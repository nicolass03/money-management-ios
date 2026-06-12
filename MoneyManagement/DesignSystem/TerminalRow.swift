import SwiftUI

struct TerminalRow: View {
  @Environment(\.appPalette) private var palette

  let title: String
  var subtitle: String?
  var trailing: String?
  var showChevron: Bool = false
  var action: (() -> Void)?

  var body: some View {
    Group {
      if let action {
        Button(action: action) { rowContent }
          .buttonStyle(.plain)
      } else {
        rowContent
      }
    }
    .frame(minHeight: 44)
  }

  private var rowContent: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(AppFont.mono(size: 14))
          .foregroundStyle(palette.text)
          .lineLimit(1)

        if let subtitle {
          Text(subtitle)
            .font(AppFont.mono(size: 11))
            .foregroundStyle(palette.muted)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 8)

      if let trailing {
        Text(trailing)
          .font(AppFont.mono(size: 13, weight: .medium))
          .foregroundStyle(palette.text)
      }

      if showChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(palette.muted)
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
    .background(palette.surface)
    .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
  }
}
