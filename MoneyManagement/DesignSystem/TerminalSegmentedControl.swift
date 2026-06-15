import SwiftUI

struct TerminalSegmentedControl<T: Hashable & Identifiable>: View where T: CustomStringConvertible {
  @Environment(\.appPalette) private var palette
  @Binding var selection: T
  let options: [T]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(options) { option in
        Button {
          selection = option
        } label: {
          Text(option.description)
            .font(AppFont.mono(size: 11, weight: selection == option ? .medium : .regular))
            .foregroundStyle(selection == option ? palette.text : palette.muted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 40)
            .background(selection == option ? palette.surfaceElevated : palette.surface)
        }
        .buttonStyle(.plain)
      }
    }
    .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
  }
}

extension ExpensePeriodKey: CustomStringConvertible {
  var description: String { label }
}

enum IncomeSection: String, CaseIterable, Identifiable, CustomStringConvertible {
  case schedules, entries

  var id: String { rawValue }
  var description: String {
    switch self {
    case .schedules: L10n.t("schedules")
    case .entries: L10n.t("entries")
    }
  }
}
