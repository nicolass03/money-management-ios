import Foundation

enum IncomeFilterLogic {
    static func filterEntriesForDisplay(
        entries: [Income],
        schedules: [IncomePaySchedule],
        today: String = PayPeriodLogic.todayISO()
    ) -> [Income] {
        let manual = entries.filter { $0.isManual }

        var scheduledByKey: [String: Income] = [:]
        for entry in entries where entry.scheduleId != nil && entry.source == .scheduled {
            scheduledByKey["\(entry.scheduleId!):\(entry.date)"] = entry
        }

        var nextScheduled: [Income] = []
        for schedule in schedules {
            let input = PayPeriodLogic.scheduleInput(from: schedule)
            let dates = PayPeriodLogic.getUpcomingPayDates(schedule: input, count: 1, fromDate: today)
            guard let nextDate = dates.first else { continue }
            if let entry = scheduledByKey["\(schedule.id):\(nextDate)"] {
                nextScheduled.append(entry)
            }
        }

        return (manual + nextScheduled).sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.createdAt > $1.createdAt
        }
    }
}
