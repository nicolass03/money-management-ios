import SwiftUI

struct QuickAction: Identifiable {
  let id: String
  let title: String
  let systemImage: String
  let action: () -> Void
}

struct QuickActionBar: View {
  @Environment(\.appPalette) private var palette

  let actions: [QuickAction]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(actions) { item in
        Button(action: item.action) {
          VStack(spacing: 6) {
            Image(systemName: item.systemImage)
              .font(.system(size: 16))
            Text(item.title)
              .font(AppFont.mono(size: 10))
              .lineLimit(1)
          }
          .foregroundStyle(palette.text)
          .frame(maxWidth: .infinity)
          .frame(minHeight: 52)
          .background(palette.surface)
          .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
      }
    }
  }
}
