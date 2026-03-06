import Foundation

@Observable
final class DashboardViewModel {

    // MARK: - Status

    func statusText(for percentRemaining: Double) -> String {
        if percentRemaining > 0.5 { return "On Track" }
        if percentRemaining > 0.25 { return "Watch It" }
        return "Over Budget"
    }

}
