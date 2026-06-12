import SwiftUI

struct BlinkingCursor: View {
    @Environment(\.appPalette) private var palette
    @State private var visible = true

    var body: some View {
        Text("_")
            .font(AppFont.mono(size: 14))
            .foregroundStyle(palette.accent)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
    }
}
