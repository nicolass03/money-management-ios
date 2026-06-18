import SpendflyShared
import SpendflyShared
import SwiftUI
import WidgetKit

// Widgets resolve a `ThemePalette` (shared with the app) from the snapshot's theme + mode and
// inject it via the environment so all subviews read the same palette.
struct WidgetPaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = SpendflyThemes.theme(for: nil).palette(for: .dark)
}

extension EnvironmentValues {
    var widgetPalette: ThemePalette {
        get { self[WidgetPaletteKey.self] }
        set { self[WidgetPaletteKey.self] = newValue }
    }
}

/// Resolves the palette for a snapshot: the theme code picks the palette family, `themeMode`
/// picks light/dark (with "system" deferring to the widget's environment color scheme).
func widgetPalette(for snapshot: WidgetSnapshot?, environmentScheme: ColorScheme) -> ThemePalette {
    let theme = SpendflyThemes.theme(for: snapshot?.theme)
    let scheme: ColorScheme
    switch snapshot?.themeMode {
    case "light": scheme = .light
    case "dark": scheme = .dark
    default: scheme = environmentScheme
    }
    return theme.palette(for: scheme)
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
    let palette: ThemePalette

    var body: some View {
        ZStack {
            palette.bg
            WidgetScanlineOverlay(palette: palette)
        }
    }
}

private struct WidgetScanlineOverlay: View {
    let palette: ThemePalette

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y + 2, width: size.width, height: 2)
                context.fill(Path(rect), with: .color(palette.scanline))
                y += 4
            }
        }
    }
}

extension View {
    func widgetTerminalBackground(palette: ThemePalette) -> some View {
        containerBackground(for: .widget) {
            WidgetTerminalBackground(palette: palette)
        }
    }
}

// MARK: - Shared layout

struct WidgetMetricView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetPalette) private var palette

    let label: String
    let amount: String
    /// Defaults to the palette's text color when nil (resolved in the body).
    var amountColor: Color?
    var limitFootnote: String?
    var period: String?
    var progress: (spent: Int, limit: Int)?

    private var resolvedAmountColor: Color {
        amountColor ?? palette.text
    }

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
                .fill(palette.border)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                headerRow

                Spacer(minLength: 4)

                amountBlock

                if family == .systemSmall, let period, !period.isEmpty {
                    Spacer(minLength: 4)
                    Text(period)
                        .font(WidgetFont.mono(size: 10))
                        .foregroundStyle(palette.muted)
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
                        .foregroundStyle(resolvedAmountColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if let limitFootnote {
                        Text(limitFootnote)
                            .font(WidgetFont.mono(size: 11))
                            .foregroundStyle(palette.muted)
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
                    .foregroundStyle(resolvedAmountColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let limitFootnote {
                    Text(limitFootnote)
                        .font(WidgetFont.mono(size: 10))
                        .foregroundStyle(palette.muted)
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
                    .foregroundStyle(palette.accent)
                Text(label)
                    .foregroundStyle(palette.muted)
            }
            .font(WidgetFont.mono(size: labelSize))
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            if family == .systemMedium, let period, !period.isEmpty {
                Text(period)
                    .font(WidgetFont.mono(size: 10))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct WidgetPlaceholderView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetPalette) private var palette

    let message: String

    private var edgePadding: CGFloat {
        family == .systemMedium ? 16 : 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Text("> ")
                        .foregroundStyle(palette.accent)
                    Text(message)
                        .foregroundStyle(palette.muted)
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
    @Environment(\.widgetPalette) private var palette

    let spent: Int
    let limit: Int

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1, Double(spent) / Double(limit))
    }

    private var fillColor: Color {
        if fraction >= 0.92 { return palette.danger }
        if fraction >= 0.70 { return palette.warning }
        return palette.accent
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(palette.surfaceElevated)
                Rectangle()
                    .fill(fillColor)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
    }
}

func extraSpentColor(extraSpent: Int, limit: Int?, palette: ThemePalette) -> Color {
    guard let limit, limit > 0 else { return palette.text }
    let usage = Double(extraSpent) / Double(limit)
    if usage >= 0.92 { return palette.danger }
    if usage >= 0.70 { return palette.warning }
    return palette.text
}
