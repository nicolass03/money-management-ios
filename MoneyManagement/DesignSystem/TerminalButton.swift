import SwiftUI

struct TerminalButton: View {
    @Environment(\.appPalette) private var palette
    let title: String
    var isLoading = false
    var showsGlow = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    TerminalSpinner()
                }
                Text(title)
                    .font(AppFont.mono(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(palette.text)
            .background(palette.surfaceElevated)
            .overlay {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(palette.border, lineWidth: 1)
            }
            .shadow(color: showsGlow ? palette.glow : .clear, radius: showsGlow ? 12 : 0, x: 0, y: 0)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
    }
}

struct ThemeSwitcherButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appPalette) private var palette
    let themeManager: ThemeManager

    var body: some View {
        Button {
            themeManager.cycle()
        } label: {
            Text(themeManager.mode.label(resolvedScheme: colorScheme))
                .font(AppFont.mono(size: 12))
                .foregroundStyle(palette.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .accessibilityLabel("Cycle theme: dark, light, or system")
    }
}
