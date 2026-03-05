import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardPlaceholderView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
            BudgetPlaceholderView()
                .tabItem {
                    Label("Budget", systemImage: "list.bullet.rectangle.fill")
                }
            HistoryPlaceholderView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            InsightsPlaceholderView()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb.fill")
                }
            SettingsPlaceholderView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
