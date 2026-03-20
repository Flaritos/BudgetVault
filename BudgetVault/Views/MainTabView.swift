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

            if isPremium {
                FinanceTabView()
                    .tabItem {
                        Label("Finance", systemImage: "chart.bar.fill")
                    }
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(BudgetVaultTheme.userAccentColor)
    }
}
