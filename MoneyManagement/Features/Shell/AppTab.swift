import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case expenses
    case budgets
    case income
    case accounts
    case projections

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expenses: L10n.t("expenses")
        case .budgets: L10n.t("budgets")
        case .income: L10n.t("income")
        case .accounts: L10n.t("accounts")
        case .projections: L10n.t("projections")
        }
    }

    var systemImage: String {
        switch self {
        case .expenses: "chart.bar"
        case .budgets: "folder"
        case .income: "arrow.down.circle"
        case .accounts: "wallet.pass"
        case .projections: "calendar"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .expenses: L10n.t("expenses tab")
        case .budgets: L10n.t("budgets tab")
        case .income: L10n.t("income tab")
        case .accounts: L10n.t("accounts tab")
        case .projections: L10n.t("projections tab")
        }
    }
}
