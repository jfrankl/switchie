import SwiftUI

enum PrefsTab: String, CaseIterable, Identifiable {
    case switching, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .switching: return "Switching"
        case .settings:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .switching: return "command"
        case .settings:  return "gearshape"
        }
    }
}

struct PreferencesTabBar: View {
    @Binding var selection: PrefsTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PrefsTab.allCases) { tab in
                TabButton(tab: tab, isSelected: selection == tab) {
                    selection = tab
                }
            }
        }
    }
}

private struct TabButton: View {
    let tab: PrefsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(backgroundColor)
                    )
                    .foregroundStyle(foregroundColor)
                Text(tab.title)
                    .font(Theme.Font.tabLabel)
                    .foregroundStyle(foregroundColor)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var foregroundColor: SwiftUI.Color {
        isSelected ? Theme.Color.accent : Theme.Color.secondaryLabel
    }

    private var backgroundColor: SwiftUI.Color {
        if isSelected { return Theme.Color.accentSubtle }
        if hovered    { return Theme.Color.label.opacity(0.06) }
        return .clear
    }
}
