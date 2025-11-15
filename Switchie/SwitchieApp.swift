import SwiftUI
import AppKit

@main
struct SwitchieApp: App {
    @StateObject private var switcher = Switcher()
    private let statusBar = StatusBarController()

    var body: some Scene {
        WindowGroup {
            PreferencesRootView()
                .environmentObject(switcher)
                .background(Theme.Color.background.ignoresSafeArea())
                .onAppear {
                    DispatchQueue.main.async {
                        DockIconManager.shared.applyCurrentPreference()
                        statusBar.installStatusItem()
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    switcher.start()
                }
        }
        .defaultSize(width: 620, height: 500)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Switchie") {
                    AboutWindowController.shared.show()
                }
            }
        }
    }
}
