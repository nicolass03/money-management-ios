import SwiftUI

struct TerminalProgressBar: View {
  @Environment(\.appPalette) private var palette

  let spent: Int
  let total: Int

  private var fraction: Double {
    guard total > 0 else { return 0 }
    return min(1, Double(spent) / Double(total))
  }

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(palette.surfaceElevated)

        Rectangle()
          .fill(fraction >= 1 ? palette.danger : palette.accent)
          .frame(width: geo.size.width * fraction)
      }
    }
    .frame(height: 6)
    .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
  }
}
