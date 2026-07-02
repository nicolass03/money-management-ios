import Foundation

enum BudgetStatus: String, CaseIterable, Hashable {
    case active, upcoming, open, ended, depleted

    var label: String {
        switch self {
        case .active: L10n.t("active")
        case .upcoming: L10n.t("upcoming")
        case .open: L10n.t("open")
        case .ended: L10n.t("ended")
        case .depleted: L10n.t("depleted")
        }
    }
}

enum BudgetTab: String, CaseIterable, Identifiable {
    case active, history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active: L10n.t("active")
        case .history: L10n.t("history")
        }
    }
}

enum BudgetStatusLogic {
    static func isDatedBudget(_ budget: BudgetWithTags) -> Bool {
        budget.startDate != nil && budget.endDate != nil
    }

    static func isInHistory(_ budget: BudgetWithTags, today: String = PayPeriodLogic.todayISO()) -> Bool {
        if budget.completedAt != nil { return true }
        guard isDatedBudget(budget), let end = budget.endDate else { return false }
        return today > end
    }

    static func isFinishable(_ budget: BudgetWithTags, today: String = PayPeriodLogic.todayISO()) -> Bool {
        !isInHistory(budget, today: today)
    }

    static func status(for budget: BudgetWithTags, today: String = PayPeriodLogic.todayISO()) -> BudgetStatus {
        if budget.completedAt != nil { return .ended }
        if budget.spent >= budget.amount { return .depleted }
        guard isDatedBudget(budget),
              let start = budget.startDate,
              let end = budget.endDate else {
            return .open
        }
        if today < start { return .upcoming }
        if today > end { return .ended }
        return .active
    }

    static func grouped(_ budgets: [BudgetWithTags], today: String = PayPeriodLogic.todayISO()) -> [(BudgetStatus, [BudgetWithTags])] {
        let order: [BudgetStatus] = [.active, .upcoming, .open, .ended, .depleted]
        let grouped = Dictionary(grouping: budgets) { status(for: $0, today: today) }
        return order.compactMap { status in
            guard let items = grouped[status], !items.isEmpty else { return nil }
            return (status, items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    static func filtered(_ budgets: [BudgetWithTags], tab: BudgetTab, today: String = PayPeriodLogic.todayISO()) -> [BudgetWithTags] {
        budgets.filter { budget in
            let inHistory = isInHistory(budget, today: today)
            return tab == .history ? inHistory : !inHistory
        }
    }
}

extension BudgetTab: CustomStringConvertible {
    var description: String { label }
}
