import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("resetDay") private var resetDay = 1
    @AppStorage("isPremium") private var isPremium = false

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

    var body: some View {
        NavigationStack {
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
                case .done:
                    doneView
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                .foregroundStyle(.secondary)
            Text("Import transactions from a CSV file")
                .font(.headline)
            Text("Supports YNAB exports and generic CSV formats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Transactions")
                    Spacer()
                    Text("\(parsedRows.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Categories")
                    Spacer()
                    Text("\(uniqueCategories.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Preview (first 5 rows)") {
                ForEach(parsedRows.prefix(5), id: \.note) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.category)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(String(format: "$%.2f", row.amount))
                                .font(.subheadline)
                                .foregroundStyle(row.isIncome ? .green : .primary)
                        }
                        HStack {
                            Text(row.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(row.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    proceedFromPreview()
                } label: {
                    Text("Continue Import")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Category Selection (Free tier)

    private var categorySelectionView: some View {
        List {
            Section {
                Text("Your import has \(uniqueCategories.count) categories. Free accounts support 6. Select which to keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Select up to 6 categories") {
                ForEach(uniqueCategories, id: \.self) { cat in
                    Button {
                        toggleCategory(cat)
                    } label: {
                        HStack {
                            Image(systemName: selectedCategories.contains(cat) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedCategories.contains(cat) ? Color.accentColor : .secondary)
                            Text(cat)
                                .foregroundStyle(.primary)
                            Spacer()
                            let count = parsedRows.filter { $0.category == cat }.count
                            Text("\(count) txns")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("\(cat), \(selectedCategories.contains(cat) ? "selected" : "not selected")")
                }
            }

            Section {
                Text("Unselected categories will be merged into \"Other\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    performImport()
                } label: {
                    Text("Import \(parsedRows.count) Transactions")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCategories.isEmpty)
            }
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Import Complete")
                .font(.title2.bold())
            if let result = importResult {
                Text("Imported \(result.transactions) transactions across \(result.months) months.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
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
        selectedCategories = Set(uniqueCategories.prefix(6))

        step = parsedRows.isEmpty ? .selectFile : .preview
    }

    private func proceedFromPreview() {
        if !isPremium && uniqueCategories.count > 6 {
            step = .categorySelection
        } else {
            performImport()
        }
    }

    private func toggleCategory(_ cat: String) {
        if selectedCategories.contains(cat) {
            selectedCategories.remove(cat)
        } else if selectedCategories.count < 6 {
            selectedCategories.insert(cat)
        }
    }

    private func performImport() {
        step = .importing

        // Build category map — unselected categories map to "Other"
        var map: [String: String] = [:]
        if !isPremium && uniqueCategories.count > 6 {
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
