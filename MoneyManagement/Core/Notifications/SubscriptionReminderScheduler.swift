import Foundation
import UserNotifications

/// Schedules on-device local notifications that nudge the user to cancel a subscription before it
/// renews. The backend only stores the `cancelReminderEnabled` flag; the device computes each
/// subscription's next charge date and schedules notifications at 09:00 local time, 5 and 2 days
/// before it. Remote push is intentionally not used — it requires a paid Apple Developer account,
/// whereas local notifications work with a free personal team.
enum SubscriptionReminderScheduler {
    private static let identifierPrefix = "cancel-reminder-"
    private static let leadDays = [5, 2]
    private static let notificationHour = 9

    /// Asks for notification permission. Safe to call repeatedly — the system only prompts once.
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Rebuilds every cancellation-reminder notification from the current recurring expenses.
    /// Idempotent: it first removes all previously scheduled cancel-reminder requests, then re-adds
    /// the ones still in the future, so it always reflects the latest flags and charge dates.
    static func reschedule(from recurring: [RecurringExpenseWithTags]) async {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else {
            return
        }

        let pending = await center.pendingNotificationRequests()
        let staleIds = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)

        let today = PayPeriodLogic.todayISO()
        for item in recurring where item.isSubscription && item.cancelReminderEnabled {
            let schedule = PayPeriodLogic.scheduleInput(from: item)
            guard let nextCharge = PayPeriodLogic
                .getUpcomingPayDates(schedule: schedule, count: 1)
                .first
            else {
                continue
            }

            for lead in leadDays {
                let fireDate = PayPeriodLogic.addDays(nextCharge, -lead)
                // ISO yyyy-MM-dd sorts lexicographically, so a string compare is a date compare.
                if fireDate <= today { continue }
                guard let request = makeRequest(
                    item: item,
                    fireDateISO: fireDate,
                    chargeDateISO: nextCharge,
                    lead: lead
                ) else { continue }
                try? await center.add(request)
            }
        }
    }

    private static func makeRequest(
        item: RecurringExpenseWithTags,
        fireDateISO: String,
        chargeDateISO: String,
        lead: Int
    ) -> UNNotificationRequest? {
        let parts = fireDateISO.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = notificationHour

        let content = UNMutableNotificationContent()
        content.title = L10n.t("Subscription renewal")
        content.body = String(
            format: L10n.t("%1$@ renews on %2$@ — cancel it now if you no longer want it."),
            item.name,
            chargeDateISO
        )
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // Stable, deterministic id → re-running reschedule replaces rather than duplicates.
        let identifier = "\(identifierPrefix)\(item.id)-\(lead)-\(chargeDateISO)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
