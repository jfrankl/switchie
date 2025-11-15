import Cocoa
import SwiftUI
import Combine
import UserNotifications

@main
struct SwitcherooApp: App {
    @StateObject private var switcher = Switcher.shared
    private let statusBarController = StatusBarController()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Text("Switcheroo")
                    .font(.system(size: 22, weight: .bold))

                Text("Press your shortcut to switch apps by MRU order.\nPress again to move to the next app.\nStop pressing for the configured delay to select.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                // Shortcut configuration
                ShortcutSettingsView()

                // Long-press delay control
                LongPressDelaySettingsView()

                // Number badges toggle
                NumberBadgesSettingsView()

                Spacer()

                Text("Tip: If media keys adjust volume, enable “Use F1, F2, etc. keys as standard function keys” or hold Fn while pressing function keys.\nAccessibility permission may be requested for full control features.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(switcher.backgroundColor.ignoresSafeArea())
            .onAppear {
                DispatchQueue.main.async {
                    // Apply persisted dock icon preference
                    DockIconManager.shared.applyCurrentPreference()
                    statusBarController.installStatusItem()

                    // Bring the app to the front even if another app is active
                    NSApp.activate(ignoringOtherApps: true)
                }
                Switcher.shared.start()
            }
        }
        .defaultSize(width: 520, height: 380)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
    }
}

// MARK: - Dock Icon Manager

final class DockIconManager {
    static let shared = DockIconManager()
    private init() {}

    private let defaultsKey = "ShowDockIcon"

    var showDockIcon: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    func applyCurrentPreference() {
        setDockIconVisible(showDockIcon)
    }

    func toggle() {
        showDockIcon.toggle()
        setDockIconVisible(showDockIcon)
    }

