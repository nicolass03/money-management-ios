import SwiftUI

struct TerminalCard<Content: View>: View {
    @Environment(\.appPalette) private var palette
    var showsGlow = true
    let content: Content

    init(showsGlow: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsGlow = showsGlow
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(palette.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(palette.border, lineWidth: 1)
            }
            .shadow(color: showsGlow ? palette.glowPulse : .clear, radius: showsGlow ? 8 : 0, x: 0, y: 0)
    }
}
