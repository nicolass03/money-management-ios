import Foundation

enum ProjectionDisplayLogic {
    static let futurePeriodLimit = 10

    static func visibleRows(
        from rows: [ProjectionRow],
        today: String = PayPeriodLogic.todayISO()
    ) -> [ProjectionRow] {
        guard !rows.isEmpty else { return [] }

        let sorted = rows.sorted { $0.payDate < $1.payDate }

        if let currentIndex = sorted.firstIndex(where: { today >= $0.startDate && today <= $0.endDate }) {
            let current = sorted[currentIndex]
            let following = sorted[(currentIndex + 1)...].prefix(futurePeriodLimit)
            return [current] + following
        }

        if let upcomingIndex = sorted.firstIndex(where: { $0.endDate >= today }) {
            let anchor = sorted[upcomingIndex]
            let following = sorted[(upcomingIndex + 1)...].prefix(futurePeriodLimit)
            return [anchor] + following
        }

        if let latest = sorted.last {
            return [latest]
        }

        return []
    }
}
