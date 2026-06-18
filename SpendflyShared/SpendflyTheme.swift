import SwiftUI

/// A complete set of semantic colors for one appearance (light or dark) of a theme.
/// Property names mirror the web CSS custom properties and the app's design tokens.
public struct ThemePalette {
    public let bg: Color
    public let surface: Color
    public let surfaceElevated: Color
    public let border: Color
    public let text: Color
    public let muted: Color
    public let accent: Color
    public let accentGlow: Color
    public let success: Color
    public let warning: Color
    public let danger: Color
    public let scanline: Color
    public let glow: Color
    public let glowPulse: Color

    public init(
        bg: Color,
        surface: Color,
        surfaceElevated: Color,
        border: Color,
        text: Color,
        muted: Color,
        accent: Color,
        accentGlow: Color,
        success: Color,
        warning: Color,
        danger: Color,
        scanline: Color,
        glow: Color,
        glowPulse: Color
    ) {
        self.bg = bg
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.border = border
        self.text = text
        self.muted = muted
        self.accent = accent
        self.accentGlow = accentGlow
        self.success = success
        self.warning = warning
        self.danger = danger
        self.scanline = scanline
        self.glow = glow
        self.glowPulse = glowPulse
    }
}

/// A selectable theme: a stable `code` (persisted to user settings) plus a complete palette for
/// both light and dark. Mirrors the web theme registry (src/lib/theme/themes.ts).
public struct SpendflyTheme: Identifiable {
    public let code: String
    /// Localization key for the display name.
    public let nameKey: String
    public let dark: ThemePalette
    public let light: ThemePalette

    public var id: String { code }

    public init(code: String, nameKey: String, dark: ThemePalette, light: ThemePalette) {
        self.code = code
        self.nameKey = nameKey
        self.dark = dark
        self.light = light
    }

    public func palette(for colorScheme: ColorScheme) -> ThemePalette {
        colorScheme == .light ? light : dark
    }
}

/// The theme registry — the single source of truth shared by the app and the widgets.
/// Adding a future theme is a code-only change: define it here and append to `all`.
public enum SpendflyThemes {
    public static let defaultCode = "terminal"

    public static let terminal = SpendflyTheme(
        code: "terminal",
        nameKey: "terminal",
        dark: ThemePalette(
            bg: Color(themeHex: 0x0A0A0A),
            surface: Color(themeHex: 0x141414),
            surfaceElevated: Color(themeHex: 0x1A1A1A),
            border: Color(themeHex: 0x2A2A2A),
            text: Color(themeHex: 0xE8E8E8),
            muted: Color(themeHex: 0x6B6B6B),
            accent: Color(themeHex: 0xD4D4D4),
            accentGlow: Color(themeHex: 0xFFFFFF),
            success: Color(themeHex: 0xA3E635),
            warning: Color(themeHex: 0xFACC15),
            danger: Color(themeHex: 0xF87171),
            scanline: Color.black.opacity(0.03),
            glow: Color.white.opacity(0.12),
            glowPulse: Color.white.opacity(0.08)
        ),
        light: ThemePalette(
            bg: Color(themeHex: 0xF7F7F7),
            surface: Color.white,
            surfaceElevated: Color(themeHex: 0xF0F0F0),
            border: Color(themeHex: 0xE0E0E0),
            text: Color(themeHex: 0x171717),
            muted: Color(themeHex: 0x737373),
            accent: Color(themeHex: 0x404040),
            accentGlow: Color(themeHex: 0x0A0A0A),
            success: Color(themeHex: 0x4D7C0F),
            warning: Color(themeHex: 0xB45309),
            danger: Color(themeHex: 0xF87171),
            scanline: Color.black.opacity(0.015),
            glow: Color.black.opacity(0.08),
            glowPulse: Color.black.opacity(0.06)
        )
    )

    public static let all: [SpendflyTheme] = [terminal]

    /// Resolves a theme by code, falling back to the default theme for unknown/nil codes.
    public static func theme(for code: String?) -> SpendflyTheme {
        all.first { $0.code == code } ?? all[0]
    }
}

private extension Color {
    init(themeHex hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
