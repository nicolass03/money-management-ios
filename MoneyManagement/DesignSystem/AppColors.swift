import SpendflyShared
import SwiftUI

/// The app consumes a `ThemePalette` (defined in SpendflyShared and shared with the widgets)
/// via the `\.appPalette` environment. The active palette is resolved from the selected theme +
/// resolved color scheme in `AppThemeModifier`.
enum AppColors {
    typealias Palette = ThemePalette
}

struct AppPaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette =
        SpendflyThemes.theme(for: nil).palette(for: .dark)
}

extension EnvironmentValues {
    var appPalette: ThemePalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}
