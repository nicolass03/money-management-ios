import SpendflyShared
import SwiftUI
import WidgetKit

struct MonthSpentEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct MonthSpentProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthSpentEntry {
        MonthSpentEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                displayCurrency: .eur,
                monthSpent: 125_000,
                monthPeriodLabel: "2025-05-16 → 2025-06-16",
                extraSpent: 0,
                extraSpentLimit: nil,
                payPeriodLabel: nil,
                hasPrimarySchedule: true,
                isSignedIn: true
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthSpentEntry) -> Void) {
        completion(MonthSpentEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthSpentEntry>) -> Void) {
        let entry = MonthSpentEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct MonthSpentWidgetView: View {
    let entry: MonthSpentEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.isSignedIn {
                WidgetMetricView(
                    label: WidgetStrings.totalSpentLabel(language: snapshot.language),
                    amount: SharedMoneyFormatter.format(snapshot.monthSpent, currency: snapshot.displayCurrency),
                    period: snapshot.monthPeriodLabel.isEmpty ? nil : snapshot.monthPeriodLabel
                )
            } else if let snapshot = entry.snapshot, !snapshot.isSignedIn {
                WidgetPlaceholderView(message: WidgetStrings.signInPrompt(language: snapshot.language))
            } else {
                WidgetPlaceholderView(message: WidgetStrings.openAppPrompt(language: "en"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetTerminalBackground()
    }
}

struct MonthSpentWidget: Widget {
    let kind = "MonthSpentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthSpentProvider()) { entry in
            MonthSpentWidgetView(entry: entry)
        }
        .configurationDisplayName("Month Spent")
        .description("Total spent in the last month.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
