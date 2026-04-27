import SwiftUI
import SwiftData
import StoreKit
import TipKit
import WidgetKit
import os
import BudgetVaultShared

private let settingsLog = Logger(subsystem: "io.budgetvault.app", category: "settings")

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.biometricLockEnabled) private var biometricLockEnabled = false
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.userName) private var userName = ""
    // Synced by StoreKitManager.checkEntitlements() on every launch
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @AppStorage(AppStorageKeys.dailyReminderEnabled) private var dailyReminderEnabled = false
    @AppStorage(AppStorageKeys.dailyReminderHour) private var dailyReminderHour = 20
    @AppStorage(AppStorageKeys.weeklyDigestEnabled) private var weeklyDigestEnabled = false
    @AppStorage(AppStorageKeys.billDueReminders) private var billDueReminders = false
    @AppStorage(AppStorageKeys.morningBriefingEnabled) private var morningBriefingEnabled = false
    @AppStorage(AppStorageKeys.morningBriefingHour) private var morningBriefingHour = 8
    // Audit 2026-04-23 Smoke-9 Fix 1: close-vault 9pm habit-anchor
    // reminder — wired up with its own Settings toggle.
    @AppStorage(AppStorageKeys.closeVaultReminderEnabled) private var closeVaultReminderEnabled = false
    @AppStorage(AppStorageKeys.reviewPromptCount) private var reviewPromptCount = 0
    @AppStorage(AppStorageKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false

    @State private var showRecurring = false
    @State private var showRestartAlert = false
    @State private var cloudSync = CloudSyncService()
    @State private var showPaywall = false
    @State private var showCurrencyPicker = false
    @State private var showCSVImport = false
    // Audit 2026-04-23 MobAI M4 re-smoke: prior two-state flip
    // (`exportURL` + `showExportShare`) produced intermittent silent
    // failures where the sheet presented before `exportURL` landed
    // in the render pass, leaving an empty sheet that dismissed on
    // its own. Swapped to a single `Identifiable` wrapper + `.sheet(item:)`
    // which atomically ties the presentation to a non-nil value.
    struct ExportShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var exportShareItem: ExportShareItem?
    @State private var tempCurrency = ""
    @State private var showBudgetTemplates = false
    @State private var showAchievements = false
    @State private var templateAppliedAlert = false
    @Environment(StoreKitManager.self) private var storeKit
    @State private var showNotificationDeniedAlert = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showDeleteAllConfirm = false
    @State private var showDeleteAllFinalConfirm = false
    @State private var showFeedback = false

    var body: some View {
        // Phase 8.2 §5.4: free users see an upgrade ChamberCard above
        // the Form (full-bleed brand treatment unconstrained by Form
        // row geometry). Premium users see a slim inline badge as the
        // Form's first section. The split lets the upgrade CTA earn
        // its visual weight without making the rest of Settings feel
        // heavy.
        ZStack {
            // Mockup line 61: radial ellipse gradient from lifted
            // navy at center-top to deep abyss at the edges. Replaces
            // a flat navyDark — adds depth so the chambers feel like
            // they sit on a curved surface, not a black wall.
            RadialGradient(
                colors: [
                    BudgetVaultTheme.navyElevated,
                    BudgetVaultTheme.navyDark,
                    BudgetVaultTheme.navyAbyss
                ],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 700
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if !(isPremium || storeKit.isPremium) {
                    premiumUpgradeCard
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.top, BudgetVaultTheme.spacingMD)
                } else {
                    // Audit 2026-04-23 Settings Option A: premium users
                    // get a summary strip above the Form (matches
                    // mockup) instead of the old inline
                    // `premiumActiveBadge` section. Strip pulls the
                    // premium state up into the ambient chrome.
                    premiumSummaryStrip
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.top, BudgetVaultTheme.spacingMD)
                }

                Form {
                    securitySection
                    profileSection
                    dataSection
                    notificationsSection
                    // Mockup Settings·Premium shows no separate "Premium"
                    // section for paid users — the active badge at the
                    // top already conveys state. Only render the Premium
                    // section for free users (Upgrade + Restore + optional
                    // Leave a Tip).
                    if !(isPremium || storeKit.isPremium) {
                        premiumSection
                    } else if storeKit.tipProduct != nil {
                        tipOnlySection
                    }
                    iCloudSection
                    aboutSection
                }
                // Phase 8.2 §5.1: the Form structure stays (iOS Settings
                // convention) but its surfaces switch to the VaultRevamp
                // chamber palette. `.scrollContentBackground(.hidden)` hides
                // the default grouped-list backdrop so our navy can show
                // through; each section's rows then pin their backdrop via
                // `.listRowBackground(chamberRowGradient)`.
                .scrollContentBackground(.hidden)
                // Audit 2026-04-23 Settings Option A redesign: all row
                // Labels render as tile-icon + title via ChamberLabelStyle.
                // Specific rows (Delete / Import / Export) override the
                // role on their own Label to get destructive/premium/
                // positive coloring.
                .labelStyle(ChamberLabelStyle())
                // Audit 2026-04-23 Smoke-3 R1: without this the last
                // Form row (Export CSV / Delete All Data) sits in the
                // tab bar's expanded hit zone — taps routed to tab-bar
                // buttons instead. `.contentMargins` pushes the
                // scrollable area up so the last row clears the tab
                // bar's strike zone even at minimum scroll.
                .contentMargins(.bottom, 40, for: .scrollContent)
            }
        }
        .navigationTitle("Settings")
        // v3.2 audit H13: opaque nav bar background so the title doesn't
        // render on top of list content when scrolling (iOS default
        // behavior leaves it transparent with translucent-on-scroll).
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showRecurring) {
            NavigationStack {
                RecurringExpenseListView()
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showCurrencyPicker) {
            NavigationStack {
                CurrencyPickerView(selectedCurrency: $tempCurrency)
                    .navigationTitle("Currency")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                selectedCurrency = tempCurrency
                                showCurrencyPicker = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showCSVImport) {
            CSVImportView()
        }
        .sheet(item: $exportShareItem) { item in
            ShareSheetView(url: item.url)
        }
        .sheet(isPresented: $showBudgetTemplates) {
            BudgetTemplateSheetView()
        }
        .sheet(isPresented: $showAchievements) {
            AchievementGridView()
        }
        .alert("Template Applied", isPresented: $templateAppliedAlert) {
            Button("OK") {}
        } message: {
            Text("Missing categories from the template have been added to your current budget.")
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text(exportErrorMessage)
        }
        .onChange(of: selectedCurrency) { _, _ in
            SettingsSyncService.pushAllSettings()
        }
        .onChange(of: resetDay) { _, _ in
            SettingsSyncService.pushAllSettings()
        }
        .onAppear {
            // Audit 2026-04-22 P0-14: surface the "iCloud toggle on but
            // no iCloud account" case every time Settings is opened, so
            // the error state doesn't stay stale from a prior launch.
            if iCloudSyncEnabled {
                cloudSync.refreshAvailability()
            }
        }
        .alert("Delete All Data?", isPresented: $showDeleteAllConfirm) {
            Button("Export Data First") {
                // Trigger export, then show final confirm
                do {
                    let url = try CSVExporter.export(context: modelContext, premiumOnly: isPremium, resetDay: resetDay)
                    exportShareItem = ExportShareItem(url: url)
                } catch {
                    // If export fails, show error — do NOT proceed to deletion
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                }
            }
            Button("Continue Without Exporting", role: .destructive) {
                showDeleteAllFinalConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We recommend exporting your data before deleting. This cannot be undone.")
        }
        .alert("Are you sure?", isPresented: $showDeleteAllFinalConfirm) {
            Button("Delete Everything", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // Audit 2026-04-23 UX P1: prior copy said "budgets, transactions,
            // and settings" but silently also wiped Keychain (premium),
            // iCloud sync, biometric lock, Live Activity + widget data,
            // and re-ran onboarding. Full disclosure.
            //
            // Audit 2026-04-27 H-2: prior copy claimed "Apple-side data
            // unaffected" — technically true but read by users as "we
            // can't see Apple's copy" rather than "your data still lives
            // in iCloud." The wipe now disables iCloud sync (so Apple's
            // copy stops mirroring back), and the message points users
            // at iOS Settings for a true CloudKit-side wipe.
            Text("""
            This permanently deletes:
            • All budgets, transactions, recurring rules, debts
            • All categories and preferences
            • Premium unlock (tap Restore Purchases in Settings to recover)
            • Live Activity + widget data
            • Onboarding progress (you'll set up again)

            iCloud sync will be turned off. To also remove your data from \
            iCloud, open iOS Settings → [your name] → iCloud → Manage \
            Account Storage → BudgetVault → Delete Data.

            Cannot be undone.
            """)
        }
    }

    // MARK: - Premium Badge

    /// Full-bleed ChamberCard upgrade CTA rendered above the Form for
    /// free users. Escapes Form row geometry so the dial + copy get
    /// proper breathing room and the chevron-right reads as a clear
    /// "tap to open paywall" affordance.
    @ViewBuilder
    private var premiumUpgradeCard: some View {
        Button {
            showPaywall = true
        } label: {
            // Phase 8.3 §3.4: uses a custom gradient + blue-tinted
            // border rather than the standard ChamberCard. The elevated
            // navy + blue-soft accent stroke give it enough visual
            // weight to earn its position above the Form without
            // feeling heavy. If a third Chamber variant shows up, pull
            // this out into ChamberCard(variant: .premium).
            HStack(spacing: 14) {
                VaultDial(size: .small, state: .locked, showNumerals: false)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BudgetVault Premium")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    // Audit 2026-04-23 Brand: canonical long-form CTA.
                    Text("Unlock the full vault")
                        .font(.system(size: 13))
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }

                Spacer()

                // §3.2 confirms the chevron is a styled text glyph, not
                // an SF Symbol — weight reads lighter and the color is
                // accentSoft (not titanium500) to signal "tappable."
                Text("\u{203A}")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BudgetVaultTheme.accentSoft)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                BudgetVaultTheme.navyElevated,
                                BudgetVaultTheme.navyDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(BudgetVaultTheme.accentSoft.opacity(0.25), lineWidth: 1)
            )
            // Mockup line 163–165: inset 0 1px 0 rgba(96,165,250,0.12)
            // inner highlight at top — a thin "lip" that catches light.
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .inset(by: 1)
                    .stroke(BudgetVaultTheme.accentSoft.opacity(0.12), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            // And: 0 4px 14px rgba(37,99,235,0.15) outer blue drop
            // shadow so the card lifts off the navy Form below.
            .shadow(color: BudgetVaultTheme.electricBlue.opacity(0.15), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to BudgetVault Premium. Open the full vault.")
    }

    /// Audit 2026-04-23 Settings Option A: above-Form summary strip for
    /// premium users. Mirrors `docs/settings-mockups/index.html` top
    /// badge — "PREMIUM" pill + a short status line. Reads as ambient
    /// chrome, not a list row.
    @ViewBuilder
    private var premiumSummaryStrip: some View {
        HStack(spacing: 10) {
            Text("PREMIUM")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(BudgetVaultTheme.accentSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(BudgetVaultTheme.accentSoft.opacity(0.14))
                )
                .overlay(
                    Capsule().strokeBorder(BudgetVaultTheme.accentSoft.opacity(0.3), lineWidth: 1)
                )
            Text("Vault Intelligence active")
                .font(.system(size: 13))
                .foregroundStyle(BudgetVaultTheme.bodyOnDark)
            Spacer(minLength: 0)
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundStyle(BudgetVaultTheme.positive)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    BudgetVaultTheme.electricBlue.opacity(0.14),
                    BudgetVaultTheme.accentSoft.opacity(0.04)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(BudgetVaultTheme.accentSoft.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("BudgetVault Premium, active. Vault Intelligence active.")
    }

    /// Slim active-state badge for premium users. Lives inside the
    /// Form as the first section so the nav-title-to-first-row rhythm
    /// stays consistent with iOS Settings convention.
    @ViewBuilder
    private var premiumActiveBadge: some View {
        // Mockup lines 389–414: blue-soft-tinted chamber row with the
        // 20pt mini dial, bold "BudgetVault Premium" in accentSoft, and
        // a green positive STAR (not a checkmark seal). Items are
        // center-aligned as a group with a 10pt gap.
        Section {
            // Audit 2026-04-22 P1-37: group the 3 sub-elements so
            // VoiceOver reads "BudgetVault Premium" once, not "small
            // dial, BudgetVault Premium, star." Also adds a stable
            // accessibilityLabel so the star glyph doesn't leak.
            HStack(spacing: 10) {
                VaultDial(size: .small, state: .locked, showNumerals: false)
                    .frame(width: 20, height: 20)
                Text("BudgetVault Premium")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.14)
                    .foregroundStyle(BudgetVaultTheme.accentSoft)
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(BudgetVaultTheme.positive)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("BudgetVault Premium, active")
            .listRowBackground(
                BudgetVaultTheme.accentSoft.opacity(0.08)
            )
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { biometricLockEnabled },
                set: { newValue in
                    biometricLockEnabled = newValue
                    // Audit 2026-04-23 Security P1: when the lock turns
                    // on, also end any live Lock-Screen Activity that's
                    // currently showing balances. Activity renders on
                    // the lock screen and would contradict the lock.
                    if newValue {
                        BudgetLiveActivityService.endAll()
                    }
                }
            )) {
                // Audit 2026-04-23 Smoke-8: Toggle's Label slot doesn't
                // inherit the Form-level `.labelStyle(ChamberLabelStyle())`
                // reliably on iOS 18, so apply the tile style
                // explicitly at every Toggle callsite.
                Label("Biometric Lock", systemImage: "faceid")
                    .labelStyle(ChamberLabelStyle())
            }
            .tint(BudgetVaultTheme.electricBlue)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)
        } header: {
            EngravedSectionHeader(title: "Security")
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack(spacing: 12) {
                ChamberTileIcon(symbol: "person.fill")
                Text("Name")
                Spacer()
                // Audit fix: TextField without submitLabel traps users
                // on-keyboard with no Done button visible in a Form
                // context. `.submitLabel(.done)` + onSubmit gives the
                // return key a "done" affordance that dismisses the
                // keyboard.
                TextField("Your name", text: $userName)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                    .submitLabel(.done)
                    .onSubmit {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .accessibilityLabel("Name")
            }
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Button {
                tempCurrency = selectedCurrency
                showCurrencyPicker = true
            } label: {
                HStack(spacing: 12) {
                    ChamberTileIcon(symbol: "dollarsign.circle.fill")
                    Text("Currency")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedCurrency)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        // Audit 2026-04-22 P0-9: chevron glyph on navy —
                        // titanium500 = 3.25:1 fails WCAG 1.4.11 (3:1 for
                        // non-text iconography is the floor; we aim higher).
                        // titanium400 = 5.8:1.
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                }
            }
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            // Audit 2026-04-23 Smoke-8: `Picker("Budget Reset Day", ...)`
            // renders its title as a plain Text — no Label, no tile.
            // Wrap in an HStack so we can prepend a ChamberTileIcon
            // while keeping the Picker's inline selection display.
            HStack(spacing: 12) {
                ChamberTileIcon(symbol: "calendar")
                Picker("Budget Reset Day", selection: $resetDay) {
                    ForEach(1...28, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .tint(BudgetVaultTheme.accentSoft)
            }
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Text("Changing the reset day takes effect next month.")
                .font(.caption)
                .foregroundStyle(BudgetVaultTheme.titanium400)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
        } header: {
            EngravedSectionHeader(title: "Profile")
        }
    }

    // MARK: - Data

    private let recurringExpenseTip = RecurringExpenseTip()

    private var dataSection: some View {
        Section {
            TipView(recurringExpenseTip)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Button {
                showRecurring = true
            } label: {
                Label("Recurring Expenses", systemImage: "repeat")
            }
            .tint(BudgetVaultTheme.accentSoft)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Button {
                // Audit 2026-04-23 M4: diagnostic log to verify the
                // button fires at all (MobAI reported silent failure).
                settingsLog.info("Export CSV tapped. premiumOnly=\(isPremium || storeKit.isPremium, privacy: .public)")
                do {
                    let url = try CSVExporter.export(context: modelContext, premiumOnly: isPremium || storeKit.isPremium, resetDay: resetDay)
                    exportShareItem = ExportShareItem(url: url)
                    settingsLog.info("Export CSV succeeded. url=\(url.lastPathComponent, privacy: .public)")
                } catch {
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                    settingsLog.error("Export CSV failed: \(error.localizedDescription, privacy: .public)")
                }
            } label: {
                Label("Export CSV (Full History)", systemImage: "square.and.arrow.up")
                    .labelStyle(ChamberLabelStyle(role: .positive))
            }
            .tint(BudgetVaultTheme.accentSoft)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Button {
                if isPremium {
                    showCSVImport = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                        .labelStyle(ChamberLabelStyle(role: isPremium ? .standard : .premium))
                    if !isPremium {
                        Spacer()
                        // Phase 8.2 §4.7: premium-gated star → caution
                        // amber so "this costs more" reads without being
                        // alarming. Default secondary rendered generic.
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(BudgetVaultTheme.caution)
                    }
                }
            }
            .tint(BudgetVaultTheme.accentSoft)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Button {
                showBudgetTemplates = true
            } label: {
                Label("Budget Templates", systemImage: "doc.on.doc")
            }
            .tint(BudgetVaultTheme.accentSoft)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            // v3.2 audit M7: removed "Multi-Budget Profiles — Coming Soon"
            // row. Shipped Settings shouldn't advertise unshipped features.
            // v3.2 audit M3/M15: trophy.fill → star for achievements
            // (trophy was gamified Duolingo tone). Also moved below the
            // other rows so it's not adjacent to destructive Delete.
            Button {
                showAchievements = true
            } label: {
                Label("Milestones", systemImage: "star.leadinghalf.filled")
            }
            .tint(BudgetVaultTheme.accentSoft)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Button(role: .destructive) {
                // Audit 2026-04-23 M5: diagnostic log (MobAI reported
                // no-confirm-dialog silent failure).
                settingsLog.info("Delete All Data tapped. showing confirm alert.")
                showDeleteAllConfirm = true
            } label: {
                Label("Delete All Data", systemImage: "trash.fill")
                    .labelStyle(ChamberLabelStyle(role: .destructive))
            }
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)
        } header: {
            EngravedSectionHeader(title: "Data")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $dailyReminderEnabled) {
                Label("Daily Reminder", systemImage: "bell.fill")
                    .labelStyle(ChamberLabelStyle())
            }
                .tint(BudgetVaultTheme.electricBlue)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
                .onChange(of: dailyReminderEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission { granted in
                            if granted {
                                NotificationService.scheduleDailyReminder(hour: dailyReminderHour)
                            } else {
                                dailyReminderEnabled = false
                            }
                        }
                    } else {
                        NotificationService.cancelDailyReminder()
                    }
                }

            if dailyReminderEnabled {
                Picker("Reminder Time", selection: $dailyReminderHour) {
                    ForEach(6...23, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
                .onChange(of: dailyReminderHour) { _, newHour in
                    NotificationService.scheduleDailyReminder(hour: newHour)
                }
            }

            Toggle(isOn: $weeklyDigestEnabled) {
                Label("Weekly Summary", systemImage: "calendar")
                    .labelStyle(ChamberLabelStyle())
            }
                .tint(BudgetVaultTheme.electricBlue)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
                .onChange(of: weeklyDigestEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission { granted in
                            if granted {
                                // Audit 2026-04-23 Max Audit P1-33:
                                // register a placeholder weekly summary
                                // immediately so Sunday 6pm fires even
                                // if the user never visits Dashboard.
                                // DashboardView.task overwrites with the
                                // personalized payload on next foreground.
                                NotificationService.scheduleWeeklySummary(
                                    weeklySpent: 0,
                                    transactionCount: 0,
                                    remaining: 0,
                                    currencyCode: selectedCurrency
                                )
                            } else {
                                weeklyDigestEnabled = false
                            }
                        }
                    } else {
                        NotificationService.cancelWeeklySummary()
                    }
                }

            Toggle(isOn: $billDueReminders) {
                Label("Bill Due Reminders", systemImage: "creditcard.fill")
                    .labelStyle(ChamberLabelStyle())
            }
                .tint(BudgetVaultTheme.electricBlue)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
                .onChange(of: billDueReminders) { _, enabled in
                    if enabled {
                        requestNotificationPermission { granted in
                            if !granted {
                                billDueReminders = false
                            } else {
                                // Audit 2026-04-23 Smoke-9 Fix 3: bulk-
                                // schedule reminders for every recurring
                                // expense already in the vault when the
                                // toggle flips on. Before this, the
                                // toggle only affected NEWLY-created
                                // expenses — users with a pre-populated
                                // recurring list flipped the toggle on
                                // and got nothing.
                                scheduleAllExistingBillDueReminders()
                            }
                        }
                    } else {
                        NotificationService.cancelAllBillDueReminders()
                    }
                }

            Toggle(isOn: $closeVaultReminderEnabled) {
                Label("Close-Vault Reminder", systemImage: "lock.circle.fill")
                    .labelStyle(ChamberLabelStyle())
            }
                .tint(BudgetVaultTheme.electricBlue)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
                .onChange(of: closeVaultReminderEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission { granted in
                            if granted {
                                NotificationService.scheduleEveningCloseVault()
                            } else {
                                closeVaultReminderEnabled = false
                            }
                        }
                    } else {
                        NotificationService.cancelEveningCloseVault()
                    }
                }

            Toggle(isOn: $morningBriefingEnabled) {
                Label("Morning Briefing", systemImage: "sun.max.fill")
                    .labelStyle(ChamberLabelStyle())
            }
                .tint(BudgetVaultTheme.electricBlue)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
                .onChange(of: morningBriefingEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission { granted in
                            if !granted {
                                morningBriefingEnabled = false
                            }
                            // Will be scheduled with real data from dashboard .task
                        }
                    } else {
                        NotificationService.cancelMorningBriefing()
                    }
                }

            if morningBriefingEnabled {
                Picker("Briefing Time", selection: $morningBriefingHour) {
                    ForEach(5...11, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            }
        } header: {
            EngravedSectionHeader(title: "Notifications")
        }
        .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are disabled for BudgetVault. Please enable them in Settings to receive reminders.")
        }
    }

    // MARK: - Premium

    /// Premium users still get Leave a Tip, but without the "Active"
    /// or Restore Purchases rows — those are either redundant (active)
    /// or rarely needed once premium is already on this device. Keeps
    /// the paid-user Settings as close to the mockup as we can while
    /// preserving the tip revenue flow.
    @ViewBuilder
    private var tipOnlySection: some View {
        if let tipProduct = storeKit.tipProduct {
            Section {
                Button {
                    Task { await storeKit.purchase(tipProduct) }
                } label: {
                    HStack(spacing: 12) {
                        ChamberTileIcon(symbol: "heart.fill", role: .destructive)
                        Text("Leave a Tip")
                        Spacer()
                        Text(tipProduct.displayPrice)
                            .foregroundStyle(BudgetVaultTheme.titanium300)
                    }
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            } header: {
                EngravedSectionHeader(title: "Support")
            }
        }
    }

    private var premiumSection: some View {
        Section {
            if isPremium || storeKit.isPremium {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(BudgetVaultTheme.positive)
                    Text("BudgetVault Premium")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.positive)
                }
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(BudgetVaultTheme.caution)
                        // Audit 2026-04-23 Brand: canonical long-form CTA
                        // (Settings Premium row treated as a long-form surface).
                        Text("Unlock the full vault")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            // Audit 2026-04-23 Max Audit P1-37: titanium500
                            // = 2.45:1 fails WCAG 1.4.11 (3:1 floor for
                            // non-text). titanium400 = 5.8:1.
                            .foregroundStyle(BudgetVaultTheme.titanium400)
                    }
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            }

            if !isPremium && !storeKit.isPremium {
                Button("Restore Purchases") {
                    Task { await storeKit.restorePurchases() }
                }
                .font(.subheadline)
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            }

            if storeKit.tipProduct != nil {
                Button {
                    Task {
                        if let tip = storeKit.tipProduct {
                            await storeKit.purchase(tip)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(BudgetVaultTheme.negative)
                        Text("Leave a Tip")
                        Spacer()
                        Text(storeKit.tipProduct?.displayPrice ?? "")
                            .foregroundStyle(BudgetVaultTheme.titanium300)
                    }
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            }
        } header: {
            EngravedSectionHeader(title: "Premium")
        }
    }

    // MARK: - iCloud

    private var iCloudSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { iCloudSyncEnabled },
                set: { newValue in
                    iCloudSyncEnabled = newValue
                    // Audit fix: register the KVS observer + push
                    // immediately when the toggle flips, so the sync
                    // works before the required app relaunch — the
                    // `showRestartAlert` explains the SwiftData
                    // container-level restart is still needed.
                    SettingsSyncService.iCloudToggleChanged(enabled: newValue)
                    // Audit 2026-04-22 P0-14: surface the no-account
                    // case immediately. Before this, toggling iCloud
                    // on without an iCloud account silently did nothing.
                    if newValue {
                        cloudSync.refreshAvailability()
                    } else {
                        cloudSync.syncError = nil
                    }
                    showRestartAlert = true
                }
            )) {
                Label("iCloud Sync", systemImage: "icloud.fill")
                    .labelStyle(ChamberLabelStyle(role: .info))
            }
            .tint(BudgetVaultTheme.electricBlue)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            if iCloudSyncEnabled {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    if cloudSync.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(BudgetVaultTheme.accentSoft)
                    } else {
                        Text(cloudSync.lastSyncText)
                            .foregroundStyle(BudgetVaultTheme.titanium300)
                    }
                }
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)

                if let error = cloudSync.syncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.negative)
                        .listRowBackground(BudgetVaultTheme.chamberRowGradient)
                }
            }

            // v3.2 audit H8: caption now matches the toggle state.
            // Previously said "data stays on Apple's servers" regardless
            // of whether sync was on or off, which contradicted reality.
            Text(iCloudSyncEnabled
                 ? "Data stays on Apple's servers only. No third-party servers."
                 : "iCloud Sync is off. All data stays on this device only.")
                .font(.caption)
                .foregroundStyle(BudgetVaultTheme.titanium400)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
        } header: {
            EngravedSectionHeader(title: "iCloud Sync")
        }
        .alert("Restart the App", isPresented: $showRestartAlert) {
            // Audit 2026-04-23 Max Audit P1-29 + gap-finder Lens 8:
            // only the SwiftData CloudKit container requires a
            // relaunch; KVS settings sync activates immediately. Soft
            // copy + OK is honest — iOS apps can't force-quit
            // themselves.
            Button("OK") {}
        } message: {
            Text("iCloud data sync activates the next time you open BudgetVault. Swipe up to close, then tap to reopen when ready.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack(spacing: 12) {
                ChamberTileIcon(symbol: "info.circle.fill")
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(BudgetVaultTheme.titanium300)
            }
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            // Audit 2026-04-23 Max Audit P2: replaced force-unwrapped
            // URLs with safely-resolved ones. Hardcoded URL strings are
            // safe today but a future refactor typo would crash.
            if let homeURL = URL(string: "https://budgetvault.io") {
                ShareLink(item: homeURL,
                           subject: Text("BudgetVault"),
                           // Audit 2026-04-23 Brand: canonical hero privacy wedge.
                           message: Text("BudgetVault. On-device. No bank login. Ever. $14.99 once.")) {
                    Label("Share BudgetVault", systemImage: "heart.fill")
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            }

            // v3.2 audit L9: removed the .foregroundStyle(.primary)
            // override that rendered the bubble icon black; now it
            // inherits the row tint like every other Settings row.
            Button {
                showFeedback = true
            } label: {
                Label("Send Feedback", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tint(BudgetVaultTheme.accentSoft)
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            Text(iCloudSyncEnabled
                 ? "Your data syncs securely via iCloud. End-to-end encrypted."
                 : "Your data never leaves this device.")
                .font(.caption)
                .foregroundStyle(BudgetVaultTheme.titanium400)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)

            if let privacyURL = URL(string: "https://budgetvault.io/privacy") {
                Link(destination: privacyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            }

            if let termsURL = URL(string: "https://budgetvault.io/terms") {
                Link(destination: termsURL) {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                }
                .tint(BudgetVaultTheme.accentSoft)
                .listRowBackground(BudgetVaultTheme.chamberRowGradient)
            }
        } header: {
            EngravedSectionHeader(title: "About")
        }
    }

    // MARK: - Helpers

    /// Audit 2026-04-23 Smoke-9 Fix 3: pull every `RecurringExpense`
    /// from the model context and schedule a bill-due reminder for
    /// each. Called when the `billDueReminders` toggle flips from
    /// off→on so pre-existing expenses start reminding.
    private func scheduleAllExistingBillDueReminders() {
        let descriptor = FetchDescriptor<RecurringExpense>()
        guard let expenses = try? modelContext.fetch(descriptor), !expenses.isEmpty else {
            settingsLog.info("scheduleAllExistingBillDueReminders: nothing to schedule.")
            return
        }
        let tuples = expenses.map { (name: $0.name, nextDueDate: $0.nextDueDate, id: $0.id.uuidString) }
        NotificationService.scheduleAllBillDueReminders(expenses: tuples)
        settingsLog.info("scheduleAllExistingBillDueReminders: scheduled \(tuples.count, privacy: .public).")
    }

    /// Requests notification authorization and calls `completion` on the main thread with the result.
    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        checkNotificationPermission()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    private func checkNotificationPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                await MainActor.run {
                    showNotificationDeniedAlert = true
                }
            }
        }
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private func deleteAllData() {
        // Delete all model objects.
        //
        // Audit fix: previously used `try? modelContext.delete(model:)`
        // per type, which swallowed errors silently. If one type failed
        // mid-loop the remaining types still got deleted and SafeSave
        // committed a partially-wiped state. Now we propagate errors,
        // rollback on the first failure, and abort before save.
        let types: [any PersistentModel.Type] = [
            Budget.self, Category.self, Transaction.self,
            RecurringExpense.self, DebtAccount.self, DebtPayment.self,
            NetWorthAccount.self, NetWorthSnapshot.self
        ]
        do {
            for type in types {
                try modelContext.delete(model: type)
            }
        } catch {
            modelContext.rollback()
            return
        }
        guard SafeSave.save(modelContext) else { modelContext.rollback(); return }

        // Reset UserDefaults — enumerate all keys and remove any that match app prefixes
        // This catches dynamic keys like "lastCategoryAlert-*" and "underBudget_*_*"
        let appPrefixes = [
            "resetDay", "hasCompleted", "hasLogged", "userName", "isPremium",
            "debugPremium", "lastPaywall", "reviewPrompt", "selectedCurrency",
            "accentColor", "biometricLock", "currentStreak", "lastLog",
            "streakFreezes", "lastFreeze", "lastSummary", "dailyReminder",
            "weeklyDigest", "billDue", "iCloudSync", "underBudget",
            "lastCategoryAlert", "unlockedAchievements",
            "lastActiveDate", "morningBriefing", "catchUpDismissed",
            "categoryLearningMappings", "reviewTriggered_", "lastReviewPrompt",
            "transactionCount", "hasSeenTransaction", "hasSeenStreak", "installDate",
            // Audit 2026-04-23 Max Audit P2: extra orphan prefixes the
            // earlier sweep missed.
            "lastBackgroundDate", "closeVaultReminder", "lastNotificationScheduleHour",
        ]
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if appPrefixes.contains(where: { key.hasPrefix($0) }) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        // Audit 2026-04-27 H-2: turn iCloud sync off BEFORE the rest of
        // the wipe. The local SwiftData store is mirrored to a CloudKit
        // private database; if the user reopens with sync still on, the
        // CloudKit mirror immediately repopulates everything we just
        // deleted, breaking the "Delete All Data" privacy contract.
        // Tearing down the KVS observer here also stops a remote-device
        // sync write from racing the deletion. The user is told via the
        // alert message how to also remove the iCloud-side copy.
        UserDefaults.standard.set(false, forKey: AppStorageKeys.iCloudSyncEnabled)
        SettingsSyncService.iCloudToggleChanged(enabled: false)

        // Audit 2026-04-22 P1-21: previously left the Keychain premium
        // flag in place — a user who "Deleted All Data" would return to
        // the app with premium still unlocked (because Keychain is the
        // authoritative source; see StoreKitManager.checkEntitlements).
        // Also explicitly reset `hasCompletedOnboarding` so the user
        // goes through setup again instead of landing on an empty
        // dashboard with half the preferences gone.
        KeychainService.delete(forKey: AppStorageKeys.isPremium)
        UserDefaults.standard.set(false, forKey: AppStorageKeys.hasCompletedOnboarding)
        // Audit 2026-04-22 P1-22: reset the file-protection one-shot so
        // the next launch re-stamps any freshly-created SwiftData files.
        UserDefaults.standard.set(false, forKey: AppStorageKeys.didStampFileProtection)

        // Audit 2026-04-23 Security P1: wipe App Group UserDefaults
        // (widget snapshot data) + end all Live Activities. Without
        // these, the user's remaining budget is still visible on the
        // lock screen / home screen after "Delete All Data".
        if let appGroup = UserDefaults(suiteName: "group.io.budgetvault.shared") {
            appGroup.removePersistentDomain(forName: "group.io.budgetvault.shared")
        }
        BudgetLiveActivityService.endAll()
        WidgetCenter.shared.reloadAllTimelines()

        NotificationService.cancelDailyReminder()
        NotificationService.cancelWeeklySummary()
        NotificationService.cancelMorningBriefing()
        NotificationService.cancelReengagementNotifications()
        NotificationService.cancelEndOfPeriodNotifications()
        // Audit 2026-04-23 Max Audit P1-14: sweep close-vault reminder
        // (added v3.3.1) + bill-due per-expense triggers + streak-at-risk
        // that the prior sweep missed.
        NotificationService.cancelEveningCloseVault()
        NotificationService.cancelStreakAtRisk()
        NotificationService.cancelAllBillDueReminders()

        // Audit 2026-04-23 Max Audit P1-14: wipe feedback log + tmp CSV
        // exports. These are in Documents/ + tmp/ and escaped the
        // UserDefaults prefix sweep above.
        FeedbackService.clearAll()
        let tmp = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tmp.path) {
            for name in files where name.hasPrefix("BudgetVault_Export") && name.hasSuffix(".csv") {
                try? FileManager.default.removeItem(at: tmp.appendingPathComponent(name))
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components) else { return "\(hour):00" }
        return Self.hourFormatter.string(from: date)
    }
}

