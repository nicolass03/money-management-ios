import SwiftUI

struct TerminalTabBar: View {
    @Environment(\.appPalette) private var palette
    @Binding var selectedTab: AppTab
    @Namespace private var activeTabNamespace

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .frame(height: 60)
            .sensoryFeedback(.selection, trigger: selectedTab)
        }
        .background(palette.surface)
    }

    private func tabButton(for tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            guard selectedTab != tab else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                if isSelected {
                    palette.glowPulse
                        .matchedGeometryEffect(id: "activeTab", in: activeTabNamespace)
                }

                VStack(spacing: 3) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 18, weight: .regular))
                        .symbolRenderingMode(.monochrome)

                    HStack(spacing: 0) {
                        if isSelected {
                            Text(">")
                                .font(AppFont.mono(size: 9, weight: .medium))
                        }
                        Text(tab.label)
                            .font(AppFont.mono(size: 11, weight: isSelected ? .medium : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .foregroundStyle(isSelected ? palette.accentGlow : palette.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
