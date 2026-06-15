import SwiftUI

// MARK: - Terminal spinner (matches web TerminalSpinner)

struct TerminalSpinner: View {
    @Environment(\.appPalette) private var palette
    @State private var isAnimating = false

    var size: CGFloat = 12

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(palette.accent.opacity(0.5), lineWidth: 1)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(palette.accentGlow)
                    .frame(height: 1)
                Spacer(minLength: 0)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(isAnimating ? 360 : 0))
        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
        .onAppear { isAnimating = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Loading indicator

enum LoadingIndicatorVariant {
    case inline
    case page
}

struct LoadingIndicator: View {
    @Environment(\.appPalette) private var palette

    var label: String = L10n.t("loading")
    var variant: LoadingIndicatorVariant = .page

    var body: some View {
        switch variant {
        case .inline:
            inlineBody
        case .page:
            pageBody
        }
    }

    private var inlineBody: some View {
        HStack(spacing: 8) {
            TerminalSpinner()
            Text(label)
                .font(AppFont.mono(size: 14))
                .foregroundStyle(palette.text)
            BlinkingCursor()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var pageBody: some View {
        VStack(spacing: 24) {
            HStack(spacing: 0) {
                Text("> ")
                    .font(AppFont.mono(size: 14))
                    .foregroundStyle(palette.accent)
                Text(label)
                    .font(AppFont.mono(size: 14))
                    .foregroundStyle(palette.muted)
                BlinkingCursor()
            }

            VStack(alignment: .leading, spacing: 8) {
                TerminalLoadingBar()
                    .frame(height: 4)

                Text(L10n.t("// please wait..."))
                    .font(AppFont.mono(size: 10))
                    .foregroundStyle(palette.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
            .frame(width: 224)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Shimmer progress bar (matches web motion bar)

private struct TerminalLoadingBar: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let duration = 1.4
            let progress = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: duration) / duration

            GeometryReader { geo in
                let shimmerWidth = geo.size.width / 3
                let offsetX = (geo.size.width * 1.33 * progress) - shimmerWidth

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(palette.border.opacity(0.5))

                    LinearGradient(
                        colors: [
                            palette.accent.opacity(0),
                            palette.accent.opacity(0.8),
                            palette.accent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerWidth)
                    .offset(x: offsetX)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
        }
        .clipShape(Rectangle())
    }
}

// MARK: - Full-screen / overlay loader

struct LoadingOverlay: View {
    @Environment(\.appPalette) private var palette

    var label: String = L10n.t("fetching data")

    var body: some View {
        ZStack {
            palette.bg.opacity(0.6)
                .ignoresSafeArea()

            LoadingIndicator(label: label, variant: .page)
        }
    }
}

// MARK: - Card overlay (login form)

struct LoadingCardOverlay: View {
    @Environment(\.appPalette) private var palette

    var label: String = L10n.t("authenticating")

    var body: some View {
        palette.surface.opacity(0.9)
            .overlay {
                Rectangle()
                    .stroke(palette.accent.opacity(0.2), lineWidth: 1)
            }
            .overlay {
                LoadingIndicator(label: label, variant: .inline)
            }
    }
}

struct SectionLoadingMask: View {
    @Environment(\.appPalette) private var palette

    var label: String = L10n.t("loading")
    var minHeight: CGFloat = 120

    var body: some View {
        ZStack {
            palette.surface.opacity(0.85)
            LoadingIndicator(label: label, variant: .inline)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
        .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}
