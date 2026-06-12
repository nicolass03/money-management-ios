import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case expenses
    case budgets
    case income
    case projections

    var id: String { rawValue }

    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .expenses: "chart.bar"
        case .budgets: "folder"
        case .income: "arrow.down.circle"
        case .projections: "calendar"
        }
    }

    var accessibilityLabel: String { "\(label) tab" }
}
