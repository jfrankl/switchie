import AppKit
import SwiftUI

@MainActor
protocol OverlayDelegate: AnyObject {
    var showNumberBadges: Bool { get }
    var autoSelectSingleResult: Bool { get }
    var overlaySelectShortcut: Shortcut { get }
    var overlayQuitShortcut: Shortcut { get }
    var overlayMarkShortcut: Shortcut { get }

    func activateApp(_ app: NSRunningApplication)
    func mruList() -> [NSRunningApplication]
    func removeFromMRU(_ app: NSRunningApplication)
    func markedBundleIDs() -> Set<String>
    func setMarkedBundleIDs(_ ids: Set<String>)
}

@MainActor
final class OverlayCoordinator {

    weak var delegate: OverlayDelegate?

    private let windowController = OverlayWindowController()
    private var searchText = ""
    private var filtered: [NSRunningApplication] = []
    private var selectedIndex: Int?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var activationObserver: Any?
    private var originApp: NSRunningApplication?

    // MARK: - Visibility

    var isVisible: Bool {
        localMonitor != nil || globalMonitor != nil
    }

    // MARK: - Show / Hide

    func enter() {
        guard let delegate else { return }
        let mru = delegate.mruList()
        guard !mru.isEmpty else {
            dismiss(reactivateOrigin: false)
            return
        }

        pruneMarkedApps()

        searchText = ""
        filtered = mru
        selectedIndex = filtered.isEmpty ? nil : 0
        originApp = NSWorkspace.shared.frontmostApplication

        windowController.show(
            candidates: filtered,
            selectedIndex: selectedIndex,
            searchText: searchText,
            showNumberBadges: delegate.showNumberBadges,
            markedBundleIDs: delegate.markedBundleIDs(),
            onSelect: { [weak self] app in
                self?.delegate?.activateApp(app)
                self?.dismiss(reactivateOrigin: false)
            },
            onClose: { [weak self] in
                self?.dismiss(reactivateOrigin: true)
            },
            onUnmarkAll: { [weak self] in
                guard let self else { return }
                self.delegate?.setMarkedBundleIDs([])
                self.updateOverlay()
            },
            onQuitAll: { [weak self] in
                self?.confirmAndQuitAllApps()
            },
            onMark: { [weak self] app in
                self?.toggleMark(for: app)
            }
        )

        installEventMonitors()
        installActivationObserver()
    }

    func dismiss(reactivateOrigin: Bool) {
        windowController.hide(animated: true)
        removeEventMonitors()
        removeActivationObserver()
        if reactivateOrigin, let origin = originApp {
            _ = origin.activate(options: [])
        }
        originApp = nil
    }

    // MARK: - Bulk Actions

    private func confirmAndQuitAllApps() {
        let alert = NSAlert()
        alert.messageText = "Quit all running apps?"
        alert.informativeText = "Every other running application will be asked to quit. Switchie will keep running."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit All")
        alert.addButton(withTitle: "Cancel")

        // Drop the overlay below the alert's level for the duration of the
        // modal so the alert appears in front of (not behind) the panel.
        windowController.setLevel(.floating)
        let response = alert.runModal()
        windowController.setLevel(.screenSaver)

        guard response == .alertFirstButtonReturn else { return }

        let myPID = ProcessInfo.processInfo.processIdentifier
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.processIdentifier != myPID else { continue }
            _ = app.terminate()
        }

