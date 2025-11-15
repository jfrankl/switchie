import Foundation
import AppKit

enum Preferences {

    // MARK: - UserDefaults Keys

    enum Key {
        static let longPressDelay    = "LongPressDelay"
        static let numberBadges      = "ShowNumberBadges"
        static let autoSelect        = "AutoSelectSingleResult"
        static let separateMode      = "SeparateKeySwitchEnabled"
        static let onlyMarkedApps    = "OnlyCycleMarkedApps"
        static let appSwitchMode     = "AppSwitchMode"
        static let dockIcon          = "ShowDockIcon"
        static let markedApps        = "MarkedAppBundleIDs"
        static let appSwitch         = "UserShortcut"
        static let windowCycle       = "WindowCycleShortcut"
        static let overlaySelect     = "OverlaySelectShortcut"
        static let overlayQuit       = "OverlayQuitShortcut"
        static let overlayMark       = "OverlayMarkShortcut"
        static let separateToggle    = "SeparateToggleShortcut"
        static let separateOverlay   = "SeparateOverlayShortcut"
    }

    // MARK: - Default Values
    //
    // Single source of truth for every default shortcut and timing value.
    // Update values here to change the app-wide defaults.

    enum Default {

        // Timing
        static let longPressDelay: TimeInterval = 1.0
        static let longPressRange: ClosedRange<TimeInterval> = 0.05...5.0

        // Activation shortcuts
        static let appSwitch       = Shortcut(keyCode: 98,  modifiers: []) // F7  combined mode: tap = toggle, hold = panel
        static let separateOverlay = Shortcut(keyCode: 97,  modifiers: []) // F6  separate mode: open panel
        static let separateToggle  = Shortcut(keyCode: 98,  modifiers: []) // F7  separate mode: toggle app
        static let windowCycle     = Shortcut(keyCode: 100, modifiers: []) // F8  cycle windows

        // Panel-action shortcuts
        static let overlaySelect   = Shortcut(keyCode: 36,  modifiers: []) // Return
        static let overlayQuit     = Shortcut(keyCode: 12,  modifiers: []) // Q
        static let overlayMark     = Shortcut(keyCode: 46,  modifiers: []) // M

        // Sentinel for "no shortcut bound"
        static let unconfigured    = Shortcut(keyCode: 0,   modifiers: [])
    }

    // MARK: - Shortcut Persistence

    static func loadShortcut(forKey key: String, default fallback: Shortcut) -> Shortcut {
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else {
            return fallback
        }
        return shortcut
    }

    static func saveShortcut(_ shortcut: Shortcut, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Long Press Delay

    static func loadLongPressDelay() -> TimeInterval {
        let value = UserDefaults.standard.double(forKey: Key.longPressDelay)
        guard value > 0 else { return Default.longPressDelay }
        return value.clamped(to: Default.longPressRange)
    }

    static func saveLongPressDelay(_ value: TimeInterval) {
        let clamped = value.clamped(to: Default.longPressRange)
        UserDefaults.standard.set(clamped, forKey: Key.longPressDelay)
    }

    // MARK: - Marked Apps

    static var markedBundleIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Key.markedApps) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Key.markedApps) }
    }

    // MARK: - Utilities

    static func isConfigured(_ shortcut: Shortcut) -> Bool {
        shortcut.keyCode != 0
    }
}

private extension TimeInterval {
    func clamped(to range: ClosedRange<TimeInterval>) -> TimeInterval {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
