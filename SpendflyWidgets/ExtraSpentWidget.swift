import SpendflyShared
import SwiftUI
import WidgetKit

struct ExtraSpentEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ExtraSpentProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExtraSpentEntry {
        ExtraSpentEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                displayCurrency: .eur,
                monthSpent: 0,
                monthPeriodLabel: "",
                extraSpent: 45_000,
                extraSpentLimit: 100_000,
                payPeriodLabel: "2025-06-01 → 2025-06-15",
                hasPrimarySchedule: true,
                isSignedIn: true
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ExtraSpentEntry) -> Void) {
        completion(ExtraSpentEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExtraSpentEntry>) -> Void) {
        let entry = ExtraSpentEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct ExtraSpentWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ExtraSpentEntry

    private var palette: ThemePalette {
        widgetPalette(for: entry.snapshot, environmentScheme: colorScheme)
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.isSignedIn {
                if snapshot.hasPrimarySchedule {
                    extraSpentContent(snapshot: snapshot)
                } else {
                    WidgetPlaceholderView(message: WidgetStrings.setPaySchedulePrompt(language: snapshot.language))
                }
            } else if let snapshot = entry.snapshot, !snapshot.isSignedIn {
                WidgetPlaceholderView(message: WidgetStrings.signInPrompt(language: snapshot.language))
            } else {
                WidgetPlaceholderView(message: WidgetStrings.openAppPrompt(language: "en"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.widgetPalette, palette)
        .widgetTerminalBackground(palette: palette)
    }

    @ViewBuilder
    private func extraSpentContent(snapshot: WidgetSnapshot) -> some View {
        let limit = snapshot.extraSpentLimit
        let limitFootnote: String? = {
            guard let limit, limit > 0 else { return nil }
            return WidgetStrings.limitFootnote(
                amount: SharedMoneyFormatter.format(limit, currency: snapshot.displayCurrency),
                language: snapshot.language
            )
        }()
        let progress: (spent: Int, limit: Int)? = {
            guard let limit, limit > 0 else { return nil }
            return (snapshot.extraSpent, limit)
        }()

        WidgetMetricView(
            label: WidgetStrings.extraSpentLabel(language: snapshot.language),
            amount: SharedMoneyFormatter.format(snapshot.extraSpent, currency: snapshot.displayCurrency),
            amountColor: extraSpentColor(extraSpent: snapshot.extraSpent, limit: limit, palette: palette),
            limitFootnote: limitFootnote,
            period: snapshot.payPeriodLabel,
            progress: progress
        )
    }
}

struct ExtraSpentWidget: Widget {
    let kind = "ExtraSpentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExtraSpentProvider()) { entry in
            ExtraSpentWidgetView(entry: entry)
        }
        .configurationDisplayName("Extra Spent")
        .description("Unplanned spend in the current pay period.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
