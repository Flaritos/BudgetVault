import SwiftUI
import TipKit

struct SwipeToDeleteTip: Tip {
    var title: Text { Text("Swipe to manage") }
    var message: Text? { Text("Swipe left on any transaction to delete it, or swipe right to duplicate.") }
}

struct MoveMoneyTip: Tip {
    var title: Text { Text("Move money between envelopes") }
    var message: Text? { Text("Tap the arrow icon to move money from one category to another.") }
}

struct SiriTip: Tip {
    var title: Text { Text("Use Siri") }
    var message: Text? { Text("Try saying \"How much budget is left in BudgetVault?\"") }
}

struct RecurringExpenseTip: Tip {
    var title: Text { Text("Automate recurring bills") }
    var message: Text? { Text("Set up recurring expenses to auto-track regular bills.") }
}
