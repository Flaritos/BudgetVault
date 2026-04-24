import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import BudgetVaultShared

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    // Audit 2026-04-23 Max Audit P0-1: storeKit.isPremium is authoritative.
    @Environment(StoreKitManager.self) private var storeKit
    private var premium: Bool { isPremium || storeKit.isPremium }
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"

    @State private var showFilePicker = false
    @State private var csvContent: String?
    @State private var parsedRows: [CSVImportRow] = []
    @State private var detectedFormat: CSVFormat = .unknown
    @State private var uniqueCategories: [String] = []
    @State private var selectedCategories: Set<String> = []
    @State private var categoryMap: [String: String] = [:]
    @State private var importResult: (transactions: Int, months: Int)?
    @State private var step: ImportStep = .selectFile
    @State private var fileError: String?

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
                    BoltRow(count: 3, engaged: stepProgress.engaged, size: .medium, stepLabel: "Step \(stepProgress.engaged) of 3")
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

            // Audit fix: surface parse / size / access errors to the
            // user instead of silently returning them to the selector.
            if let fileError {
                Text(fileError)
                    .font(.caption)
                    .foregroundStyle(BudgetVaultTheme.negative)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

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
                            // Phase 8.3 audit fix: was `String(format:
                            // "$%.2f")` which locked the symbol to USD.
                            // Final-pass audit fix: preview was still
                            // using `.rounded()` Double→Int64 while the
                            // importer uses Decimal banker's rounding.
                            // Diverged for a few binary-fraction-hostile
                            // values. Use the same Decimal path in both.
                            Text(CurrencyFormatter.format(
                                cents: Self.doubleToCents(row.amount),
                                currencyCode: selectedCurrency
                            ))
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
                Text("Your import has \(uniqueCategories.count) categories. Free accounts support 6. Select which to keep.")
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
                EngravedSectionHeader(title: "Select up to 6 categories")
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

    /// Decimal-routed Double→cents conversion shared between the
    /// preview row and (implicitly) the importer path. Banker's
    /// rounding matches `CSVImporter.bankersRounding`.
    private static func doubleToCents(_ value: Double) -> Int64 {
        let decimal = Decimal(value) * 100
        let rounded = (decimal as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .bankers, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        ))
        return Int64(truncating: rounded)
    }

    /// Max CSV size we'll read into memory. Anything larger is
    /// rejected with a user-visible error so an adversarial 500 MB
    /// file from the share sheet can't OOM the app.
    private static let maxFileSizeBytes: Int = 10 * 1024 * 1024  // 10 MB

    private func handleFileSelection(_ result: Result<URL, Error>) {
        fileError = nil
        switch result {
        case .failure(let err):
            fileError = "Couldn't read file: \(err.localizedDescription)"
            return
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                fileError = "Couldn't access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Audit fix: cap file size before reading into memory.
            // `String(contentsOf:)` loads the entire file — a large
            // CSV would OOM the app on devices with tight memory.
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int,
               size > Self.maxFileSizeBytes {
                let mb = Double(size) / (1024 * 1024)
                fileError = String(format: "File is %.1f MB — max supported is 10 MB.", mb)
                return
            }

            // Audit 2026-04-22 P0-15: Excel/Numbers default to UTF-16
            // (often with a BOM) or Windows-1252, not UTF-8. Try a
            // short ladder of encodings before giving up. Order matters:
            // UTF-8 catches modern exports; BOM-sniffing UTF-16 handles
            // Excel-on-Windows defaults; ISO Latin 1 is a lossless
            // superset of the ASCII range used by most CP1252 content.
            if let (content, encodingUsed) = Self.readWithEncodingFallback(url: url) {
                csvContent = content

                let parsed = CSVImporter.parse(csv: content)
                detectedFormat = parsed.format
                parsedRows = parsed.rows
                uniqueCategories = Array(Set(parsedRows.map(\.category))).sorted()
                selectedCategories = Set(uniqueCategories.prefix(premium ? uniqueCategories.count : Self.freeCategoryLimit))

                if parsedRows.isEmpty {
                    fileError = "No transactions found in this \(encodingUsed)-decoded file. Supported formats: YNAB export or generic CSV with Date, Category, Amount columns."
                    step = .selectFile
                } else {
                    step = .preview
                }
            } else {
                fileError = "Couldn't read this file as text. If it's from Excel or Numbers, re-export as \"CSV UTF-8\" and try again."
            }
        }
    }

    /// Free-tier category cap. Matches `SettingsView.BudgetTemplateSheetView`
    /// and `AppStorage` usage elsewhere. Single source of truth.
    private static let freeCategoryLimit = 6

    /// Audit 2026-04-22 P0-15: attempt to read the file using a ladder
    /// of encodings common to spreadsheet exports. Returns the decoded
    /// text and a short label for the encoding that worked (for error
    /// copy if parsing later fails), or nil if no encoding succeeded.
    private static func readWithEncodingFallback(url: URL) -> (content: String, encoding: String)? {
        // Step 1: read raw bytes once so we can try multiple encodings
        // without repeatedly hitting the filesystem.
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Step 2: BOM sniff first — if a UTF-16 BOM is present, the
        // String init for utf16 will honor the byte order mark and
        // produce clean text. Same for UTF-8 BOM.
        if data.count >= 2 {
            let b0 = data[0], b1 = data[1]
            // UTF-16 LE BOM
            if b0 == 0xFF && b1 == 0xFE, let s = String(data: data, encoding: .utf16) { return (s, "UTF-16") }
            // UTF-16 BE BOM
            if b0 == 0xFE && b1 == 0xFF, let s = String(data: data, encoding: .utf16) { return (s, "UTF-16") }
        }
        if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF {
            if let s = String(data: data, encoding: .utf8) { return (s, "UTF-8") }
        }

        // Step 3: try the common encodings in order. UTF-8 first
        // (modern default), then the two UTF-16 variants (Windows
        // Excel without explicit encoding selection), then Windows-1252
        // (Excel-exported Latin text), then ISO-8859-1 (Latin-1, which
        // decodes any single-byte stream without throwing).
        let attempts: [(String.Encoding, String)] = [
            (.utf8, "UTF-8"),
            (.utf16LittleEndian, "UTF-16"),
            (.utf16BigEndian, "UTF-16"),
            (.windowsCP1252, "Windows-1252"),
            (.isoLatin1, "Latin-1"),
        ]
        for (enc, label) in attempts {
            if let s = String(data: data, encoding: enc), !s.isEmpty {
                return (s, label)
            }
        }
        return nil
    }

    private func proceedFromPreview() {
        if !premium && uniqueCategories.count > Self.freeCategoryLimit {
            step = .categorySelection
        } else {
            performImport()
        }
    }

    private func toggleCategory(_ cat: String) {
        if selectedCategories.contains(cat) {
            selectedCategories.remove(cat)
        } else if selectedCategories.count < Self.freeCategoryLimit {
            selectedCategories.insert(cat)
        }
    }

    private func performImport() {
        step = .importing

        // Build category map — unselected categories map to "Other"
        var map: [String: String] = [:]
        if !premium && uniqueCategories.count > Self.freeCategoryLimit {
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
