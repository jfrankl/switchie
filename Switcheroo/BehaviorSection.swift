import SwiftUI

struct GeneralTab: View {
    @EnvironmentObject private var switcher: Switcher
    @State private var separateMode = false
    @State private var cycleAll = true
    @State private var showDockIcon = false

    @State private var appSwitch = Preferences.loadShortcut(forKey: Preferences.Key.appSwitch, default: Preferences.Default.appSwitch)
    @State private var windowCycle = Preferences.Default.unconfigured
    @State private var overlaySelect = Preferences.Default.unconfigured
    @State private var overlayQuit = Preferences.Default.unconfigured
    @State private var overlayMark = Preferences.Default.unconfigured
    @State private var separateToggle = Preferences.Default.unconfigured
    @State private var separateOverlay = Preferences.Default.unconfigured

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            behaviorToggles
                .padding(.bottom, Theme.Metrics.sectionPadding)

            if !switcher.separateKeySwitchEnabled {
                SectionDivider()

                LabeledRow("Long-press delay:") {
                    LongPressDelaySettingsView()
                }
                .padding(.vertical, Theme.Metrics.sectionPadding)
            }

            SectionDivider()

            activationShortcuts
                .padding(.vertical, Theme.Metrics.sectionPadding)

            SectionDivider()

            panelActionShortcuts
                .padding(.top, Theme.Metrics.sectionPadding)
        }
        .onAppear {
            separateMode = switcher.separateKeySwitchEnabled
            cycleAll = switcher.cycleThroughAllApps
            showDockIcon = DockIconManager.shared.showDockIcon
            syncShortcutsFromSwitcher()
        }
    }

    // MARK: - Sub-sections

    private var behaviorToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show number badges in panel", isOn: Binding(
                get: { switcher.showNumberBadges },
                set: { switcher.setShowNumberBadges($0) }
            ))
            .toggleStyle(.checkbox)

            Toggle("Auto-select when only one match remains", isOn: Binding(
                get: { switcher.autoSelectSingleResult },
                set: { switcher.setAutoSelectSingleResult($0) }
            ))
            .toggleStyle(.checkbox)

            Toggle("Cycle through all apps when toggling", isOn: $cycleAll)
                .toggleStyle(.checkbox)
                .onChange(of: cycleAll) { _, new in
                    switcher.setCycleThroughAllApps(new)
                }

            Toggle("Use separate keys for toggle and overlay", isOn: $separateMode)
                .toggleStyle(.checkbox)
                .onChange(of: separateMode) { _, new in
                    switcher.setSeparateKeySwitchEnabled(new)
                }

            Toggle("Show app icon in Dock", isOn: $showDockIcon)
                .toggleStyle(.checkbox)
                .onChange(of: showDockIcon) { _, new in
                    if new != DockIconManager.shared.showDockIcon {
                        DockIconManager.shared.toggle()
                    }
                }
        }
        .font(Theme.Font.body)
    }

    private var activationShortcuts: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.rowSpacing) {
            if switcher.separateKeySwitchEnabled {
                shortcutRow("Open panel:", $separateOverlay) { switcher.applySeparateOverlayShortcut($0) }
                shortcutRow("Toggle app:", $separateToggle) { switcher.applySeparateToggleShortcut($0) }
            } else {
                shortcutRow("App Switcher:", $appSwitch) { switcher.applyAppSwitchShortcut($0) }
            }
            shortcutRow("Toggle window:", $windowCycle) { switcher.applyWindowCycleShortcut($0) }
        }
    }

    private var panelActionShortcuts: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.rowSpacing) {
            shortcutRow("Select highlighted:", $overlaySelect) { switcher.applyOverlaySelectShortcut($0) }
            shortcutRow("Quit selected:", $overlayQuit) { switcher.applyOverlayQuitShortcut($0) }
            shortcutRow("Mark / unmark:", $overlayMark) { switcher.applyOverlayMarkShortcut($0) }
        }
    }

    @ViewBuilder
    private func shortcutRow(_ label: String, _ binding: Binding<Shortcut>, apply: @escaping (Shortcut) -> Void) -> some View {
        LabeledRow(label, alignment: .center) {
            ShortcutPicker(shortcut: binding)
                .onChange(of: binding.wrappedValue) { _, new in apply(new) }
        }
    }

    private func syncShortcutsFromSwitcher() {
        appSwitch = Preferences.loadShortcut(forKey: Preferences.Key.appSwitch, default: Preferences.Default.appSwitch)
        windowCycle = switcher.windowCycleShortcut
        overlaySelect = switcher.overlaySelectShortcut
        overlayQuit = switcher.overlayQuitShortcut
        overlayMark = switcher.overlayMarkShortcut
        separateToggle = switcher.separateToggleShortcut
        separateOverlay = switcher.separateOverlayShortcut
    }
}