    private func setDockIconVisible(_ visible: Bool) {
        let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
        NSApplication.shared.setActivationPolicy(policy)

        if visible {
            // Ensure the app comes to the very front when showing the Dock icon
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Status Bar

final class StatusBarController {
    private var statusItem: NSStatusItem?

    func installStatusItem() {
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let img = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Switcheroo") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "Switcheroo"
            }
            button.toolTip = "Switcheroo"
        }
        let menu = NSMenu()

        let dockItem = NSMenuItem(title: dockMenuTitle(), action: #selector(toggleDockIcon), keyEquivalent: "")
        dockItem.target = self
        dockItem.state = DockIconManager.shared.showDockIcon ? .on : .off
        menu.addItem(dockItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Switcheroo", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.last?.target = self

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleDockIcon(_ sender: NSMenuItem) {
        DockIconManager.shared.toggle()
        sender.state = DockIconManager.shared.showDockIcon ? .on : .off
        sender.title = dockMenuTitle()
    }

    private func dockMenuTitle() -> String {
        DockIconManager.shared.showDockIcon ? "Hide Dock Icon" : "Show Dock Icon"
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Shortcut Settings UI

struct ShortcutSettingsView: View {
    @State private var current = Shortcut.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Global Shortcut")
                .font(.headline)
            HStack(spacing: 12) {
                ShortcutRecorder(shortcut: $current)
                    .frame(width: 180)
                Button("Save") {
                    current.save()
                    Switcher.shared.applyShortcut(current)
                }
                Button("Reset") {
                    current = .default
                    current.save()
                    Switcher.shared.applyShortcut(current)
                }
                Text("Current: \(current.displayString)")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            current = Shortcut.load()
        }
    }
}

// MARK: - Long-press Delay Settings UI

struct LongPressDelaySettingsView: View {
    @ObservedObject private var switcher = Switcher.shared
    @State private var tempDelay: Double = Switcher.shared.longPressThreshold

    private let range: ClosedRange<Double> = 0.2...2.0
    private let step: Double = 0.05

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Long‑Press Delay")
                .font(.headline)
            HStack(spacing: 12) {
                Slider(value: $tempDelay, in: range, step: step, onEditingChanged: { editing in
                    if !editing {
                        apply()
                    }
                })
                .frame(width: 200)

                Stepper(value: $tempDelay, in: range, step: step) {
                    EmptyView()
                }
                .onChange(of: tempDelay) { _, _ in
                    // live apply on stepper taps
                    apply()
                }

                Text(String(format: "%.2fs", tempDelay))
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
                    .foregroundStyle(.secondary)

                Button("Reset") {
                    tempDelay = Switcher.defaultLongPressDelay
                    apply()
                }
            }
            .onAppear {
                tempDelay = switcher.longPressThreshold
            }
        }
    }

    private func apply() {
        Switcher.shared.applyLongPressDelay(tempDelay)
    }
}

// MARK: - Number badges settings UI

struct NumberBadgesSettingsView: View {
    @ObservedObject private var switcher = Switcher.shared

    var body: some View {
        Toggle("Show number badges in overlay", isOn: Binding(
            get: { switcher.showNumberBadges },
            set: { Switcher.shared.setShowNumberBadges($0) }
        ))
        .toggleStyle(.switch)
        .padding(.top, 6)
    }
}

// MARK: - Switcher Core

final class Switcher: ObservableObject {
    static let shared = Switcher()
    private init() {
        // Load persisted long-press delay at init
        self.longPressThreshold = Self.loadPersistedLongPressDelay()
        // Load persisted number badges preference
        self.showNumberBadges = UserDefaults.standard.object(forKey: Self.numberBadgesDefaultsKey) as? Bool ?? true
    }

    @Published var backgroundColor: Color = Color(NSColor.windowBackgroundColor)

    // Long-press delay (user adjustable)
    @Published private(set) var longPressThreshold: TimeInterval
    static let defaultLongPressDelay: TimeInterval = 1.0
    private static let longPressDefaultsKey = "LongPressDelay"

    // Number badges preference
    @Published private(set) var showNumberBadges: Bool
    private static let numberBadgesDefaultsKey = "ShowNumberBadges"

    private var pressStart: Date?
    private var longPressTimer: DispatchSourceTimer?
    private var actionConsumedForThisPress = false

    private var systemMonitor: Any?

    private var activationObserver: Any?
    private var mru: [NSRunningApplication] = []

    private let overlay = OverlayWindowController()

    private var shortcut: Shortcut = .default

    // Overlay typing state
    private var overlaySearchText: String = ""
    private var overlayFiltered: [NSRunningApplication] = []
    private var overlaySelectedIndex: Int? = nil
    private var overlayEventMonitor: Any?
    private var overlayGlobalEventMonitor: Any? // NEW: global key monitor

    func start() {
        requestNotificationAuthorization()

        shortcut = Shortcut.load()
        applyShortcut(shortcut)

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.recordActivation(app)
        }

        seedMRU()
    }

    func applyShortcut(_ shortcut: Shortcut) {
        self.shortcut = shortcut
        HotKeyManager.shared.register(shortcut: shortcut) { [weak self] event in
            switch event {
            case .pressed:
                self?.onHotkeyPressed()
            case .released:
                self?.onHotkeyReleased()
            }
        }
    }

    func applyLongPressDelay(_ value: TimeInterval) {
        let clamped = max(0.05, min(5.0, value))
        guard clamped != longPressThreshold else { return }
        longPressThreshold = clamped
        UserDefaults.standard.set(clamped, forKey: Self.longPressDefaultsKey)

        // If a long-press is currently pending, reschedule to respect the new delay
        if pressStart != nil {
            rescheduleLongPressTimer()
        }
    }

    func setShowNumberBadges(_ show: Bool) {
        guard show != showNumberBadges else { return }
        showNumberBadges = show
        UserDefaults.standard.set(show, forKey: Self.numberBadgesDefaultsKey)
        // If overlay is visible, refresh it to reflect the new setting
        overlay.update(candidates: overlayFiltered, selectedIndex: overlaySelectedIndex, searchText: overlaySearchText, showNumberBadges: showNumberBadges)
    }

    private static func loadPersistedLongPressDelay() -> TimeInterval {
        let v = UserDefaults.standard.double(forKey: longPressDefaultsKey)
        if v == 0 {
            return defaultLongPressDelay
        }
        return max(0.05, min(5.0, v))
    }

    private func onHotkeyPressed() {
        actionConsumedForThisPress = false
        pressStart = Date()

        cancelLongPressTimer()
        scheduleLongPressTimer()
    }

    private func scheduleLongPressTimer() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + longPressThreshold)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.cancelLongPressTimer()
            if self.actionConsumedForThisPress == false {
                self.enterOverlayMode()
                self.actionConsumedForThisPress = true
            }
        }
        t.resume()
        longPressTimer = t
    }

    private func rescheduleLongPressTimer() {
        // Called when user changes the delay mid-press
        cancelLongPressTimer()
        // Compute remaining time from new threshold if desired; for simplicity, start a fresh timer
        scheduleLongPressTimer()
    }

    private func onHotkeyReleased() {
        let elapsed = pressStart.map { Date().timeIntervalSince($0) } ?? 0
        cancelLongPressTimer()
        pressStart = nil

        if actionConsumedForThisPress {
            actionConsumedForThisPress = false
            return
        }

        if elapsed < longPressThreshold {
            restorePreviousApp()
            actionConsumedForThisPress = true
        }
        actionConsumedForThisPress = false
    }

    private func cancelLongPressTimer() {
        longPressTimer?.cancel()
        longPressTimer = nil
    }

    private func restorePreviousApp() {
        postDebugNotification()
        updateBackgroundColor()
        pruneMRU()
        guard !mru.isEmpty else {
            NSLog("MRU empty; nothing to activate.")
            overlay.hide(animated: true)
            removeOverlayEventMonitor()
            return
        }
        let targetIndex = (mru.count > 1) ? 1 : 0
        let target = mru[targetIndex]
        activateApp(target)
        overlay.hide(animated: true)
        removeOverlayEventMonitor()
    }

    private func enterOverlayMode() {
        pruneMRU()
        if mru.isEmpty {
            overlay.hide(animated: true)
            removeOverlayEventMonitor()
            return
        }
        // Initialize overlay state
        overlaySearchText = ""
        overlayFiltered = mru
        overlaySelectedIndex = overlayFiltered.isEmpty ? nil : 0

        postOverlayEnteredNotification(candidateCount: mru.count)
        overlay.show(candidates: overlayFiltered, selectedIndex: overlaySelectedIndex, searchText: overlaySearchText, showNumberBadges: showNumberBadges, onSelect: { [weak self] app in
            guard let self else { return }
            self.activateApp(app)
            self.overlay.hide(animated: true)
            self.removeOverlayEventMonitor()
        })

        installOverlayEventMonitor()
    }

    private func seedMRU() {
        let running = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                !app.isHidden &&
                !app.isTerminated
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
        mru.removeAll { $0.processIdentifier == app.processIdentifier }
        mru.insert(app, at: 0)
        pruneMRU()
    }

    private func pruneMRU() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        mru = mru.filter { app in
            app.processIdentifier != myPID &&
            app.activationPolicy == .regular &&
            !app.isHidden &&
            !app.isTerminated
        }
    }

    private func activateApp(_ app: NSRunningApplication) {
        let name = app.localizedName ?? app.bundleIdentifier ?? "App"

        // Avoid deprecated .activateIgnoringOtherApps on macOS 14+; it has no effect.
        let optionSets: [[NSApplication.ActivationOptions]] = [
            [.activateAllWindows],
            []
        ]

        for opts in optionSets {
            let ok: Bool
            if opts.isEmpty {
                ok = app.activate()
            } else {
                ok = app.activate(options: NSApplication.ActivationOptions(opts))
            }
            NSLog("Activating \(name) with options \(opts) -> \(ok ? "OK" : "Failed")")
            if ok { return }
        }

        if let url = app.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: config) { result, error in
                if result != nil {
                    NSLog("Reopen \(name) via NSWorkspace -> OK")
                } else {
                    NSLog("Reopen \(name) via NSWorkspace -> Failed (\(error?.localizedDescription ?? "unknown"))")
                    self.axUnhideAndRaise(app, appName: name)
                }
            }
            return
        }

        axUnhideAndRaise(app, appName: name)
    }

    // MARK: - Overlay typing support

    private func installOverlayEventMonitor() {
        removeOverlayEventMonitor()

        // Local monitor (works when our app is active)
        overlayEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            switch event.type {
            case .keyDown:
                if self.handleOverlayKeyDown(event) {
                    // Swallow event
                    return nil
                }
                return event
            default:
                return event
            }
        }

        // Global monitor (works when another app is active)
        overlayGlobalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return }
            _ = self.handleOverlayKeyDown(event)
        }
    }

    private func removeOverlayEventMonitor() {
        if let monitor = overlayEventMonitor {
            NSEvent.removeMonitor(monitor)
            overlayEventMonitor = nil
        }
        if let global = overlayGlobalEventMonitor {
            NSEvent.removeMonitor(global)
            overlayGlobalEventMonitor = nil
        }
    }

    private func handleOverlayKeyDown(_ event: NSEvent) -> Bool {
        // Navigation keys
        if let charsIgnoringMods = event.charactersIgnoringModifiers, charsIgnoringMods.count == 1 {
            let c = charsIgnoringMods.unicodeScalars.first!
            switch c.value {
            case 0x1B: // Escape
                if overlaySearchText.isEmpty {
                    // Cancel overlay
                    overlay.hide(animated: true)
                    removeOverlayEventMonitor()
                } else {
                    overlaySearchText = ""
                    recomputeOverlayFilterAndUpdate()
                }
                return true
            case 0x7F: // Delete (backspace)
                if !overlaySearchText.isEmpty {
                    overlaySearchText.removeLast()
                    recomputeOverlayFilterAndUpdate()
                }
                return true
            case 0x0D, 0x03: // Return / Enter
                if let idx = overlaySelectedIndex, overlayFiltered.indices.contains(idx) {
                    let app = overlayFiltered[idx]
                    activateApp(app)
                    overlay.hide(animated: true)
                    removeOverlayEventMonitor()
                }
                return true
            default:
                break
            }
        }

        // Arrow keys (left/right), tab to cycle
        if let special = event.specialKey {
            switch special {
            case .leftArrow:
                moveSelection(delta: -1)
                return true
            case .rightArrow:
                moveSelection(delta: 1)
                return true
            case .tab:
                let delta = event.modifierFlags.contains(.shift) ? -1 : 1
                moveSelection(delta: delta)
                return true
            default:
                break
            }
        }

        // Printable characters -> digits select directly, others build search
        if let chars = event.characters, !chars.isEmpty {
            let scalars = chars.unicodeScalars
            if scalars.count == 1, let digit = scalars.first, ("0"..."9").contains(Character(digit)) {
                if selectByDigit(Character(digit)) {
                    return true
                }
            }

            // Keep only scalars that are reasonably printable
            let printableScalars = scalars.filter { scalar in
                switch scalar.properties.generalCategory {
                case .control, .format, .surrogate, .privateUse, .unassigned:
                    return false
                default:
                    return true
                }
            }
            if !printableScalars.isEmpty {
                overlaySearchText.append(String(String.UnicodeScalarView(printableScalars)))
                recomputeOverlayFilterAndUpdate()
                return true
            }
        }

        return false
    }

    // Select an app by typed digit (1-based; 0 means 10)
    private func selectByDigit(_ ch: Character) -> Bool {
        guard !overlayFiltered.isEmpty else { return false }
        let index: Int
        switch ch {
        case "1"..."9":
            index = Int(String(ch))! - 1
        case "0":
            index = 9 // 10th item
        default:
            return false
        }
        guard overlayFiltered.indices.contains(index) else { return false }
        let app = overlayFiltered[index]
        activateApp(app)
        overlay.hide(animated: true)
        removeOverlayEventMonitor()
        return true
    }

    private func moveSelection(delta: Int) {
        guard !overlayFiltered.isEmpty else { return }
        let current = overlaySelectedIndex ?? 0
        let next = (current + delta % overlayFiltered.count + overlayFiltered.count) % overlayFiltered.count
        overlaySelectedIndex = next
        overlay.update(candidates: overlayFiltered, selectedIndex: overlaySelectedIndex, searchText: overlaySearchText, showNumberBadges: showNumberBadges)
    }

    private func recomputeOverlayFilterAndUpdate() {
        if overlaySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            overlayFiltered = mru
        } else {
            let needle = overlaySearchText.lowercased()
            overlayFiltered = mru.filter { app in
                let name = (app.localizedName ?? app.bundleIdentifier ?? "").lowercased()
                return matchesWordPrefix(name: name, query: needle)
            }
        }
        overlaySelectedIndex = overlayFiltered.isEmpty ? nil : min(overlaySelectedIndex ?? 0, overlayFiltered.count - 1)
        overlay.update(candidates: overlayFiltered, selectedIndex: overlaySelectedIndex, searchText: overlaySearchText, showNumberBadges: showNumberBadges)

        // Auto-accept when exactly one candidate remains
        if overlayFiltered.count == 1, let only = overlayFiltered.first {
            activateApp(only)
            overlay.hide(animated: true)
            removeOverlayEventMonitor()
        }
    }

    // Word-prefix matching: every query token must match the start of some word in the name.
    // Words are split on non-alphanumeric boundaries.
    private func matchesWordPrefix(name: String, query: String) -> Bool {
        let nameWords = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let queryTokens = query.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        guard !queryTokens.isEmpty else { return true }

        // Each token must be a prefix of at least one word
        for token in queryTokens {
            var matchedThisToken = false
            for word in nameWords {
                if word.hasPrefix(token) {
                    matchedThisToken = true
                    break
                }
            }
            if !matchedThisToken { return false }
        }
        return true
    }

    // MARK: - Missing helpers implemented

    private func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("Notification authorization error: \(error.localizedDescription)")
            } else {
                NSLog("Notification authorization granted: \(granted)")
            }
        }
    }

    private func postDebugNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Switcheroo"
        content.body = "Quick switched to previous app."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("postDebugNotification failed: \(error.localizedDescription)")
            }
        }
    }

    private func postOverlayEnteredNotification(candidateCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Switcheroo"
        content.body = "Overlay shown with \(candidateCount) apps."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("postOverlayEnteredNotification failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateBackgroundColor() {
        DispatchQueue.main.async {
            self.backgroundColor = Color(NSColor.windowBackgroundColor)
        }
    }

    private func axUnhideAndRaise(_ app: NSRunningApplication, appName: String) {
        let unhidden = app.unhide()
        let activated = app.activate(options: [])
        NSLog("AX fallback for \(appName): unhide=\(unhidden) activate=\(activated)")
    }
}
