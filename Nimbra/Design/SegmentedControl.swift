import SwiftUI

/// The kit's Segmented: a three-way choice (Theme, the signature's Text, HTML and
/// Preview). It is the system's segmented picker, which iOS 26 draws in Liquid Glass (a
/// capsule track with a capsule thumb), so it follows the system's look, Dynamic Type and
/// accessibility on its own.
struct SegmentedControl<Value: Hashable & Identifiable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> Text

    var body: some View {
        Picker(selection: $selection) {
            ForEach(options) { option in
                label(option).tag(option)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
