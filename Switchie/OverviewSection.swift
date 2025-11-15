import SwiftUI
import AppKit

/// Singleton controller for the custom About window. Replaces the default
/// macOS About panel with a richer Switchie-branded version.
@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: AboutView())
            let win = NSWindow(contentViewController: host)
            win.styleMask = [.titled, .closable]
            win.title = ""
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 360, height: 320))
            window = win
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - About Window Content

struct AboutView: View {
    private let appName = "Switchie"

    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            VStack(spacing: 2) {
                Text(appName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Color.label)
                Text("Version \(versionString)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Color.secondaryLabel)
                    .monospacedDigit()
            }

            Text("A fast, keyboard-driven app and window switcher for macOS.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Color.secondaryLabel)
                .frame(maxWidth: 280)

            Spacer().frame(height: 4)

            HStack(spacing: 10) {
                linkButton("GitHub", systemImage: "arrow.up.right.square") {
                    open("https://github.com/jfrankl/switchie/")
                }
                linkButton("Leave Feedback", systemImage: "star.bubble") {
                    openFeedback()
                }
            }

            Text("\u{00A9} \(currentYear) Switchie")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Color.tertiaryLabel)
                .padding(.top, 4)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background)
    }

    private func linkButton(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(Theme.Font.buttonLabel)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .fill(Theme.Color.accentSubtle)
            )
            .foregroundStyle(Theme.Color.accent)
        }
        .buttonStyle(.plain)
    }

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(v) (\(b))"
    }

    private var currentYear: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: Date())
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openFeedback() {
        let fallback = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review")!
        let deep = URL(string: "macappstore://apps.apple.com/app/id1234567890?action=write-review")
        if let deep, NSWorkspace.shared.open(deep) { return }
        _ = NSWorkspace.shared.open(fallback)
    }
}
