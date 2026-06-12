import SwiftUI

struct LoginView: View {
    @Environment(\.appPalette) private var palette
    @Bindable var viewModel: LoginViewModel
    let themeManager: ThemeManager

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    ThemeSwitcherButton(themeManager: themeManager)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    header

                    TerminalCard(showsGlow: false) {
                        VStack(spacing: 16) {
                            TerminalTextField(
                                label: "enter email:",
                                placeholder: "you@example.com",
                                text: $viewModel.email,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress,
                                submitLabel: .next,
                                showsFocusGlow: false
                            ) {
                                focusedField = .password
                            }
                            .focused($focusedField, equals: .email)

                            TerminalTextField(
                                label: "enter password:",
                                placeholder: "••••••••",
                                text: $viewModel.password,
                                isSecure: true,
                                textContentType: .password,
                                submitLabel: .go,
                                showsFocusGlow: false
                            ) {
                                Task { await viewModel.authenticate() }
                            }
                            .focused($focusedField, equals: .password)

                            rememberMeRow

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(AppFont.mono(size: 12))
                                    .foregroundStyle(palette.danger)
                            }

                            TerminalButton(
                                title: viewModel.isLoading ? "authenticating..." : "authenticate",
                                isLoading: viewModel.isLoading,
                                showsGlow: true
                            ) {
                                Task { await viewModel.authenticate() }
                            }
                        }
                    }
                    .overlay {
                        if viewModel.isLoading {
                            LoadingCardOverlay(label: "authenticating")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 480)

                Spacer()
            }
        }
        .scanlineOverlay()
        .onAppear {
            focusedField = viewModel.rememberMe ? .password : .email
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppBrand.versionLabel)
                .font(AppFont.mono(size: 12))
                .foregroundStyle(palette.muted)

            HStack(spacing: 0) {
                Text("guest")
                    .foregroundStyle(palette.accent)
                Text(":")
                    .foregroundStyle(palette.muted)
                Text("~")
                    .foregroundStyle(palette.accentGlow)
                Text("$")
                    .foregroundStyle(palette.muted)
                Text(" auth --login")
                    .foregroundStyle(palette.text)
                BlinkingCursor()
            }
            .font(AppFont.mono(size: 14))
        }
    }

    private var rememberMeRow: some View {
        Button {
            viewModel.rememberMe.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.rememberMe ? palette.accent : palette.muted)
                Text("remember me")
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
