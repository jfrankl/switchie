import SwiftUI

struct BehaviorSection: View {
    @EnvironmentObject private var switcher: Switcher
    @State private var separateMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Checkbox-style settings (checkbox on the left; clicking text toggles)
            VStack(alignment: .leading, spacing: 10) {
                NumberBadgesSettingsView_Checkbox()
                AutoSelectSingleResultSettingsView_Checkbox()
                Toggle("Separate key switch", isOn: $separateMode)
                    .toggleStyle(.checkbox)
                    .onChange(of: separateMode) { _, new in
                        switcher.setSeparateKeySwitchEnabled(new)
                    }

            }
            // Keep grid only for key-value style rows
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                if !switcher.separateKeySwitchEnabled {
                    GridRow {
                        Text("Long‑Press Delay:")
                            .gridLabel()
                        LongPressDelaySettingsView()
                    }
                }
            }
        }
        .onAppear {
            separateMode = switcher.separateKeySwitchEnabled
        }
    }
}
