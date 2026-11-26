import SwiftUI

/// The kit's Tab Bar: a Liquid Glass capsule with the tabs, and the Compose
/// button beside it in the brand gradient.
struct TabBar: View {
    @Binding var selection: AppTab
    let compose: () -> Void
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 0) {
                    ForEach(AppTab.allCases) { tab in
                        item(tab)
                    }
                }
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer(minLength: 16)

                Button(action: compose) {
                    Icon(.compose, size: 24)
                        .foregroundStyle(Color.onAccent)
                        .frame(width: 62, height: 62)
                        .background(.brand, in: .circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: .circle)
                .accessibilityLabel(Text("Compose"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = tab == selection
        return Button {
            withAnimation(.smooth(duration: 0.3)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Icon(tab.icon, size: 22)
                Text(tab.title)
                    .nimbraText(.tab)
            }
            // Apple's Liquid Glass bars: the selected tab takes the tint,
            // the others the primary label color, so they read on any backdrop.
            .foregroundStyle(isSelected ? Color.accentColor : Color.textPrimary)
            .frame(width: 88, height: 54)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.surfaceSelected)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
