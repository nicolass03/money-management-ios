import Foundation

enum PayPeriodLogic {
    struct ScheduleInput {
        let anchorDate: String
        let frequency: PayFrequency
        let lastPaymentDate: String?
    }

    static func scheduleInput(from schedule: IncomePaySchedule) -> ScheduleInput {
        ScheduleInput(anchorDate: schedule.anchorDate, frequency: schedule.frequency, lastPaymentDate: nil)
    }

    static func scheduleInput(from recurring: RecurringExpenseWithTags) -> ScheduleInput {
        ScheduleInput(
            anchorDate: recurring.anchorDate,
            frequency: recurring.frequency,
            lastPaymentDate: recurring.lastPaymentDate
        )
    }

    static func getUpcomingPayDates(schedule: ScheduleInput, count: Int, fromDate: String? = nil) -> [String] {
        let start = fromDate ?? todayISO()
        var dates: [String] = []
        var current = getNextPayDate(schedule: schedule, fromDate: start)

        while dates.count < count {
            if let last = schedule.lastPaymentDate, compareISO(current, last) > 0 {
                break
            }
            dates.append(current)
            current = advancePayDate(schedule: schedule, current: current)
        }
        return dates
    }

    static func getPeriodContaining(schedule: ScheduleInput, date: String) -> PayPeriod {
        let payDate = getNextPayDate(schedule: schedule, fromDate: date)
        let previousPayDate = getPreviousPayDate(schedule: schedule, payDate: payDate)
        return PayPeriod(
            payDate: payDate,
            startDate: addDays(previousPayDate, 1),
            endDate: payDate
        )
    }

    static func getPayDatesInRange(schedule: ScheduleInput, startDate: String, endDate: String) -> [String] {
        let effectiveEnd = effectiveEndDate(schedule: schedule, endDate: endDate)
        if compareISO(startDate, effectiveEnd) > 0 { return [] }

        var dates: [String] = []
        var current = getNextPayDate(schedule: schedule, fromDate: startDate)

        while compareISO(current, effectiveEnd) <= 0 {
            if compareISO(current, startDate) >= 0 {
                dates.append(current)
            }
            current = advancePayDate(schedule: schedule, current: current)
        }
        return dates
    }

    // MARK: - Private helpers

