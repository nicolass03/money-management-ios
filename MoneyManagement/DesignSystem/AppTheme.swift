import SpendflyShared
import SwiftUI

enum AppThemeMode: String, CaseIterable {
    case dark
    case light
    case system

    var label: String {
        switch self {
        case .dark: L10n.t("theme: dark")
        case .light: L10n.t("theme: light")
        case .system: L10n.t("theme: system")
        }
    }

    func label(resolvedScheme: ColorScheme) -> String {
        switch self {
        case .system:
            String(
                format: L10n.t("theme: system (%@)"),
                L10n.t(resolvedScheme == .dark ? "dark" : "light")
            )
        default:
            label
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }

    var next: AppThemeMode {
        switch self {
        case .dark: .light
        case .light: .system
        case .system: .dark
        }
    }
}

@Observable
final class ThemeManager {
    /// Light/dark/system appearance — orthogonal to the selected theme palette.
    static let modeStorageKey = "theme"
    /// The selected theme palette code (e.g. "terminal"), kept in sync with user settings.
    static let themeCodeStorageKey = "theme-code"

    var mode: AppThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeStorageKey) }
    }

    var themeCode: String {
        didSet { UserDefaults.standard.set(themeCode, forKey: Self.themeCodeStorageKey) }
    }

    /// The resolved theme definition for the selected code (falls back to the default theme).
    var theme: SpendflyTheme {
        SpendflyThemes.theme(for: themeCode)
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.modeStorageKey),
           let stored = AppThemeMode(rawValue: raw) {
            mode = stored
        } else {
            mode = .dark
        }
        themeCode = UserDefaults.standard.string(forKey: Self.themeCodeStorageKey)
            ?? SpendflyThemes.defaultCode
    }

    func cycle() {
        mode = mode.next
    }

    func setTheme(_ code: String) {
        guard code != themeCode else { return }
        themeCode = code
    }
}

enum AppFont {
    static let monoRegular = "JetBrainsMono-Regular"
    static let monoMedium = "JetBrainsMono-Medium"

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium, .semibold, .bold:
            .custom(monoMedium, size: size)
        default:
            .custom(monoRegular, size: size)
        }
    }
}

struct AppThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var systemColorScheme
    let themeManager: ThemeManager

    private var resolvedScheme: ColorScheme {
        themeManager.mode.colorScheme ?? systemColorScheme
    }

    func body(content: Content) -> some View {
        content
            .environment(\.appPalette, themeManager.theme.palette(for: resolvedScheme))
            .preferredColorScheme(themeManager.mode.colorScheme)
    }
}

extension View {
    func appTheme(_ themeManager: ThemeManager) -> some View {
        modifier(AppThemeModifier(themeManager: themeManager))
    }
}
