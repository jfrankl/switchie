import AppKit

/// Manages the status bar item and its menu.
final class StatusBarController {
    private var statusItem: NSStatusItem?

    func installStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let img = NSImage(systemSymbolName: "s.circle", accessibilityDescription: "Switchie") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "Switchie"
            }
            button.toolTip = "Switchie"
        }

        item.menu = buildMenu()
        statusItem = item
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let dockItem = NSMenuItem(title: dockMenuTitle(), action: #selector(toggleDockIcon), keyEquivalent: "")
        dockItem.target = self
        dockItem.state = DockIconManager.shared.showDockIcon ? .on : .off
        menu.addItem(dockItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Switchie", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
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
