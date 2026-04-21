import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import BudgetVaultShared

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @State private var showFilePicker = false
    @State private var csvContent: String?
    @State private var parsedRows: [CSVImportRow] = []
    @State private var detectedFormat: CSVFormat = .unknown
    @State private var uniqueCategories: [String] = []
    @State private var selectedCategories: Set<String> = []
    @State private var categoryMap: [String: String] = [:]
    @State private var importResult: (transactions: Int, months: Int)?
    @State private var step: ImportStep = .selectFile

    enum ImportStep {
        case selectFile
        case preview
        case categorySelection
        case importing
        case done
    }

    /// Mockup §5.2: 3-bolt BoltRow at the top of every step.
    /// - selectFile → engaged 1 ("Step 1 of 3 · Select file")
    /// - preview / categorySelection → engaged 2 ("Step 2 of 3 · Review")
    /// - done → engaged 3 ("Complete")
    private var stepProgress: (engaged: Int, label: String) {
        switch step {
        case .selectFile: return (1, "Step 1 of 3 \u{00B7} Select file")
        case .preview, .categorySelection: return (2, "Step 2 of 3 \u{00B7} Review")
        case .importing: return (2, "Importing")
        case .done: return (3, "Complete")
        }
    }

    private var stepProgressLabelColor: Color {
        step == .done ? BudgetVaultTheme.positive : BudgetVaultTheme.titanium300
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    BoltRow(count: 3, engaged: stepProgress.engaged, size: .medium)
                    Text(stepProgress.label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(stepProgressLabelColor)
                }
                .padding(.top, BudgetVaultTheme.spacingLG)
                .padding(.bottom, BudgetVaultTheme.spacingMD)

                Group {
                    switch step {
                    case .selectFile:
                        selectFileView
                    case .preview:
                        previewView
                    case .categorySelection:
                        categorySelectionView
                    case .importing:
                        ProgressView("Importing...")
                            .tint(BudgetVaultTheme.accentSoft)
                            .foregroundStyle(BudgetVaultTheme.titanium300)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .done:
                        doneView
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BudgetVaultTheme.navyDark)
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(BudgetVaultTheme.accentSoft)
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText]) { result in
                handleFileSelection(result)
            }
        }
    }

    // MARK: - Select File

    private var selectFileView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(BudgetVaultTheme.titanium300)
            Text("Import transactions from a CSV file")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Supports YNAB exports and generic CSV formats.")
                .font(.subheadline)
                .foregroundStyle(BudgetVaultTheme.titanium400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showFilePicker = true
            } label: {
                Label("Choose CSV File", systemImage: "folder")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Preview

    private var previewView: some View {
        List {
            Section {
                HStack {
                    Text("Format Detected")
                    Spacer()
                    Text(formatName)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }
                .listRowBackground(BudgetVaultTheme.chamberDeep)
                HStack {
                    Text("Transactions")
                    Spacer()
                    Text("\(parsedRows.count)")
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }
                .listRowBackground(BudgetVaultTheme.chamberDeep)
                HStack {
                    Text("Categories")
                    Spacer()
                    Text("\(uniqueCategories.count)")
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }
                .listRowBackground(BudgetVaultTheme.chamberDeep)
            }

            Section {
                ForEach(Array(parsedRows.prefix(5).enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.category)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(String(format: "$%.2f", row.amount))
                                .font(.subheadline)
                                .foregroundStyle(row.isIncome ? BudgetVaultTheme.positive : .primary)
                        }
                        HStack {
                            Text(row.note)
                                .font(.caption)
                                .foregroundStyle(BudgetVaultTheme.titanium400)
                                .lineLimit(1)
                            Spacer()
                            Text(row.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(BudgetVaultTheme.titanium400)
                        }
                    }
                    .listRowBackground(BudgetVaultTheme.chamberDeep)
                }
            } header: {
                EngravedSectionHeader(title: "Preview (first 5 rows)")
            }

            Section {
                Button {
                    proceedFromPreview()
                } label: {
                    Text("Continue Import")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BudgetVaultTheme.navyDark)
    }

    // MARK: - Category Selection (Free tier)

    private var categorySelectionView: some View {
        List {
            Section {
                Text("Your import has \(uniqueCategories.count) categories. Free accounts support 4. Select which to keep.")
                    .font(.subheadline)
                    .foregroundStyle(BudgetVaultTheme.titanium400)
                    .listRowBackground(BudgetVaultTheme.chamberDeep)
            }

            Section {
                ForEach(uniqueCategories, id: \.self) { cat in
                    Button {
                        toggleCategory(cat)
                    } label: {
                        HStack {
                            Image(systemName: selectedCategories.contains(cat) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedCategories.contains(cat) ? BudgetVaultTheme.accentSoft : BudgetVaultTheme.titanium400)
                            Text(cat)
                                .foregroundStyle(.primary)
                            Spacer()
                            let count = parsedRows.filter { $0.category == cat }.count
                            Text("\(count) txns")
                                .font(.caption)
                                .foregroundStyle(BudgetVaultTheme.titanium400)
                        }
                    }
                    .accessibilityLabel("\(cat), \(selectedCategories.contains(cat) ? "selected" : "not selected")")
                    .listRowBackground(BudgetVaultTheme.chamberDeep)
                }
            } header: {
                EngravedSectionHeader(title: "Select up to 4 categories")
            }

            Section {
                Text("Unselected categories will be merged into \"Other\".")
                    .font(.caption)
                    .foregroundStyle(BudgetVaultTheme.titanium400)
                    .listRowBackground(BudgetVaultTheme.chamberDeep)

                Button {
                    performImport()
                } label: {
                    Text("Import \(parsedRows.count) Transactions")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedCategories.isEmpty)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BudgetVaultTheme.navyDark)
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(BudgetVaultTheme.positive)
            Text("Import Complete")
                .font(.title2.bold())
                .foregroundStyle(.white)
            if let result = importResult {
                Text("Imported \(result.transactions) transactions across \(result.months) months.")
                    .font(.subheadline)
                    .foregroundStyle(BudgetVaultTheme.titanium400)
                    .multilineTextAlignment(.center)
            }
            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private var formatName: String {
        switch detectedFormat {
        case .ynab: "YNAB"
        case .generic: "Generic CSV"
        case .unknown: "Unknown"
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        guard let url = try? result.get() else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        csvContent = content

        let parsed = CSVImporter.parse(csv: content)
        detectedFormat = parsed.format
        parsedRows = parsed.rows
        uniqueCategories = Array(Set(parsedRows.map(\.category))).sorted()
        selectedCategories = Set(uniqueCategories.prefix(isPremium ? uniqueCategories.count : 4))

        step = parsedRows.isEmpty ? .selectFile : .preview
    }

    private func proceedFromPreview() {
        if !isPremium && uniqueCategories.count > 4 {
            step = .categorySelection
        } else {
            performImport()
        }
    }

    private func toggleCategory(_ cat: String) {
        if selectedCategories.contains(cat) {
            selectedCategories.remove(cat)
        } else if selectedCategories.count < 4 {
            selectedCategories.insert(cat)
        }
    }

    private func performImport() {
        step = .importing

        // Build category map — unselected categories map to "Other"
        var map: [String: String] = [:]
        if !isPremium && uniqueCategories.count > 4 {
            for cat in uniqueCategories {
                map[cat] = selectedCategories.contains(cat) ? cat : "Other"
            }
        } else {
            for cat in uniqueCategories {
                map[cat] = cat
            }
        }

        let result = CSVImporter.importRows(parsedRows, categoryMap: map, context: modelContext, resetDay: resetDay)
        importResult = result
        step = .done
    }
}
