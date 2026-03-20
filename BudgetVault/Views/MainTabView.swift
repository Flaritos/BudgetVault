import SwiftUI

struct MainTabView: View {
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"

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

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(BudgetVaultTheme.userAccentColor)
    }
}
