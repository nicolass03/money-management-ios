import Foundation

enum ProjectionDisplayLogic {
    static let futurePeriodLimit = 10
    static let pastPeriodLimit = 2

    static func visibleRows(
        from rows: [ProjectionRow],
        today: String = PayPeriodLogic.todayISO()
    ) -> [ProjectionRow] {
        guard !rows.isEmpty else { return [] }

        let sorted = rows.sorted { $0.payDate < $1.payDate }

        if let currentIndex = sorted.firstIndex(where: { today >= $0.startDate && today <= $0.endDate }) {
            let precedingStart = max(0, currentIndex - pastPeriodLimit)
            let preceding = sorted[precedingStart..<currentIndex]
            let current = sorted[currentIndex]
            let following = sorted[(currentIndex + 1)...].prefix(futurePeriodLimit)
            return Array(preceding) + [current] + following
        }

        if let upcomingIndex = sorted.firstIndex(where: { $0.endDate >= today }) {
            let precedingStart = max(0, upcomingIndex - pastPeriodLimit)
            let preceding = sorted[precedingStart..<upcomingIndex]
            let anchor = sorted[upcomingIndex]
            let following = sorted[(upcomingIndex + 1)...].prefix(futurePeriodLimit)
            return Array(preceding) + [anchor] + following
        }

        let lastIndex = sorted.count - 1
        let start = max(0, lastIndex - pastPeriodLimit)
        return Array(sorted[start...lastIndex])
    }
}
