import SwiftUI

struct MainTabView: View {
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            FinanceTabView()
                .tabItem {
                    Label("Vault", systemImage: "lock.open.fill")
                }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(BudgetVaultTheme.userAccentColor)
    }
}
