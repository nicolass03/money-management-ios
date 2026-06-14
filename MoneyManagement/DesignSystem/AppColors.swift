import SwiftUI

enum AppColors {
    struct Palette {
        let bg: Color
        let surface: Color
        let surfaceElevated: Color
        let border: Color
        let text: Color
        let muted: Color
        let accent: Color
        let accentGlow: Color
        let success: Color
        let warning: Color
        let danger: Color
        let scanline: Color
        let glow: Color
        let glowPulse: Color
    }

    static func palette(for colorScheme: ColorScheme) -> Palette {
        switch colorScheme {
        case .dark:
            return Palette(
                bg: Color(hex: 0x0A0A0A),
                surface: Color(hex: 0x141414),
                surfaceElevated: Color(hex: 0x1A1A1A),
                border: Color(hex: 0x2A2A2A),
                text: Color(hex: 0xE8E8E8),
                muted: Color(hex: 0x6B6B6B),
                accent: Color(hex: 0xD4D4D4),
                accentGlow: Color(hex: 0xFFFFFF),
                success: Color(hex: 0xA3E635),
                warning: Color(hex: 0xFACC15),
                danger: Color(hex: 0xF87171),
                scanline: Color.black.opacity(0.03),
                glow: Color.white.opacity(0.12),
                glowPulse: Color.white.opacity(0.08)
            )
        case .light:
            return Palette(
                bg: Color(hex: 0xF7F7F7),
                surface: Color.white,
                surfaceElevated: Color(hex: 0xF0F0F0),
                border: Color(hex: 0xE0E0E0),
                text: Color(hex: 0x171717),
                muted: Color(hex: 0x737373),
                accent: Color(hex: 0x404040),
                accentGlow: Color(hex: 0x0A0A0A),
                success: Color(hex: 0x4D7C0F),
                warning: Color(hex: 0xB45309),
                danger: Color(hex: 0xF87171),
                scanline: Color.black.opacity(0.015),
                glow: Color.black.opacity(0.08),
                glowPulse: Color.black.opacity(0.06)
            )
        @unknown default:
            return palette(for: .dark)
        }
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppColors.palette(for: .dark)
}

extension EnvironmentValues {
    var appPalette: AppColors.Palette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}
