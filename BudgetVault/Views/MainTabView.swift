import SwiftUI
import BudgetVaultShared

struct MainTabView: View {
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
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
                    Label("Vault", systemImage: isPremium ? "lock.open.fill" : "lock.fill")
                }

            NavigationStack {
                SettingsView()
            }
            .tag(3)
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(BudgetVaultTheme.userAccentColor)
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
