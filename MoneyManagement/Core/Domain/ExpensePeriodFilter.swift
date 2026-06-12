import Foundation

enum ExpensePeriodFilter {
    static func resolvePeriodDates(
        periodKey: ExpensePeriodKey,
        primarySchedule: IncomePaySchedule?,
        today: String = PayPeriodLogic.todayISO()
    ) -> PayPeriod? {
        switch periodKey {
        case .lastPeriod:
            guard let schedule = primarySchedule else { return nil }
            return PayPeriodLogic.getPeriodContaining(
                schedule: PayPeriodLogic.scheduleInput(from: schedule),
                date: today
            )
        case .lastMonth:
            return PayPeriod(payDate: today, startDate: addMonths(today, -1), endDate: today)
        case .last3Months:
            return PayPeriod(payDate: today, startDate: addMonths(today, -3), endDate: today)
        }
    }

    static func filterExpenses(
        _ expenses: [ExpenseWithTags],
        periodKey: ExpensePeriodKey,
        primarySchedule: IncomePaySchedule?,
        today: String = PayPeriodLogic.todayISO()
    ) -> [ExpenseWithTags] {
        guard let period = resolvePeriodDates(periodKey: periodKey, primarySchedule: primarySchedule, today: today) else {
            return []
        }
        return expenses.filter { isDateInRange($0.date, period.startDate, period.endDate) }
    }

    static func isDateInRange(_ date: String, _ start: String, _ end: String) -> Bool {
        date >= start && date <= end
    }

    private static func addMonths(_ iso: String, _ months: Int) -> String {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        let total = parts[0] * 12 + (parts[1] - 1) + months
        let y = total / 12
        let m = total % 12 + 1
        let d = parts[2]
        var comp = DateComponents()
        comp.year = y
        comp.month = m + 1
        comp.day = 0
        let maxDay = Calendar.current.date(from: comp).map {
            Calendar.current.component(.day, from: $0)
        } ?? 28
        return String(format: "%04d-%02d-%02d", y, m, min(d, maxDay))
    }
}
