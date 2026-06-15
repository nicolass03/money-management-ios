import SwiftUI

struct FloatingSettingsButton: View {
    @Environment(\.appPalette) private var palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(palette.muted)
                .frame(width: 44, height: 44)
                .background(palette.surfaceElevated.opacity(0.95))
                .overlay {
                    Rectangle()
                        .stroke(palette.border, lineWidth: 1)
                }
                .shadow(color: palette.glow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("Settings"))
    }
}
