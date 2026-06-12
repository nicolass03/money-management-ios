import Foundation

enum UpcomingPayableLogic {
    static func getUpcomingPayableItems(
        expenses: [ExpenseWithTags],
        recurringExpenses: [RecurringExpenseWithTags],
        plannedExpenses: [PlannedExpenseWithTags],
        today: String = PayPeriodLogic.todayISO(),
        horizonDays: Int = 30
    ) -> [PayableFutureItem] {
        let windowEnd = PayPeriodLogic.addDays(today, horizonDays)
        let recurringMaterialized = buildRecurringMaterializedSet(expenses)
        let plannedMaterialized = buildPlannedMaterializedSet(expenses)
        var items: [PayableFutureItem] = []

        for recurring in recurringExpenses {
            if let last = recurring.lastPaymentDate, today > last { continue }

            let input = PayPeriodLogic.scheduleInput(from: recurring)
            let dueDates = PayPeriodLogic.getPayDatesInRange(
                schedule: input,
                startDate: PayPeriodLogic.addDays(today, 1),
                endDate: windowEnd
            )

            for dueDate in dueDates {
                if dueDate <= today { continue }
                if let last = recurring.lastPaymentDate, dueDate > last { continue }
                let key = materializedRecurringKey(recurring.id, dueDate)
                if recurringMaterialized.contains(key) { continue }

                items.append(PayableFutureItem(
                    key: "recurring:\(recurring.id):\(dueDate)",
                    sourceType: "recurring",
                    recurringId: recurring.id,
                    plannedExpenseId: nil,
                    scheduledDate: dueDate,
                    name: recurring.name,
                    amount: recurring.amount,
                    currency: recurring.currency,
                    tags: recurring.tags,
                    isSubscription: recurring.isSubscription
                ))
            }
        }

        for planned in plannedExpenses {
            if planned.date <= today || planned.date > windowEnd { continue }
            if plannedMaterialized.contains(planned.id) { continue }

            items.append(PayableFutureItem(
                key: "planned:\(planned.id):\(planned.date)",
                sourceType: "planned",
                recurringId: nil,
                plannedExpenseId: planned.id,
                scheduledDate: planned.date,
                name: planned.name,
                amount: planned.amount,
                currency: planned.currency,
                tags: planned.tags,
                isSubscription: false
            ))
        }

        return items.sorted {
            if $0.scheduledDate != $1.scheduledDate {
                return $0.scheduledDate < $1.scheduledDate
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func recurringDueDate(_ expense: ExpenseWithTags) -> String {
        expense.scheduledDate ?? expense.date
    }

    private static func materializedRecurringKey(_ recurringId: String, _ dueDate: String) -> String {
        "\(recurringId):\(dueDate)"
    }

    private static func buildRecurringMaterializedSet(_ expenses: [ExpenseWithTags]) -> Set<String> {
        var set = Set<String>()
        for expense in expenses where expense.recurringId != nil {
            set.insert(materializedRecurringKey(expense.recurringId!, recurringDueDate(expense)))
        }
        return set
    }

    private static func buildPlannedMaterializedSet(_ expenses: [ExpenseWithTags]) -> Set<String> {
        Set(expenses.compactMap(\.plannedExpenseId))
    }
}
