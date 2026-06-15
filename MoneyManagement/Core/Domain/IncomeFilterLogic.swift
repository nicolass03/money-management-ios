import Foundation

enum IncomeFilterLogic {
    /// Income entries for display. Scheduled income is now materialized by the daily cron
    /// (one actual row per pay date), so every entry — manual or scheduled — is a real
    /// registry the user can edit/delete. Deleted scheduled rows are tombstoned server-side
    /// and never reach the client, so only sorting is needed.
    static func filterEntriesForDisplay(entries: [Income]) -> [Income] {
        entries.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.createdAt > $1.createdAt
        }
    }
}
