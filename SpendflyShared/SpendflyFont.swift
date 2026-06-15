import CoreText
import Foundation
import SwiftUI

public enum SpendflyFont {
    public static let monoRegular = "JetBrainsMono-Regular"
    public static let monoMedium = "JetBrainsMono-Medium"

    private static var didRegister = false

    /// Loads JetBrains Mono from the SpendflyShared framework bundle (used by widgets).
    public static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        // Widget extension: fonts may live in the appex bundle (UIAppFonts) or SpendflyShared.framework.
        let bundles = [Bundle(for: BundleMarker.self), Bundle.main]
        for bundle in bundles {
            for name in [monoRegular, monoMedium] {
                guard let url = bundle.url(forResource: name, withExtension: "ttf") else { continue }
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    public static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registerIfNeeded()
        switch weight {
        case .medium, .semibold, .bold:
            return .custom(monoMedium, size: size)
        default:
            return .custom(monoRegular, size: size)
        }
    }

    private final class BundleMarker: NSObject {}
}
