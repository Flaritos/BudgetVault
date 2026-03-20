import SwiftUI
import SwiftData

struct FinanceTabView: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1

    var body: some View {
        NavigationStack {
            List {
                // Budget Management section
                Section {
                    NavigationLink {
                        BudgetView()
                    } label: {
                        Label("Manage Budget", systemImage: "envelope.fill")
                    }

                    NavigationLink {
                        InsightsView()
                    } label: {
                        Label("Insights & Analytics", systemImage: "chart.xyaxis.line")
                    }
                } header: {
                    Text("Budget")
                }

                // Finance Tools section
                Section {
                    NavigationLink {
                        DebtTrackingView()
                    } label: {
                        Label("Debt Tracking", systemImage: "creditcard.fill")
                    }

                    NavigationLink {
                        NetWorthView()
                    } label: {
                        Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis")
                    }
                } header: {
                    Text("Finance Tools")
                }

                // Reports section
                Section {
                    NavigationLink {
                        MonthlyWrappedShell()
                    } label: {
                        Label("Monthly Wrapped", systemImage: "star.circle.fill")
                    }
                } header: {
                    Text("Reports")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Finance")
        }
    }
}

// MARK: - Shell to load Monthly Wrapped with budget data

struct MonthlyWrappedShell: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: max(resetDay, 1))
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    var body: some View {
        if let budget = currentBudget {
            MonthlyWrappedView(budget: budget, allTransactions: allTransactions)
        } else {
            ContentUnavailableView(
                "No Budget",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Create a budget first to see your monthly wrapped.")
            )
        }
    }
}
