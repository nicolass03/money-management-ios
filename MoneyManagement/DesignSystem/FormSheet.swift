import SwiftUI

struct FormSheet<Content: View>: View {
  @Environment(\.appPalette) private var palette
  @Environment(\.dismiss) private var dismiss

  let title: String
  var isSaving: Bool = false
  var canSave: Bool = true
  let onSave: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    NavigationStack {
      ZStack {
        palette.bg.ignoresSafeArea()

        TerminalScrollView {
          VStack(alignment: .leading, spacing: 16) {
            content()
          }
          .padding(16)
        }
      }
      .scanlineOverlay()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("cancel") { dismiss() }
            .font(AppFont.mono(size: 12))
            .foregroundStyle(palette.muted)
            .disabled(isSaving)
        }
        ToolbarItem(placement: .principal) {
          Text(title)
            .font(AppFont.mono(size: 14, weight: .medium))
            .foregroundStyle(palette.text)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "..." : "save") { onSave() }
            .font(AppFont.mono(size: 12, weight: .medium))
            .foregroundStyle(canSave && !isSaving ? palette.accent : palette.muted)
            .disabled(!canSave || isSaving)
        }
      }
    }
  }
}

struct ErrorBanner: View {
  @Environment(\.appPalette) private var palette

  let message: String
  var onRetry: (() -> Void)?

  var body: some View {
    TerminalCard {
      HStack(alignment: .top, spacing: 12) {
        Text("> \(message)")
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.danger)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let onRetry {
          Button("retry", action: onRetry)
            .font(AppFont.mono(size: 12, weight: .medium))
            .foregroundStyle(palette.accent)
        }
      }
    }
  }
}

struct MoneyLabel: View {
  @Environment(\.appPalette) private var palette

  let amount: Int
  let currency: CurrencyCode
  var displayCurrency: CurrencyCode?
  var rates: ExchangeRates?
  var size: CGFloat = 14
  var weight: Font.Weight = .regular

  var body: some View {
    Text(MoneyFormatter.format(amount, currency: currency, displayCurrency: displayCurrency, rates: rates))
      .font(AppFont.mono(size: size, weight: weight))
      .foregroundStyle(palette.text)
  }
}

enum Haptics {
  static func light() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  static func success() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }

  static func warning() {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
  }
}