// MARK: - Budget Template Sheet

struct BudgetTemplateSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

    @State private var showAppliedAlert = false
    @State private var appliedTemplateName = ""

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Applying a template adds any missing categories to your current budget. Existing categories are not removed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(BudgetTemplates.settingsTemplates, id: \.name) { template in
                    Button {
                        applyTemplate(template)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: template.icon)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(template.categories.map(\.emoji).joined(separator: " "))
                                    .font(.caption)
                            }

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Budget Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Template Applied", isPresented: $showAppliedAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Categories from \"\(appliedTemplateName)\" have been added to your budget.")
            }
        }
    }

    private func applyTemplate(_ template: BudgetTemplates.SettingsTemplate) {
        guard let budget = currentBudget else { return }
        let existingNames = Set((budget.categories ?? []).map { $0.name.lowercased() })
        let maxSortOrder = (budget.categories ?? []).map(\.sortOrder).max() ?? 0
        var nextOrder = maxSortOrder + 1

        let currentCount = (budget.categories ?? []).filter { !$0.isHidden }.count
        let freeLimit = 6
        var added = 0

        for cat in template.categories {
            guard !existingNames.contains(cat.name.lowercased()) else { continue }
            if !isPremium && (currentCount + added) >= freeLimit { break }
            let newCategory = Category(
                name: cat.name,
                emoji: cat.emoji,
                budgetedAmountCents: 0,
                color: cat.color,
                sortOrder: nextOrder
            )
            newCategory.budget = budget
            modelContext.insert(newCategory)
            nextOrder += 1
            added += 1
        }

        guard SafeSave.save(modelContext) else { modelContext.rollback(); return }
        appliedTemplateName = template.name
        showAppliedAlert = true
    }
}
