import SwiftUI
import BudgetVaultShared

struct MainTabView: View {
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    // Audit 2026-04-23 Max Audit P0-1: per CLAUDE.md rule 9, the
    // AppStorage cache is UI-instant only — `storeKit.isPremium` is
    // authoritative. Vault-tab icon was the single highest-visibility
    // drift site post-purchase (stays "locked" until next AppStorage
    // write propagates).
    @Environment(StoreKitManager.self) private var storeKit
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(0)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryView()
                .tag(1)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            FinanceTabView()
                .tag(2)
                .tabItem {
                    Label("Vault", systemImage: (isPremium || storeKit.isPremium) ? "lock.open.fill" : "lock.fill")
                }

            NavigationStack {
                SettingsView()
            }
            .tag(3)
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(BudgetVaultTheme.accentSoft)
        // Audit 2026-04-23 Smoke-4 R1: opaque tab bar so Settings Form
        // rows don't render under it (translucent default let rows at
        // y≈768 overlap tab bar at y≈791, and iOS routed taps to tab-
        // bar buttons). Making the bar opaque forces iOS to reserve
        // safe-area inset so content ends above the tab bar.
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(BudgetVaultTheme.navyDark, for: .tabBar)
        // VaultRevamp v2.1: force dark color scheme app-wide so system
        // chrome (tab bar, nav bars, default Text colors) resolves to
        // navy-compatible values. The History tab uses explicit
        // ledgerInk/ledgerPaper tokens that read correctly under either
        // scheme, so forcing dark here doesn't affect its cream look.
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .switchToHistoryTab)) { _ in
            selectedTab = 1
        }
    }
}
