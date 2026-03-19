import SwiftUI

struct MainTabView: View {
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "list.bullet.rectangle.fill")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.accentColor)
    }
}
