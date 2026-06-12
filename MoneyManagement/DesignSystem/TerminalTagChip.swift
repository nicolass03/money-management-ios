import SwiftUI

struct TerminalTagChip: View {
  @Environment(\.appPalette) private var palette

  let tag: String
  var isSelected: Bool = false
  var action: (() -> Void)?

  var body: some View {
    Group {
      if let action {
        Button(action: action) { chip }
          .buttonStyle(.plain)
      } else {
        chip
      }
    }
  }

  private var chip: some View {
    Text("#\(tag)")
      .font(AppFont.mono(size: 10))
      .foregroundStyle(isSelected ? palette.accent : palette.muted)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(isSelected ? palette.surfaceElevated : palette.surface)
      .overlay(Rectangle().stroke(isSelected ? palette.accent : palette.border, lineWidth: 1))
  }
}

struct TerminalTagFlow: View {
  let tags: [String]

  var body: some View {
    FlowLayout(spacing: 6) {
      ForEach(tags, id: \.self) { tag in
        TerminalTagChip(tag: tag)
      }
    }
  }
}

private struct FlowLayout: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = arrange(proposal: proposal, subviews: subviews)
    return result.size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let result = arrange(proposal: proposal, subviews: subviews)
    for (index, frame) in result.frames.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(frame.size)
      )
    }
  }

  private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var frames: [CGRect] = []

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
    }

    return (CGSize(width: maxWidth, height: y + rowHeight), frames)
  }
}
