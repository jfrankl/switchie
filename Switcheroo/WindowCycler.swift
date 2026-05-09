import AppKit

final class WindowCycler {

    private var stackByPID: [pid_t: [AppWindow]] = [:]
    private var indexByPID: [pid_t: Int] = [:]

    // MARK: - Public

    func cycleWindow(in app: NSRunningApplication) {
        let pid = app.processIdentifier
        let liveWindows = WindowEnumerator.windows(for: app)

        if stackByPID[pid] == nil || stackByPID[pid]?.count != liveWindows.count {
            guard !liveWindows.isEmpty else {
                stackByPID[pid] = nil
                indexByPID[pid] = nil
                return
            }
            stackByPID[pid] = liveWindows
            indexByPID[pid] = liveWindows.count >= 2 ? 0 : -1
        }

        guard var stack = stackByPID[pid], !stack.isEmpty else { return }

        var nextIndex = ((indexByPID[pid] ?? -1) + 1) % stack.count
        var safety = 0

        while safety < 2 * max(stack.count, 1) {
            let candidate = stack[nextIndex]
            if isValid(candidate.axElement) {
                break
            }
            stack.remove(at: nextIndex)
            stackByPID[pid] = stack
            if stack.isEmpty {
                indexByPID[pid] = -1
                return
            }
            nextIndex = nextIndex % stack.count
            safety += 1
        }

        let target = stack[nextIndex]
        indexByPID[pid] = nextIndex

        WindowEnumerator.activate(window: target)
        _ = app.activate(options: [.activateAllWindows])
    }

    func resetStacks(exceptPID pid: pid_t) {
        stackByPID = stackByPID.filter { $0.key == pid }
        indexByPID = indexByPID.filter { $0.key == pid }
    }

    // MARK: - Private

    private func isValid(_ element: AXUIElement) -> Bool {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success
    }
}