        dismiss(reactivateOrigin: false)
    }

    // MARK: - Selection Movement

    func moveSelection(delta: Int) {
        guard !filtered.isEmpty else { return }
        let count = filtered.count
        let current = selectedIndex ?? 0
        selectedIndex = (current + (delta % count) + count) % count
        updateOverlay()
    }

    // MARK: - Keyboard Handling

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let delegate else { return false }

        let pressed = shortcutFromEvent(event)

        if pressed == delegate.overlaySelectShortcut {
            if let idx = selectedIndex, filtered.indices.contains(idx) {
                delegate.activateApp(filtered[idx])
                dismiss(reactivateOrigin: false)
            }
            return true
        }

        if pressed == delegate.overlayQuitShortcut {
            quitSelectedApp()
            return true
        }

        if pressed == delegate.overlayMarkShortcut {
            toggleMarkForSelectedApp()
            return true
        }

        if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
            let scalar = chars.unicodeScalars.first!
            switch scalar.value {
            case 0x1B: // ESC
                if searchText.isEmpty {
                    dismiss(reactivateOrigin: true)
                } else {
                    searchText = ""
                    recomputeFilter()
                }
                return true
            case 0x7F: // DELETE
                if !searchText.isEmpty {
                    searchText.removeLast()
                    recomputeFilter()
                }
                return true
            default:
                break
            }
        }

        if let special = event.specialKey {
            switch special {
            case .leftArrow:  moveSelection(delta: -1); return true
            case .rightArrow: moveSelection(delta:  1); return true
            case .tab:
                moveSelection(delta: event.modifierFlags.contains(.shift) ? -1 : 1)
                return true
            default: break
            }
        }

        if let chars = event.characters, !chars.isEmpty {
            let scalars = chars.unicodeScalars
            if scalars.count == 1, let digit = scalars.first, ("0"..."9").contains(Character(digit)) {
                if selectByDigit(Character(digit)) { return true }
            }

            let printable = scalars.filter { scalar in
                switch scalar.properties.generalCategory {
                case .control, .format, .surrogate, .privateUse, .unassigned: return false
                default: return true
                }
            }
            if !printable.isEmpty {
                searchText.append(String(String.UnicodeScalarView(printable)))
                recomputeFilter()
                return true
            }
        }

        return false
    }

    // MARK: - Private Helpers

    private func quitSelectedApp() {
        guard let delegate,
              let idx = selectedIndex,
              filtered.indices.contains(idx) else { return }

        let app = filtered[idx]
        let name = app.localizedName ?? app.bundleIdentifier ?? "App"
        _ = app.terminate()

        delegate.removeFromMRU(app)
        filtered.removeAll { $0.processIdentifier == app.processIdentifier }

        if filtered.isEmpty {
            selectedIndex = nil
        } else if let idx = selectedIndex {
            selectedIndex = min(idx, filtered.count - 1)
        }

        pruneMarkedApps()

        windowController.showToast("Quit \(name)")
        updateOverlay()
    }

    private func pruneMarkedApps() {
        guard let delegate else { return }
        let marks = delegate.markedBundleIDs()
        guard !marks.isEmpty else { return }

        let runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && !$0.isTerminated }
                .compactMap(\.bundleIdentifier)
        )
        let activeMarks = marks.intersection(runningBundleIDs)
        if activeMarks.count <= 1 {
            delegate.setMarkedBundleIDs([])
        }
    }

    private func toggleMarkForSelectedApp() {
        guard let idx = selectedIndex,
              filtered.indices.contains(idx) else { return }
        toggleMark(for: filtered[idx])
    }

    private func toggleMark(for app: NSRunningApplication) {
        guard let delegate,
              let bundleID = app.bundleIdentifier else { return }

        var marks = delegate.markedBundleIDs()
        if marks.contains(bundleID) {
            marks.remove(bundleID)
        } else {
            marks.insert(bundleID)
        }
        delegate.setMarkedBundleIDs(marks)
        updateOverlay()
    }

    private func selectByDigit(_ ch: Character) -> Bool {
        guard !filtered.isEmpty, let delegate else { return false }
        let index: Int
        switch ch {
        case "1"..."9": index = Int(String(ch))! - 1
        case "0":       index = 9
        default:        return false
        }
        guard filtered.indices.contains(index) else { return false }
        delegate.activateApp(filtered[index])
        dismiss(reactivateOrigin: false)
        return true
    }

    private func recomputeFilter() {
        guard let delegate else { return }
        let mru = delegate.mruList()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            filtered = mru
        } else {
            let needle = trimmed.lowercased()
            filtered = mru.filter { app in
                let name = (app.localizedName ?? app.bundleIdentifier ?? "").lowercased()
                return Self.matchesWordPrefix(name: name, query: needle)
            }
        }

        selectedIndex = filtered.isEmpty ? nil : min(selectedIndex ?? 0, filtered.count - 1)
        updateOverlay()

        if delegate.autoSelectSingleResult, filtered.count == 1, let only = filtered.first {
            delegate.activateApp(only)
            dismiss(reactivateOrigin: false)
        }
    }

    private func updateOverlay() {
        guard let delegate else { return }
        windowController.update(
            candidates: filtered,
            selectedIndex: selectedIndex,
            searchText: searchText,
            showNumberBadges: delegate.showNumberBadges,
            markedBundleIDs: delegate.markedBundleIDs()
        )
    }

    private func shortcutFromEvent(_ event: NSEvent) -> Shortcut {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift, .capsLock, .function])
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods)
    }

    static func matchesWordPrefix(name: String, query: String) -> Bool {
        let nameWords = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let queryTokens = query.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        guard !queryTokens.isEmpty else { return true }
        for token in queryTokens {
            if !nameWords.contains(where: { $0.hasPrefix(token) }) { return false }
        }
        return true
    }

    // MARK: - Event Monitors

    private func installEventMonitors() {
        removeEventMonitors()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, self.handleKeyDown(event) { return nil }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return }
            _ = self.handleKeyDown(event)
        }

}

    private func removeEventMonitors() {
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }

    private func installActivationObserver() {
        removeActivationObserver()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, self.isVisible else { return }
            guard let activated = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if activated.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self.dismiss(reactivateOrigin: false)
            }
        }
    }

    private func removeActivationObserver() {
        if let obs = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            activationObserver = nil
        }
    }
}
