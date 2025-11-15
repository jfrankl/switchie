import SwiftUI

struct SwitchingTab: View {
    @EnvironmentObject private var switcher: Switcher

    @State private var useSameShortcut = true
    @State private var onlyMarked = false
    @State private var switchMode: AppSwitchMode = .cycle

    @State private var appSwitch       = Preferences.loadShortcut(forKey: Preferences.Key.appSwitch, default: Preferences.Default.appSwitch)
    @State private var separateOverlay = Preferences.Default.unconfigured
    @State private var separateToggle  = Preferences.Default.unconfigured
    @State private var overlayMark     = Preferences.Default.unconfigured
    @State private var windowCycle     = Preferences.Default.unconfigured

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App
            SectionHeading("App")
            TabIntro(text: "Switch between your open applications.")

            VStack(alignment: .leading, spacing: 14) {
                DescribedToggle(
                    title: "Use the same shortcut for opening and toggling",
                    helpText: "A single shortcut handles both — tap to toggle apps, hold past the long-press delay to open the panel. When off, you\u{2019}ll set separate shortcuts for the panel and the toggle.",
                    isOn: $useSameShortcut
                )
                .onChange(of: useSameShortcut) { _, new in
                    switcher.setSeparateKeySwitchEnabled(!new)
                }

                DescribedPicker(
                    title: "Mode",
                    helpText: "Cycle moves through every open app on each tap. Toggle bounces between your two most recently used apps. \u{201C}Only cycle through marked apps\u{201D} overrides this and always cycles.",
                    selection: $switchMode
                ) {
                    ForEach(AppSwitchMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .onChange(of: switchMode) { _, new in
                    switcher.setAppSwitchMode(new)
                }

                DescribedToggle(
                    title: "Only cycle through marked apps",
                    helpText: "Limit cycling to apps you\u{2019}ve marked. Overrides the mode above and always cycles.",
                    isOn: $onlyMarked
                )
                .onChange(of: onlyMarked) { _, new in
                    switcher.setOnlyCycleMarkedApps(new)
                }
            }
            .padding(.bottom, Theme.Metrics.sectionPadding)

            // Shortcuts (mode-dependent)
            VStack(alignment: .leading, spacing: 14) {
                if switcher.separateKeySwitchEnabled {
                    shortcutRow(
                        "Open panel:",
                        helpText: "Bring up the panel of every running app for searching and selecting.",
                        $separateOverlay
                    ) { switcher.applySeparateOverlayShortcut($0) }

                    shortcutRow(
                        "Toggle app:",
                        helpText: "Switch to the next app. Tap repeatedly to cycle through every open app.",
                        $separateToggle
                    ) { switcher.applySeparateToggleShortcut($0) }
                } else {
                    shortcutRow(
                        "Toggle app:",
                        helpText: "Tap to cycle through every open app. Hold past the long-press delay to bring up the panel instead.",
                        $appSwitch
                    ) { switcher.applyAppSwitchShortcut($0) }

                    DescribedRow(
                        "Long-press delay:",
                        helpText: "How long you have to hold the toggle shortcut before the panel appears instead of cycling."
                    ) {
                        LongPressDelaySettingsView()
                    }
                }

                if switcher.onlyCycleMarkedApps {
                    shortcutRow(
                        "Mark / unmark:",
                        helpText: "From inside the panel, add or remove the highlighted app from your marked set.",
                        $overlayMark
                    ) { switcher.applyOverlayMarkShortcut($0) }
                }
            }
            .padding(.bottom, Theme.Metrics.sectionPadding)

            SectionDivider()
                .padding(.bottom, Theme.Metrics.sectionPadding)

            // Window
            SectionHeading("Window")
            TabIntro(text: "Cycle through the open windows of the frontmost application. Useful when you have multiple documents or browser windows open in the same app.")

            shortcutRow(
                "Toggle window:",
                helpText: "Cycle to the next window of the frontmost app.",
                $windowCycle
            ) { switcher.applyWindowCycleShortcut($0) }
        }
        .onAppear { sync() }
    }

    @ViewBuilder
    private func shortcutRow(_ label: String,
                             helpText: String,
                             _ binding: Binding<Shortcut>,
                             apply: @escaping (Shortcut) -> Void) -> some View {
        DescribedRow(label, helpText: helpText, alignment: .center) {
            ShortcutPicker(shortcut: binding)
                .onChange(of: binding.wrappedValue) { _, new in apply(new) }
        }
    }

    private func sync() {
        useSameShortcut = !switcher.separateKeySwitchEnabled
        onlyMarked      = switcher.onlyCycleMarkedApps
        switchMode      = switcher.appSwitchMode
        appSwitch       = Preferences.loadShortcut(forKey: Preferences.Key.appSwitch, default: Preferences.Default.appSwitch)
        separateOverlay = switcher.separateOverlayShortcut
        separateToggle  = switcher.separateToggleShortcut
        overlayMark     = switcher.overlayMarkShortcut
        windowCycle     = switcher.windowCycleShortcut
    }
}
