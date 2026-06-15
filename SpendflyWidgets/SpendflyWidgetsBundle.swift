import SwiftUI
import SpendflyShared
import WidgetKit

@main
struct SpendflyWidgetsBundle: WidgetBundle {
    init() {
        SpendflyFont.registerIfNeeded()
    }

    var body: some Widget {
        MonthSpentWidget()
        ExtraSpentWidget()
    }
}
