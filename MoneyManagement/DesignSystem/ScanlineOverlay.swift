import SwiftUI

struct ScanlineOverlay: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y + 2, width: size.width, height: 2)
                context.fill(Path(rect), with: .color(palette.scanline))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func scanlineOverlay() -> some View {
        overlay {
            ScanlineOverlay()
        }
    }
}
