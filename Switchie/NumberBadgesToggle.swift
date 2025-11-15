import SwiftUI

struct NumberBadgesSettingsView_Checkbox: View {
    @EnvironmentObject private var switcher: Switcher

    var body: some View {
        Toggle("Show number badges in panel", isOn: Binding(
            get: { switcher.showNumberBadges },
            set: { switcher.setShowNumberBadges($0) }
        ))
        .toggleStyle(.checkbox)
    }
}
