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

/// Account picker for the entry forms. Currency follows the chosen account, so forms read
/// their currency from the selection rather than offering a separate currency picker.
struct AccountPicker: View {
  let accounts: [Account]
  @Binding var selection: String?
  /// When true, offer an "auto" option (nil selection). Used by recurring expenses, whose account
  /// is optional — nil means the daily charge job picks an account by currency.
  var includeAutoOption: Bool = false

  /// True when the current selection points at an account absent from `accounts` (archived). Kept
  /// as a selectable option so editing a row never silently rebinds it to a different account.
  private var archivedSelection: String? {
    guard let selection, !accounts.contains(where: { $0.id == selection }) else { return nil }
    return selection
  }

  /// The selected account when it is active (has a known balance to surface at point of entry).
  private var selectedAccount: Account? {
    guard let selection else { return nil }
    return accounts.first { $0.id == selection }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Picker(L10n.t("account"), selection: $selection) {
        if includeAutoOption {
          Text(L10n.t("auto — pick by currency")).tag(String?.none)
        }
        if let archivedSelection {
          Text(L10n.t("archived account")).tag(Optional(archivedSelection))
        }
        ForEach(accounts) { account in
          Text(Self.label(account)).tag(Optional(account.id))
        }
      }
      .pickerStyle(.menu)
      .font(AppFont.mono(size: 14))

      if let selectedAccount {
        Text("\(L10n.t("balance")): \(MoneyFormatter.format(selectedAccount.balance, currency: selectedAccount.currency))")
          .font(AppFont.mono(size: 11))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  static func label(_ account: Account) -> String {
    let trimmed = account.name?.trimmingCharacters(in: .whitespaces)
    let name = (trimmed?.isEmpty == false ? trimmed : nil) ?? L10n.t("unnamed")
    return "\(name) · \(account.currency.label)"
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
