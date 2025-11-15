import SwiftUI

struct PreferencesRootView: View {
    @State private var selectedTab: PrefsTab = .switching

    var body: some View {
        VStack(spacing: 0) {
            // Title row, occupies the same vertical band as the traffic lights.
            // The whole stack ignores the top safe area so this row sits at y=0.
            Text("Switchie")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(Theme.Color.background)

            HStack {
                Spacer()
                PreferencesTabBar(selection: $selectedTab)
                Spacer()
            }
            .padding(.top, 4)
            .padding(.bottom, 10)
            .background(Theme.Color.background)

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case .switching: SwitchingTab()
                    case .settings:  SettingsTab()
                    }
                }
                .padding(.horizontal, Theme.Metrics.contentPadding)
                .padding(.vertical, Theme.Metrics.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .background(Theme.Color.background)
        .ignoresSafeArea(.container, edges: .top)
    }
}

// MARK: - Shared building blocks

/// Microcopy block at the top of a tab or section.
struct TabIntro: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Font.helpText)
            .foregroundStyle(Theme.Color.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 12)
    }
}

/// A heading shown above a logical section within a tab.
struct SectionHeading: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.Color.label)
            .padding(.bottom, 6)
    }
}

/// A segmented picker row with a leading title and helper text underneath.
struct DescribedPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    let helpText: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.label)
                Picker("", selection: $selection) {
                    content()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            Text(helpText)
                .font(Theme.Font.helpText)
                .foregroundStyle(Theme.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A toggle row with descriptive helper text underneath.
struct DescribedToggle: View {
    let title: String
    let helpText: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.checkbox)
                .font(Theme.Font.body)
            Text(helpText)
                .font(Theme.Font.helpText)
                .foregroundStyle(Theme.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 20)
        }
    }
}

/// A LabeledRow with helper text underneath, aligned with the field column.
struct DescribedRow<Content: View>: View {
    let label: String
    let helpText: String
    let alignment: VerticalAlignment
    let content: () -> Content

    init(_ label: String,
         helpText: String,
         alignment: VerticalAlignment = .center,
         @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.helpText = helpText
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledRow(label, alignment: alignment, content: content)

            Text(helpText)
                .font(Theme.Font.helpText)
                .foregroundStyle(Theme.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, Theme.Metrics.labelColumnWidth + 12)
        }
    }
}
