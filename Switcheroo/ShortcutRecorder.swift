import SwiftUI
import AppKit
import Combine

// MARK: - Recording Coordination

@MainActor
private final class RecordingCoordinator: ObservableObject {
    static let shared = RecordingCoordinator()

    private var activeID: UUID?

    func begin(for picker: ShortcutPickerHandle) {
        if let current = activeID, current != picker.recorderID {
            NotificationCenter.default.post(name: .switcherooCancelOtherPicker, object: current)
        }
        activeID = picker.recorderID
        NotificationCenter.default.post(name: .switcherooBeginRecording, object: nil)
    }

    func end(for picker: ShortcutPickerHandle) {
        guard activeID == picker.recorderID else { return }
        activeID = nil
        NotificationCenter.default.post(name: .switcherooEndRecording, object: nil)
    }

    func pickerDeinit(_ picker: ShortcutPickerHandle) {
        guard activeID == picker.recorderID else { return }
        activeID = nil
        NotificationCenter.default.post(name: .switcherooEndRecording, object: nil)
    }
}

private protocol ShortcutPickerHandle {
    var recorderID: UUID { get }
    func cancelRecordingAndRevert()
}

// MARK: - ShortcutPicker

struct ShortcutPicker: View, ShortcutPickerHandle {
    @Binding var shortcut: Shortcut

    @State private var isRecording = false
    @State private var liveModifiers: NSEvent.ModifierFlags = []
    @State private var snapshotBeforeRecording: Shortcut?
    @State private var hovered = false
    @FocusState private var focused: Bool
    @State private var _recorderID = UUID()

    private let coordinator = RecordingCoordinator.shared

    fileprivate var recorderID: UUID { _recorderID }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: beginRecording) {
                Text(displayText)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentTransition(.opacity)
                    .padding(.horizontal, 12)
                    .background(fieldBackground)
                    .overlay(fieldStroke)
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .focusable(true)
            .focused($focused)
            .onHover { hovered = $0 }
            .accessibilityLabel("Shortcut")

            Button(action: clearShortcut) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isRecording ? Color.white.opacity(0.7) : Theme.Color.tertiaryLabel)
            }
            .buttonStyle(.plain)
            .help("Clear shortcut")
            .padding(.trailing, 6)
            .opacity(hasShortcut ? 1 : 0)
            .disabled(!hasShortcut)
        }
        .frame(width: Theme.Metrics.fieldWidth, height: Theme.Metrics.pickerHeight)
        .background(RecorderEventCatcher(
            isRecording: $isRecording,
            onCommit: { new in
                shortcut = new
                NotificationCenter.default.post(
                    name: .switcherooShortcutCommitted,
                    object: nil,
                    userInfo: ["shortcut": new, "senderID": recorderID]
                )
                endRecording()
            },
            onCancel: {
                if let snap = snapshotBeforeRecording { shortcut = snap }
                endRecording()
            }
        ))
        .onReceive(NotificationCenter.default.publisher(for: .switcherooCancelOtherPicker)) { note in
            if let id = note.object as? UUID, id == recorderID {
                cancelRecordingAndRevert()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switcherooShortcutCommitted)) { note in
            guard let info = note.userInfo,
                  let committed = info["shortcut"] as? Shortcut,
                  let sender = info["senderID"] as? UUID,
                  sender != recorderID,
                  committed == shortcut,
                  hasShortcut else { return }
            shortcut = Shortcut(keyCode: 0, modifiers: [])
        }
        .onDisappear { coordinator.pickerDeinit(self) }
    }

    // MARK: - ShortcutPickerHandle

    func cancelRecordingAndRevert() {
        guard isRecording else { return }
        if let snap = snapshotBeforeRecording { shortcut = snap }
        endRecording()
    }

    // MARK: - State

    private var hasShortcut: Bool { shortcut.keyCode != 0 }

    private var displayText: String {
        if isRecording { return "•••" }
        let s = shortcut.displayString.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty || shortcut.keyCode == 0 ? " " : s
    }

    private func clearShortcut() { shortcut = Shortcut(keyCode: 0, modifiers: []) }

    private func beginRecording() {
        guard !isRecording else { return }
        snapshotBeforeRecording = shortcut
        isRecording = true
        focused = true
        coordinator.begin(for: self)
    }

    private func endRecording() {
        guard isRecording else { return }
        isRecording = false
        focused = false
        liveModifiers = []
        coordinator.end(for: self)
    }

    // MARK: - Styling

    private var textColor: SwiftUI.Color {
        isRecording ? .white : Theme.Color.label
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
            .fill(isRecording ? Theme.Color.accent : Theme.Color.fieldBackground)
    }

    private var fieldStroke: some View {
        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
            .stroke(isRecording ? Theme.Color.accent : Theme.Color.separator.opacity(0.6),
                    lineWidth: 0.5)
    }
}

// MARK: - Event Capture NSView

private struct RecorderEventCatcher: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCommit: (Shortcut) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderCatcherView {
        let v = RecorderCatcherView()
        v.handler = context.coordinator
        return v
    }

    func updateNSView(_ nsView: RecorderCatcherView, context: Context) {
        nsView.handler = context.coordinator
        nsView.isRecording = isRecording
        if isRecording, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async { _ = nsView.window?.makeFirstResponder(nsView) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, RecorderCatcherHandling {
        let parent: RecorderEventCatcher
        init(_ parent: RecorderEventCatcher) { self.parent = parent }

        func didCancel() { parent.onCancel() }
        func didCommit(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
            parent.onCommit(Shortcut(keyCode: UInt32(keyCode), modifiers: flags))
        }
    }
}

private protocol RecorderCatcherHandling: AnyObject {
    func didCancel()
    func didCommit(keyCode: UInt16, flags: NSEvent.ModifierFlags)
}

private final class RecorderCatcherView: NSView {
    weak var handler: RecorderCatcherHandling?
    var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        if event.keyCode == 53 { handler?.didCancel(); return }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift, .capsLock, .function])
        handler?.didCommit(keyCode: event.keyCode, flags: flags)
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording { handler?.didCancel() } else { super.mouseDown(with: event) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isRecording {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                _ = self.window?.makeFirstResponder(self)
            }
        }
    }
}

// MARK: - Internal Notification Names

extension Notification.Name {
    static let switcherooCancelOtherPicker  = Notification.Name("SwitcherooCancelOtherPicker")
    static let switcherooShortcutCommitted  = Notification.Name("SwitcherooShortcutCommitted")
}

private extension Color {
    init(nsColor: NSColor) { self.init(nsColor) }
}
