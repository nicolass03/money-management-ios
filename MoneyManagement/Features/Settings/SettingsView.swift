import SwiftUI

struct SettingsView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let sessionStore: SessionStore
    let themeManager: ThemeManager
    let languageManager: LanguageManager
    @Bindable var viewModel: SettingsViewModel
    var onSaved: (() -> Void)? = nil

    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                palette.bg.ignoresSafeArea()

                TerminalScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeader(
                            title: L10n.t("settings"),
                            subtitle: L10n.t("configure app preferences")
                        )

                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error) {
                                Task { await viewModel.load() }
                            }
                        }

                        sessionSection
                        themeSection
                        languageSection
                        currencySection
                        projectionSection
                        extraSpentSection
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
                    Text(L10n.t("settings"))
                        .font(AppFont.mono(size: 14, weight: .medium))
                        .foregroundStyle(palette.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("done")) { dismiss() }
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
                Text(L10n.t("> session"))
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)
                Text(sessionStore.session?.user.email ?? L10n.t("unknown"))
                    .font(AppFont.mono(size: 14))
                    .foregroundStyle(palette.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var themeSection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("> appearance"))
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

    private var languageSection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("> language"))
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)

                Picker("language", selection: $viewModel.language) {
                    Text("English").tag(AppLanguage.en)
                    Text("Español").tag(AppLanguage.es)
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.language) { _, newValue in
                    guard newValue != languageManager.language else { return }
                    languageManager.apply(newValue)
                    Task {
                        _ = await viewModel.updateLanguage(newValue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var currencySection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("> currency"))
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)

                Picker(L10n.t("display currency"), selection: $viewModel.displayCurrency) {
                    ForEach(CurrencyCode.allCases) { currency in
                        Text(currency.label).tag(currency)
                    }
                }
                .pickerStyle(.segmented)

                Text(L10n.t("> primary pay schedule"))
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 8)

                Picker(L10n.t("primary schedule"), selection: $viewModel.primaryScheduleId) {
                    Text(L10n.t("none")).tag(Optional<String>.none)
                    ForEach(viewModel.schedules) { schedule in
                        Text(schedule.name).tag(Optional(schedule.id))
                    }
                }
                .pickerStyle(.menu)
                .font(AppFont.mono(size: 14))

                TerminalButton(
                    title: viewModel.isSaving
                        ? L10n.t("saving...")
                        : L10n.t("save preferences"),
                    isLoading: viewModel.isSaving
                ) {
                    Task {
                        if await viewModel.save() {
                            onSaved?()
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
                Text(L10n.t("> projections"))
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)

                AmountTextField(
                    text: $viewModel.projectionInitialFreeMoneyText,
                    label: L10n.t("initial free money"),
                    placeholder: "0.00",
                    allowsNegative: true
                )

                TerminalTextField(
                    label: L10n.t("projection start date (YYYY-MM-DD)"),
                    placeholder: L10n.t("optional"),
                    text: $viewModel.projectionStartDate,
                    keyboardType: .numbersAndPunctuation
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var extraSpentSection: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("> extra spent limit"))
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)

                AmountTextField(
                    text: $viewModel.extraSpentLimitText,
                    label: L10n.t("limit (empty = none)"),
                    placeholder: L10n.t("no limit")
                )

                Text(L10n.t("> optimal limit for unplanned spending (not recurring, planned, or budgets)"))
                    .font(AppFont.mono(size: 11))
                    .foregroundStyle(palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var logoutSection: some View {
        TerminalButton(
            title: isSigningOut
                ? L10n.t("signing out...")
                : L10n.t("logout"),
            isLoading: isSigningOut
        ) {
            Task {
                isSigningOut = true
                defer { isSigningOut = false }
                viewModel.clearWidgetSnapshot()
                try? await sessionStore.signOut()
                dismiss()
            }
        }
    }
}
