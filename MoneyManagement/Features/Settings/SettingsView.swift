import SwiftUI

struct SettingsView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let sessionStore: SessionStore
    let themeManager: ThemeManager
    @Bindable var viewModel: SettingsViewModel

    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                palette.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeader(title: "settings", subtitle: "configure app preferences")

                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error) {
                                Task { await viewModel.load() }
                            }
                        }

                        sessionSection
                        themeSection
                        currencySection
                        projectionSection
                        logoutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }

                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
            .scanlineOverlay()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("settings")
                        .font(AppFont.mono(size: 14, weight: .medium))
                        .foregroundStyle(palette.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .font(AppFont.mono(size: 12))
                        .foregroundStyle(palette.muted)
                }
            }
            .task { await viewModel.load() }
        }
    }

    private var sessionSection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("> session")
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)
                Text(sessionStore.session?.user.email ?? "unknown")
                    .font(AppFont.mono(size: 14))
                    .foregroundStyle(palette.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var themeSection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("> appearance")
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)

                Button { themeManager.cycle() } label: {
                    HStack {
                        Text(themeManager.mode.label(resolvedScheme: colorScheme))
                            .font(AppFont.mono(size: 14))
                            .foregroundStyle(palette.text)
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(palette.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var currencySection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("> currency")
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)

                Picker("display currency", selection: $viewModel.displayCurrency) {
                    ForEach(CurrencyCode.allCases) { currency in
                        Text(currency.label).tag(currency)
                    }
                }
                .pickerStyle(.segmented)

                Text("> primary pay schedule")
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 8)

                Picker("primary schedule", selection: $viewModel.primaryScheduleId) {
                    Text("none").tag(Optional<String>.none)
                    ForEach(viewModel.schedules) { schedule in
                        Text(schedule.name).tag(Optional(schedule.id))
                    }
                }
                .pickerStyle(.menu)
                .font(AppFont.mono(size: 14))

                TerminalButton(title: viewModel.isSaving ? "saving..." : "save preferences", isLoading: viewModel.isSaving) {
                    Task {
                        if await viewModel.save() {
                            dismiss()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var projectionSection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("> projections")
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)

                TerminalTextField(
                    label: "initial free money (minor units)",
                    placeholder: "0",
                    text: $viewModel.projectionInitialFreeMoneyText,
                    keyboardType: .numberPad
                )

                TerminalTextField(
                    label: "projection start date (YYYY-MM-DD)",
                    placeholder: "optional",
                    text: $viewModel.projectionStartDate,
                    keyboardType: .numbersAndPunctuation
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var logoutSection: some View {
        TerminalButton(title: isSigningOut ? "signing out..." : "logout", isLoading: isSigningOut) {
            Task {
                isSigningOut = true
                defer { isSigningOut = false }
                try? await sessionStore.signOut()
                dismiss()
            }
        }
    }
}
