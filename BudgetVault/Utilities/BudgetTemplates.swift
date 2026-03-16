import Foundation

/// Shared budget template definitions used by OnboardingView and BudgetTemplateSheetView.
enum BudgetTemplates {

    // MARK: - Onboarding Templates (with percentage allocations)

    enum OnboardingTemplate: String, CaseIterable {
        case single = "Single"
        case couple = "Couple"
        case family = "Family"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .single: return "person.fill"
            case .couple: return "person.2.fill"
            case .family: return "person.3.fill"
            case .custom: return "slider.horizontal.3"
            }
        }

        var categories: [(name: String, emoji: String, color: String, pct: Double)] {
            switch self {
            case .single:
                return [
                    ("Rent", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55", 0.10),
                    ("Entertainment", "\u{1F3AC}", "#AF52DE", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .couple:
                return [
                    ("Housing", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55", 0.10),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Date Night", "\u{2764}\u{FE0F}", "#AF52DE", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .family:
                return [
                    ("Housing", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Kids", "\u{1F476}", "#FF2D55", 0.10),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Utilities", "\u{1F4A1}", "#FFCC00", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .custom:
                return []
            }
        }
    }

    // MARK: - Settings Templates (name + icon + categories without percentages)

    struct SettingsTemplate {
        let name: String
        let icon: String
        let categories: [(name: String, emoji: String, color: String)]
    }

    /// All templates available in the Settings > Budget Templates sheet.
    /// Includes the core onboarding templates plus additional lifestyle templates.
    static let settingsTemplates: [SettingsTemplate] = [
        SettingsTemplate(name: "Single", icon: "person.fill", categories: [
            ("Rent", "\u{1F3E0}", "#5856D6"),
            ("Groceries", "\u{1F6D2}", "#34C759"),
            ("Transport", "\u{1F697}", "#FF9500"),
            ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55"),
            ("Entertainment", "\u{1F3AC}", "#AF52DE"),
            ("Savings", "\u{1F3E6}", "#007AFF"),
        ]),
        SettingsTemplate(name: "Couple", icon: "person.2.fill", categories: [
            ("Housing", "\u{1F3E0}", "#5856D6"),
            ("Groceries", "\u{1F6D2}", "#34C759"),
            ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55"),
            ("Transport", "\u{1F697}", "#FF9500"),
            ("Date Night", "\u{2764}\u{FE0F}", "#AF52DE"),
            ("Savings", "\u{1F3E6}", "#007AFF"),
        ]),
        SettingsTemplate(name: "Family", icon: "person.3.fill", categories: [
            ("Housing", "\u{1F3E0}", "#5856D6"),
            ("Groceries", "\u{1F6D2}", "#34C759"),
            ("Kids", "\u{1F476}", "#FF2D55"),
            ("Transport", "\u{1F697}", "#FF9500"),
            ("Utilities", "\u{1F4A1}", "#FFCC00"),
            ("Savings", "\u{1F3E6}", "#007AFF"),
        ]),
        SettingsTemplate(name: "College Student", icon: "graduationcap.fill", categories: [
            ("Tuition", "\u{1F393}", "#5856D6"),
            ("Food", "\u{1F355}", "#34C759"),
            ("Books", "\u{1F4DA}", "#FF9500"),
            ("Transport", "\u{1F68C}", "#007AFF"),
        ]),
        SettingsTemplate(name: "Debt Payoff", icon: "arrow.down.circle.fill", categories: [
            ("Essentials", "\u{1F3E0}", "#34C759"),
            ("Debt Payment", "\u{1F4B3}", "#FF2D55"),
            ("Savings", "\u{1F3E6}", "#007AFF"),
            ("Minimal Fun", "\u{1F3AE}", "#AF52DE"),
        ]),
        SettingsTemplate(name: "Freelancer", icon: "laptopcomputer", categories: [
            ("Business", "\u{1F4BC}", "#5856D6"),
            ("Taxes", "\u{1F4C4}", "#FF9500"),
            ("Personal", "\u{1F3E0}", "#34C759"),
            ("Savings", "\u{1F3E6}", "#007AFF"),
            ("Healthcare", "\u{1FA7A}", "#FF2D55"),
        ]),
    ]
}
