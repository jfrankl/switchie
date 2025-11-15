import SwiftUI

struct SettingsTab: View {
    @EnvironmentObject private var switcher: Switcher

    @State private var showDockIcon = false
    @State private var overlaySelect = Preferences.Default.unconfigured
    @State private var overlayQuit   = Preferences.Default.unconfigured

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DescribedToggle(
                title: "Show number badges in panel",
                helpText: "Display 1\u{2013}9 number labels on app icons in the panel so you can press a digit to jump straight to that app.",
                isOn: Binding(
                    get: { switcher.showNumberBadges },
                    set: { switcher.setShowNumberBadges($0) }
                )
            )

            DescribedToggle(
                title: "Auto-select when only one match remains",
                helpText: "Automatically activate the only matching app when typing in the panel narrows results down to one.",
                isOn: Binding(
                    get: { switcher.autoSelectSingleResult },
                    set: { switcher.setAutoSelectSingleResult($0) }
                )
            )

            DescribedToggle(
                title: "Show app icon in Dock",
                helpText: "Keep Switchie\u{2019}s icon in the Dock alongside your other running apps. When off, Switchie lives only in the menu bar.",
                isOn: $showDockIcon
            )
            .onChange(of: showDockIcon) { _, new in
                if new != DockIconManager.shared.showDockIcon {
                    DockIconManager.shared.toggle()
                }
            }

            SectionDivider()
                .padding(.vertical, 6)

            DescribedRow(
                "Select:",
                helpText: "Activate the highlighted app and dismiss the panel."
            ) {
                ShortcutPicker(shortcut: $overlaySelect)
                    .onChange(of: overlaySelect) { _, new in switcher.applyOverlaySelectShortcut(new) }
            }

            DescribedRow(
                "Quit:",
                helpText: "Quit the highlighted app without leaving the panel."
            ) {
                ShortcutPicker(shortcut: $overlayQuit)
                    .onChange(of: overlayQuit) { _, new in switcher.applyOverlayQuitShortcut(new) }
            }
        }
        .onAppear {
            showDockIcon  = DockIconManager.shared.showDockIcon
            overlaySelect = switcher.overlaySelectShortcut
            overlayQuit   = switcher.overlayQuitShortcut
        }
    }
}
