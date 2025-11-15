import SwiftUI

/// A horizontal row with a right-aligned label and left-aligned content.
/// Use throughout preferences for consistent alignment.
struct LabeledRow<Content: View>: View {
    let label: String
    let alignment: VerticalAlignment
    let content: () -> Content

    init(_ label: String,
         alignment: VerticalAlignment = .firstTextBaseline,
         @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 12) {
            Text(label)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.label)
                .frame(width: Theme.Metrics.labelColumnWidth, alignment: .trailing)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }

            Spacer(minLength: 0)
        }
    }
}

/// Subtle horizontal divider between sections inside a tab.
struct SectionDivider: View {
    var body: some View {
        Divider()
            .opacity(0.5)
    }
}
