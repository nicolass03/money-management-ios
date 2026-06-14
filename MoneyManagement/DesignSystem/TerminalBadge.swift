import SwiftUI

struct TerminalBadge: View {
  @Environment(\.appPalette) private var palette

  let text: String
  var style: Style = .muted

  enum Style {
    case muted, accent, success, danger, warning
  }

  var body: some View {
    Text(text)
      .font(AppFont.mono(size: 10, weight: .medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(background)
      .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
  }

  private var foreground: Color {
    switch style {
    case .muted: palette.muted
    case .accent: palette.accent
    case .success: palette.success
    case .danger: palette.danger
    case .warning: palette.warning
    }
  }

  private var background: Color {
    switch style {
    case .muted: palette.surface
    case .accent: palette.surfaceElevated
    case .success: palette.surfaceElevated
    case .danger: palette.surfaceElevated
    case .warning: palette.surfaceElevated
    }
  }
}
