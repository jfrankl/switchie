import SwiftUI
import AppKit
import Combine

final class Switcher: ObservableObject, OverlayDelegate {

    // MARK: - Published Settings

    @Published var backgroundColor = Color(NSColor.windowBackgroundColor)
    @Published private(set) var longPressThreshold: TimeInterval
    @Published private(set) var showNumberBadges: Bool
    @Published private(set) var autoSelectSingleResult: Bool
    @Published private(set) var separateKeySwitchEnabled: Bool
    @Published private(set) var cycleThroughAllApps: Bool
    @Published private(set) var hotkeysSuspended = false

    // MARK: - Published Shortcuts

    @Published private(set) var windowCycleShortcut: Shortcut
    @Published private(set) var overlaySelectShortcut: Shortcut
    @Published private(set) var overlayQuitShortcut: Shortcut
    @Published private(set) var overlayMarkShortcut: Shortcut
    @Published private(set) var separateToggleShortcut: Shortcut
    @Published private(set) var separateOverlayShortcut: Shortcut

    // MARK: - Components

    private let overlay = OverlayCoordinator()
    private let windowCycler = WindowCycler()

    // MARK: - MRU State

    private var mru: [NSRunningApplication] = []
    private var cycleIndex = 0
    private var isCycling = false
    private var cycleSnapshot: [NSRunningApplication]?

    // MARK: - Press Detection

    private var appSwitchShortcut: Shortcut = .default
    private var pressStart: Date?
    private var longPressTimer: DispatchSourceTimer?
    private var actionConsumedForThisPress = false

    // MARK: - Observers

    private var activationObserver: Any?

    // MARK: - Hotkey IDs

    private enum HotKeyID: UInt32 {
        case appSwitch = 1, windowCycle = 2, separateToggle = 3, separateOverlay = 4
    }

    // MARK: - Init

    init() {
        longPressThreshold = Preferences.loadLongPressDelay()
        showNumberBadges = UserDefaults.standard.object(forKey: Preferences.Key.numberBadges) as? Bool ?? true
        autoSelectSingleResult = UserDefaults.standard.object(forKey: Preferences.Key.autoSelect) as? Bool ?? true
        separateKeySwitchEnabled = UserDefaults.standard.object(forKey: Preferences.Key.separateMode) as? Bool ?? false
        cycleThroughAllApps = UserDefaults.standard.object(forKey: Preferences.Key.cycleAllApps) as? Bool ?? true

        windowCycleShortcut     = Preferences.loadShortcut(forKey: Preferences.Key.windowCycle, default: Preferences.Default.unconfigured)
        overlaySelectShortcut   = Preferences.loadShortcut(forKey: Preferences.Key.overlaySelect, default: Preferences.Default.unconfigured)
        overlayQuitShortcut     = Preferences.loadShortcut(forKey: Preferences.Key.overlayQuit, default: Preferences.Default.unconfigured)
        overlayMarkShortcut     = Preferences.loadShortcut(forKey: Preferences.Key.overlayMark, default: Preferences.Default.overlayMark)
        separateToggleShortcut  = Preferences.loadShortcut(forKey: Preferences.Key.separateToggle, default: Preferences.Default.unconfigured)
        separateOverlayShortcut = Preferences.loadShortcut(forKey: Preferences.Key.separateOverlay, default: Preferences.Default.unconfigured)

        HotKeyManager.shared.shouldDeliverCallback = { [weak self] in
            self?.hotkeysSuspended != true
        }

        overlay.delegate = self
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    func start() {
        appSwitchShortcut = Preferences.loadShortcut(forKey: Preferences.Key.appSwitch, default: Preferences.Default.appSwitch)
        registerHotkeys()
        seedMRU()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.recordActivation(app)
            self.windowCycler.resetStacks(exceptPID: app.processIdentifier)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(beginShortcutRecording), name: .switcherooBeginRecording, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(endShortcutRecording), name: .switcherooEndRecording, object: nil)
    }

    // MARK: - Recording Suspension

    @objc private func beginShortcutRecording() {
        hotkeysSuspended = true
        HotKeyManager.shared.unregisterAll()
    }

    @objc private func endShortcutRecording() {
        hotkeysSuspended = false
        registerHotkeys()
    }

    // MARK: - Settings API (called by views)