    static func todayISO() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: Date())
    }

    private static func parseDate(_ iso: String) -> (y: Int, m: Int, d: Int) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        return (parts[0], parts[1], parts[2])
    }

    private static func toISO(y: Int, m: Int, d: Int) -> String {
        String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func addDays(_ iso: String, _ days: Int) -> String {
        let (y, m, d) = parseDate(iso)
        var comp = DateComponents()
        comp.year = y
        comp.month = m
        comp.day = d
        let cal = Calendar.current
        let date = cal.date(from: comp)!
        let next = cal.date(byAdding: .day, value: days, to: date)!
        let c = cal.dateComponents([.year, .month, .day], from: next)
        return toISO(y: c.year!, m: c.month!, d: c.day!)
    }

    private static func addMonths(_ iso: String, _ months: Int) -> String {
        let (y, m, d) = parseDate(iso)
        let total = y * 12 + (m - 1) + months
        let newY = total / 12
        let newM = total % 12 + 1
        return toISO(y: newY, m: newM, d: clampDay(newY, newM, d))
    }

    private static func daysInMonth(_ year: Int, _ month: Int) -> Int {
        var comp = DateComponents()
        comp.year = year
        comp.month = month + 1
        comp.day = 0
        return Calendar.current.date(from: comp).map {
            Calendar.current.component(.day, from: $0)
        } ?? 30
    }

    private static func clampDay(_ year: Int, _ month: Int, _ day: Int) -> Int {
        min(day, daysInMonth(year, month))
    }

    private static func compareISO(_ a: String, _ b: String) -> Int {
        a.compare(b) == .orderedAscending ? -1 : (a == b ? 0 : 1)
    }

    private static func daysBetween(_ start: String, _ end: String) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        let s = f.date(from: start)!
        let e = f.date(from: end)!
        return Calendar.current.dateComponents([.day], from: s, to: e).day ?? 0
    }

    private static func intervalDays(_ frequency: PayFrequency) -> Int? {
        switch frequency {
        case .weekly: 7
        case .biweekly: 14
        default: nil
        }
    }

    private static func effectiveEndDate(schedule: ScheduleInput, endDate: String) -> String {
        if let last = schedule.lastPaymentDate, compareISO(last, endDate) < 0 {
            return last
        }
        return endDate
    }

    private static func getNextPayDate(schedule: ScheduleInput, fromDate: String) -> String {
        if let interval = intervalDays(schedule.frequency) {
            return nextIntervalPayDate(anchor: schedule.anchorDate, fromDate: fromDate, intervalDays: interval)
        }
        if schedule.frequency == .yearly {
            return nextYearlyPayDate(anchorDate: schedule.anchorDate, fromDate: fromDate)
        }
        return nextMonthlyPayDate(anchorDate: schedule.anchorDate, fromDate: fromDate)
    }

    private static func nextIntervalPayDate(anchor: String, fromDate: String, intervalDays: Int) -> String {
        if compareISO(fromDate, anchor) <= 0 { return anchor }
        let diff = daysBetween(anchor, fromDate)
        let remainder = diff % intervalDays
        if remainder == 0 { return fromDate }
        return addDays(fromDate, intervalDays - remainder)
    }

    private static func nextMonthlyPayDate(anchorDate: String, fromDate: String) -> String {
        let anchorDay = parseDate(anchorDate).d
        let (y, m, _) = parseDate(fromDate)
        let thisMonth = monthlyPayDate(y: y, m: m, anchorDay: anchorDay)
        if compareISO(thisMonth, fromDate) >= 0 { return thisMonth }
        let (ny, nm) = m == 12 ? (y + 1, 1) : (y, m + 1)
        return monthlyPayDate(y: ny, m: nm, anchorDay: anchorDay)
    }

    private static func nextYearlyPayDate(anchorDate: String, fromDate: String) -> String {
        let (_, anchorMonth, anchorDay) = parseDate(anchorDate)
        let (y, _, _) = parseDate(fromDate)
        let thisYear = toISO(y: y, m: anchorMonth, d: clampDay(y, anchorMonth, anchorDay))
        if compareISO(thisYear, fromDate) >= 0 { return thisYear }
        return toISO(y: y + 1, m: anchorMonth, d: clampDay(y + 1, anchorMonth, anchorDay))
    }

    private static func monthlyPayDate(y: Int, m: Int, anchorDay: Int) -> String {
        toISO(y: y, m: m, d: clampDay(y, m, anchorDay))
    }

    private static func getPreviousPayDate(schedule: ScheduleInput, payDate: String) -> String {
        if let interval = intervalDays(schedule.frequency) {
            return addDays(payDate, -interval)
        }
        if schedule.frequency == .yearly {
            let (y, m, d) = parseDate(payDate)
            return toISO(y: y - 1, m: m, d: clampDay(y - 1, m, d))
        }
        let anchorDay = parseDate(schedule.anchorDate).d
        let (y, m, _) = parseDate(payDate)
        let (py, pm) = m == 1 ? (y - 1, 12) : (y, m - 1)
        return monthlyPayDate(y: py, m: pm, anchorDay: anchorDay)
    }

    private static func advancePayDate(schedule: ScheduleInput, current: String) -> String {
        if let interval = intervalDays(schedule.frequency) {
            return addDays(current, interval)
        }
        if schedule.frequency == .yearly {
            return addMonths(current, 12)
        }
        let anchorDay = parseDate(schedule.anchorDate).d
        let (y, m, _) = parseDate(current)
        let (ny, nm) = m == 12 ? (y + 1, 1) : (y, m + 1)
        return monthlyPayDate(y: ny, m: nm, anchorDay: anchorDay)
    }
}
