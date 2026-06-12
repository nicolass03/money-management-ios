import Foundation

enum BudgetStatus: String, CaseIterable, Hashable {
    case active, upcoming, open, ended, depleted

    var label: String { rawValue }
}

enum BudgetStatusLogic {
    static func isDatedBudget(_ budget: BudgetWithTags) -> Bool {
        budget.startDate != nil && budget.endDate != nil
    }

    static func status(for budget: BudgetWithTags, today: String = PayPeriodLogic.todayISO()) -> BudgetStatus {
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
}
