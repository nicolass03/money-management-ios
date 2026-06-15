import SpendflyShared
import SpendflyShared
import SwiftUI
import WidgetKit

enum WidgetPalette {
    static let bg = Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0A / 255.0)
    static let surfaceElevated = Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0)
    static let border = Color(red: 0x2A / 255.0, green: 0x2A / 255.0, blue: 0x2A / 255.0)
    static let text = Color(red: 0xE8 / 255.0, green: 0xE8 / 255.0, blue: 0xE8 / 255.0)
    static let muted = Color(red: 0x6B / 255.0, green: 0x6B / 255.0, blue: 0x6B / 255.0)
    static let accent = Color(red: 0xD4 / 255.0, green: 0xD4 / 255.0, blue: 0xD4 / 255.0)
    static let warning = Color(red: 0xFA / 255.0, green: 0xCC / 255.0, blue: 0x15 / 255.0)
    static let danger = Color(red: 0xF8 / 255.0, green: 0x71 / 255.0, blue: 0x71 / 255.0)
    static let scanline = Color.black.opacity(0.03)
}

enum WidgetStrings {
    static func totalSpentLabel(language: String) -> String {
        language == "es" ? "gasto total" : "total spent"
    }

    static func extraSpentLabel(language: String) -> String {
        language == "es" ? "gasto extra" : "extra spent"
    }

    static func limitFootnote(amount: String, language: String) -> String {
        language == "es" ? "> / \(amount) límite" : "> / \(amount) limit"
    }

    static func signInPrompt(language: String) -> String {
        language == "es" ? "inicia sesión en spendfly" : "sign in to spendfly"
    }

    static func openAppPrompt(language: String) -> String {
        language == "es" ? "abre la app para actualizar" : "open app to refresh"
    }

    static func setPaySchedulePrompt(language: String) -> String {
        language == "es" ? "configura tu periodo de pago" : "set pay schedule in settings"
    }
}

enum WidgetFont {
    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        SpendflyFont.mono(size: size, weight: weight)
    }
}

// MARK: - Background

struct WidgetTerminalBackground: View {
    var body: some View {
        ZStack {
            WidgetPalette.bg
            WidgetScanlineOverlay()
        }
    }
}

private struct WidgetScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y + 2, width: size.width, height: 2)
                context.fill(Path(rect), with: .color(WidgetPalette.scanline))
                y += 4
            }
        }
    }
}

extension View {
    func widgetTerminalBackground() -> some View {
        containerBackground(for: .widget) {
            WidgetTerminalBackground()
        }
    }
}

// MARK: - Shared layout

struct WidgetMetricView: View {
    @Environment(\.widgetFamily) private var family

    let label: String
    let amount: String
    var amountColor: Color = WidgetPalette.text
    var limitFootnote: String?
    var period: String?
    var progress: (spent: Int, limit: Int)?

    private var amountSize: CGFloat {
        switch family {
        case .systemMedium: return 40
        default: return 32
        }
    }

    private var labelSize: CGFloat {
        family == .systemMedium ? 12 : 11
    }

    private var edgePadding: CGFloat {
        family == .systemMedium ? 16 : 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(WidgetPalette.border)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                headerRow

                Spacer(minLength: 4)

                amountBlock

                if family == .systemSmall, let period, !period.isEmpty {
                    Spacer(minLength: 4)
                    Text(period)
                        .font(WidgetFont.mono(size: 10))
                        .foregroundStyle(WidgetPalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(edgePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var amountBlock: some View {
        switch family {
        case .systemMedium:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(amount)
                        .font(WidgetFont.mono(size: amountSize, weight: .medium))
                        .foregroundStyle(amountColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let limitFootnote {
                        Text(limitFootnote)
                            .font(WidgetFont.mono(size: 11))
                            .foregroundStyle(WidgetPalette.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let progress {
                    WidgetLimitBar(spent: progress.spent, limit: progress.limit)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(amount)
                    .font(WidgetFont.mono(size: amountSize, weight: .medium))
                    .foregroundStyle(amountColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let limitFootnote {
                    Text(limitFootnote)
                        .font(WidgetFont.mono(size: 10))
                        .foregroundStyle(WidgetPalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if let progress {
                    WidgetLimitBar(spent: progress.spent, limit: progress.limit)
                }
            }
        }
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 0) {
                Text("> ")
                    .foregroundStyle(WidgetPalette.accent)
                Text(label)
                    .foregroundStyle(WidgetPalette.muted)
            }
            .font(WidgetFont.mono(size: labelSize))
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            if family == .systemMedium, let period, !period.isEmpty {
                Text(period)
                    .font(WidgetFont.mono(size: 10))
                    .foregroundStyle(WidgetPalette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct WidgetPlaceholderView: View {
    @Environment(\.widgetFamily) private var family

    let message: String

    private var edgePadding: CGFloat {
        family == .systemMedium ? 16 : 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(WidgetPalette.border)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Text("> ")
                        .foregroundStyle(WidgetPalette.accent)
                    Text(message)
                        .foregroundStyle(WidgetPalette.muted)
                }
                .font(WidgetFont.mono(size: family == .systemMedium ? 12 : 11))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(edgePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetLimitBar: View {
    let spent: Int
    let limit: Int

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1, Double(spent) / Double(limit))
    }

    private var fillColor: Color {
        if fraction >= 0.92 { return WidgetPalette.danger }
        if fraction >= 0.70 { return WidgetPalette.warning }
        return WidgetPalette.accent
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(WidgetPalette.surfaceElevated)
                Rectangle()
                    .fill(fillColor)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .overlay(Rectangle().stroke(WidgetPalette.border, lineWidth: 1))
    }
}

func extraSpentColor(extraSpent: Int, limit: Int?) -> Color {
    guard let limit, limit > 0 else { return WidgetPalette.text }
    let usage = Double(extraSpent) / Double(limit)
    if usage >= 0.92 { return WidgetPalette.danger }
    if usage >= 0.70 { return WidgetPalette.warning }
    return WidgetPalette.text
}
