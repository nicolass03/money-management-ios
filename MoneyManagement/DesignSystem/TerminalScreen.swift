import SwiftUI

struct TerminalScrollView<Content: View>: View {
    var axes: Axis.Set = .vertical
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(axes) {
            content()
        }
        .scrollIndicators(.hidden)
    }
}

struct TerminalScreen<Content: View>: View {
    @Environment(\.appPalette) private var palette
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()

            TerminalScrollView {
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 52)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
            }
        }
        .scanlineOverlay()
    }
}

struct EmptyStateCard: View {
    @Environment(\.appPalette) private var palette
    let message: String
    var footnote: String?

    var body: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .font(AppFont.mono(size: 14))
                    .foregroundStyle(palette.muted)

                if let footnote {
                    Text(footnote)
                        .font(AppFont.mono(size: 12))
                        .foregroundStyle(palette.muted.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
