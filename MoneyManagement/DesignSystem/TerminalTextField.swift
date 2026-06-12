import SwiftUI

struct TerminalTextField: View {
    @Environment(\.appPalette) private var palette
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var submitLabel: SubmitLabel = .done
    var showsFocusGlow = true
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFont.mono(size: 12))
                .foregroundStyle(palette.muted)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(AppFont.mono(size: 14))
            .foregroundStyle(palette.text)
            .textContentType(textContentType)
            .submitLabel(submitLabel)
            .focused($isFocused)
            .onSubmit { onSubmit?() }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.bg)
            .overlay {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isFocused ? palette.accent.opacity(0.5) : palette.border, lineWidth: 1)
            }
            .shadow(
                color: showsFocusGlow && isFocused ? palette.glow : .clear,
                radius: showsFocusGlow && isFocused ? 4 : 0,
                x: 0,
                y: 0
            )
        }
    }
}
