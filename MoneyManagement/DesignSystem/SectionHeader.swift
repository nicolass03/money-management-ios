import SwiftUI

struct SectionHeader: View {
    @Environment(\.appPalette) private var palette
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("> ")
                    .foregroundStyle(palette.accent)
                Text(title)
                    .foregroundStyle(palette.text)
            }
            .font(AppFont.mono(size: 18, weight: .medium))

            if let subtitle {
                Text(subtitle)
                    .font(AppFont.mono(size: 12))
                    .foregroundStyle(palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
