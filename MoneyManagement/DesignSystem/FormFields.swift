import SwiftUI

struct AmountTextField: View {
  @Binding var text: String
  var label = L10n.t("amount")
  var placeholder = "0.00"
  var allowsNegative = false

  var body: some View {
    TerminalTextField(
      label: label,
      placeholder: placeholder,
      text: sanitizedText,
      keyboardType: .numbersAndPunctuation
    )
  }

  private var sanitizedText: Binding<String> {
    Binding(
      get: { text },
      set: { text = Self.sanitize($0, allowsNegative: allowsNegative) }
    )
  }

  private static func sanitize(_ value: String, allowsNegative: Bool) -> String {
    var result = ""
    var hasDecimalSeparator = false

    for character in value {
      if character.isNumber {
        result.append(character)
      } else if character == ".", !hasDecimalSeparator {
        result.append(character)
        hasDecimalSeparator = true
      } else if character == "-", allowsNegative, result.isEmpty {
        result.append(character)
      }
    }

    return result
  }
}

struct CurrencyPicker: View {
  @Binding var selection: CurrencyCode

  var body: some View {
    Picker(L10n.t("currency"), selection: $selection) {
      ForEach(CurrencyCode.allCases) { currency in
        Text(currency.label).tag(currency)
      }
    }
    .pickerStyle(.segmented)
  }
}

struct FrequencyPicker: View {
  @Binding var selection: PayFrequency

  var body: some View {
    Picker(L10n.t("frequency"), selection: $selection) {
      ForEach(PayFrequency.allCases) { frequency in
        Text(frequency.label).tag(frequency)
      }
    }
    .pickerStyle(.menu)
    .font(AppFont.mono(size: 14))
  }
}

struct TagsInputField: View {
  @Environment(\.appPalette) private var palette
  @Binding var tagsText: String
  var knownTags: [String] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TerminalTextField(
        label: L10n.t("tags (comma-separated)"),
        placeholder: "food, bills",
        text: $tagsText
      )

      if !knownTags.isEmpty {
        TerminalScrollView(axes: .horizontal) {
          HStack(spacing: 6) {
            ForEach(knownTags.prefix(12), id: \.self) { tag in
              TerminalTagChip(tag: tag) {
                appendTag(tag)
              }
            }
          }
        }
      }
    }
  }

  private func appendTag(_ tag: String) {
    let current = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    if current.contains(tag) { return }
    tagsText = (current + [tag]).joined(separator: ", ")
  }

  static func parseTags(_ text: String) -> [String] {
    text.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
      .filter { !$0.isEmpty }
  }
}

struct SubscriptionToggle: View {
  @Environment(\.appPalette) private var palette
  @Binding var isSubscription: Bool

  var body: some View {
    Toggle(isOn: $isSubscription) {
      Text(L10n.t("subscription"))
        .font(AppFont.mono(size: 14))
        .foregroundStyle(palette.text)
    }
    .tint(palette.accent)
  }
}
