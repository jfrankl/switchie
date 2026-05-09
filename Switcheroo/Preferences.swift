import Foundation
import AppKit

enum Preferences {

    // MARK: - UserDefaults Keys

    enum Key {
        static let longPressDelay    = "LongPressDelay"
        static let numberBadges      = "ShowNumberBadges"
        static let autoSelect        = "AutoSelectSingleResult"
        static let separateMode      = "SeparateKeySwitchEnabled"
        static let cycleAllApps      = "CycleThroughAllApps"
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

    enum Default {
        static let longPressDelay: TimeInterval = 1.0
        static let longPressRange: ClosedRange<TimeInterval> = 0.05...5.0

        static let appSwitch     = Shortcut(keyCode: 111, modifiers: [])           // F12
        static let overlaySelect = Shortcut(keyCode: 36, modifiers: [])            // Return
        static let overlayQuit   = Shortcut(keyCode: 12, modifiers: [.command])    // ⌘Q
        static let overlayMark   = Shortcut(keyCode: 46, modifiers: [])            // M
        static let unconfigured  = Shortcut(keyCode: 0, modifiers: [])
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