    func setSeparateKeySwitchEnabled(_ enabled: Bool) {
        guard enabled != separateKeySwitchEnabled else { return }
        separateKeySwitchEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Preferences.Key.separateMode)
        registerHotkeys()
    }

    func applyLongPressDelay(_ value: TimeInterval) {
        let clamped = max(0.05, min(5.0, value))
        guard clamped != longPressThreshold else { return }
        longPressThreshold = clamped
        Preferences.saveLongPressDelay(clamped)
        if pressStart != nil && !separateKeySwitchEnabled { rescheduleLongPressTimer() }
    }

    func setShowNumberBadges(_ show: Bool) {
        guard show != showNumberBadges else { return }
        showNumberBadges = show
        UserDefaults.standard.set(show, forKey: Preferences.Key.numberBadges)
    }

    func setAutoSelectSingleResult(_ enabled: Bool) {
        guard enabled != autoSelectSingleResult else { return }
        autoSelectSingleResult = enabled
        UserDefaults.standard.set(enabled, forKey: Preferences.Key.autoSelect)
    }

    func setCycleThroughAllApps(_ enabled: Bool) {
        guard enabled != cycleThroughAllApps else { return }
        cycleThroughAllApps = enabled
        UserDefaults.standard.set(enabled, forKey: Preferences.Key.cycleAllApps)
        cycleSnapshot = nil
        cycleIndex = 0
    }

    func applyAppSwitchShortcut(_ shortcut: Shortcut) {
        appSwitchShortcut = shortcut
        Preferences.saveShortcut(shortcut, forKey: Preferences.Key.appSwitch)
        if !separateKeySwitchEnabled { registerHotkeys() }
    }

    func applyWindowCycleShortcut(_ shortcut: Shortcut) {
        windowCycleShortcut = shortcut
        Preferences.saveShortcut(shortcut, forKey: Preferences.Key.windowCycle)
        registerHotkeys()
    }

    func applyOverlaySelectShortcut(_ s: Shortcut) {
        overlaySelectShortcut = s
        Preferences.saveShortcut(s, forKey: Preferences.Key.overlaySelect)
    }

    func applyOverlayQuitShortcut(_ s: Shortcut) {
        overlayQuitShortcut = s
        Preferences.saveShortcut(s, forKey: Preferences.Key.overlayQuit)
    }

    func applyOverlayMarkShortcut(_ s: Shortcut) {
        overlayMarkShortcut = s
        Preferences.saveShortcut(s, forKey: Preferences.Key.overlayMark)
    }

    func applySeparateToggleShortcut(_ s: Shortcut) {
        separateToggleShortcut = s
        Preferences.saveShortcut(s, forKey: Preferences.Key.separateToggle)
        if separateKeySwitchEnabled { registerHotkeys() }
    }

    func applySeparateOverlayShortcut(_ s: Shortcut) {
        separateOverlayShortcut = s
        Preferences.saveShortcut(s, forKey: Preferences.Key.separateOverlay)
        if separateKeySwitchEnabled { registerHotkeys() }
    }

    // MARK: - OverlayDelegate

    func activateApp(_ app: NSRunningApplication) {
        let name = app.localizedName ?? app.bundleIdentifier ?? "App"

        if app.activate(options: [.activateAllWindows]) { return }
        if app.activate() { return }

        if let url = app.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] result, _ in
                if result == nil { self?.axFallbackActivate(app) }
            }
            return
        }

        axFallbackActivate(app)
    }

    func mruList() -> [NSRunningApplication] {
        pruneMRU()
        return mru
    }

    func removeFromMRU(_ app: NSRunningApplication) {
        mru.removeAll { $0.processIdentifier == app.processIdentifier }
    }

    func markedBundleIDs() -> Set<String> {
        Preferences.markedBundleIDs
    }

    func setMarkedBundleIDs(_ ids: Set<String>) {
        Preferences.markedBundleIDs = ids
    }

    // MARK: - Hotkey Registration

    private func registerHotkeys() {
        HotKeyManager.shared.unregisterAll()

        if separateKeySwitchEnabled {
            registerIfConfigured(separateToggleShortcut, id: .separateToggle) { [weak self] event in
                if case .pressed = event { self?.cycleToNextApp() }
            }
            registerIfConfigured(separateOverlayShortcut, id: .separateOverlay) { [weak self] event in
                if case .pressed = event {
                    if self?.overlay.isVisible == true {
                        self?.overlay.moveSelection(delta: 1)
                    } else {
                        self?.overlay.enter()
                    }
                }
            }
        } else {
            registerIfConfigured(appSwitchShortcut, id: .appSwitch) { [weak self] event in
                switch event {
                case .pressed:  self?.onHotkeyPressed()
                case .released: self?.onHotkeyReleased()
                }
            }
        }

        registerIfConfigured(windowCycleShortcut, id: .windowCycle) { [weak self] event in
            if case .pressed = event {
                guard let app = NSWorkspace.shared.frontmostApplication else { return }
                self?.windowCycler.cycleWindow(in: app)
            }
        }
    }

    private func registerIfConfigured(_ shortcut: Shortcut, id: HotKeyID, handler: @escaping (HotKeyEvent) -> Void) {
        guard Preferences.isConfigured(shortcut) else { return }
        HotKeyManager.shared.register(id: id.rawValue, shortcut: shortcut, callback: handler)
    }

    // MARK: - Combined Mode (Press / Hold)

    private func onHotkeyPressed() {
        if overlay.isVisible {
            actionConsumedForThisPress = false
            pressStart = Date()
            cancelLongPressTimer()
            scheduleLongPressTimer { [weak self] in
                self?.overlay.dismiss(reactivateOrigin: true)
            }
            return
        }

        actionConsumedForThisPress = false
        pressStart = Date()
        cancelLongPressTimer()
        scheduleLongPressTimer { [weak self] in
            self?.overlay.enter()
        }
    }

    private func onHotkeyReleased() {
        let elapsed = pressStart.map { Date().timeIntervalSince($0) } ?? 0
        cancelLongPressTimer()
        pressStart = nil

        if actionConsumedForThisPress {
            actionConsumedForThisPress = false
            return
        }

        if overlay.isVisible, elapsed < longPressThreshold {
            overlay.moveSelection(delta: 1)
            actionConsumedForThisPress = true
            return
        }

        if elapsed < longPressThreshold {
            cycleToNextApp()
            actionConsumedForThisPress = true
        }
        actionConsumedForThisPress = false
    }

    // MARK: - Long Press Timer

    private func scheduleLongPressTimer(action: @escaping () -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + longPressThreshold)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.cancelLongPressTimer()
            if !self.actionConsumedForThisPress {
                action()
                self.actionConsumedForThisPress = true
            }
        }
        timer.resume()
        longPressTimer = timer
    }

    private func cancelLongPressTimer() {
        longPressTimer?.cancel()
        longPressTimer = nil
    }

    private func rescheduleLongPressTimer() {
        cancelLongPressTimer()
        scheduleLongPressTimer { [weak self] in self?.overlay.enter() }
    }

    // MARK: - App Cycling

    private func cycleToNextApp() {
        if cycleThroughAllApps {
            cycleThroughList()
        } else {
            toggleToPreviousApp()
        }
    }

    private func cycleThroughList() {
        if cycleSnapshot == nil {
            cycleSnapshot = effectiveCycleList()
            cycleIndex = 0
        }

        cycleSnapshot?.removeAll { $0.isTerminated }

        guard let list = cycleSnapshot, !list.isEmpty else {
            cycleSnapshot = nil
            overlay.dismiss(reactivateOrigin: false)
            return
        }

        guard list.count > 1 else {
            isCycling = true
            activateApp(list[0])
            overlay.dismiss(reactivateOrigin: false)
            return
        }

        cycleIndex = (cycleIndex + 1) % list.count
        isCycling = true
        activateApp(list[cycleIndex])
        overlay.dismiss(reactivateOrigin: false)
    }

    private func toggleToPreviousApp() {
        let list = effectiveCycleList()
        guard list.count >= 2 else {
            if let only = list.first {
                isCycling = true
                activateApp(only)
            }
            overlay.dismiss(reactivateOrigin: false)
            return
        }
        let target = list[1]
        isCycling = true
        activateApp(target)
        // Pre-emptively reorder MRU so rapid presses bounce correctly,
        // even if the workspace activation notification hasn't fired yet.
        mru.removeAll { $0.processIdentifier == target.processIdentifier }
        mru.insert(target, at: 0)
        overlay.dismiss(reactivateOrigin: false)
    }

    private func effectiveCycleList() -> [NSRunningApplication] {
        pruneMRU()
        let marked = Preferences.markedBundleIDs
        if marked.isEmpty { return mru }
        let filtered = mru.filter { app in
            guard let bid = app.bundleIdentifier else { return false }
            return marked.contains(bid)
        }
        return filtered.isEmpty ? mru : filtered
    }

    // MARK: - MRU Management

    private func seedMRU() {
        let running = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && !app.isHidden && !app.isTerminated
        }

        var list: [NSRunningApplication] = []
        if let front = running.first(where: { $0.isActive }) {
            list.append(front)
        }
        for app in running where !list.contains(where: { $0.processIdentifier == app.processIdentifier }) {
            list.append(app)
        }
        mru = list
        pruneMRU()
    }

    private func recordActivation(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        if isCycling {
            isCycling = false
        } else {
            cycleIndex = 0
            cycleSnapshot = nil
        }
        mru.removeAll { $0.processIdentifier == app.processIdentifier }
        mru.insert(app, at: 0)
        pruneMRU()
    }

    private func pruneMRU() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        mru.removeAll { app in
            app.processIdentifier == myPID ||
            app.activationPolicy != .regular ||
            app.isHidden ||
            app.isTerminated
        }
    }

    // MARK: - Activation Helpers

    private func axFallbackActivate(_ app: NSRunningApplication) {
        _ = app.unhide()
        _ = app.activate(options: [])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let switcherooBeginRecording = Notification.Name("SwitcherooBeginShortcutRecording")
    static let switcherooEndRecording   = Notification.Name("SwitcherooEndShortcutRecording")
}
