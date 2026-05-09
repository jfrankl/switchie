import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App identity
            HStack(alignment: .center, spacing: 14) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Switcheroo")
                        .font(Theme.Font.title)
                        .foregroundStyle(Theme.Color.label)
                    Text(versionString)
                        .font(Theme.Font.helpText)
                        .foregroundStyle(Theme.Color.secondaryLabel)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(.bottom, Theme.Metrics.sectionPadding)

            SectionDivider()

            VStack(alignment: .leading, spacing: Theme.Metrics.rowSpacing) {
                LabeledRow("Support:") {
                    Link(destination: URL(string: "https://github.com/jfrankl/switchie/")!) {
                        HStack(spacing: 4) {
                            Text("GitHub")
                                .font(Theme.Font.body)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Color.accent)
                    }
                }

                LabeledRow("Feedback:") {
                    Button(action: openAppStoreFeedback) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.bubble.fill")
                                .imageScale(.small)
                            Text("Leave a Review")
                                .font(Theme.Font.buttonLabel)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                                .fill(Theme.Color.accentSubtle)
                        )
                        .foregroundStyle(Theme.Color.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Theme.Metrics.sectionPadding)

            SectionDivider()
                .padding(.top, Theme.Metrics.sectionPadding)

            Text("Tip: If media keys adjust volume, enable \u{201C}Use F1, F2, etc. keys as standard function keys\u{201D} in System Settings, or hold Fn while pressing function keys.")
                .font(Theme.Font.helpText)
                .foregroundStyle(Theme.Color.tertiaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Metrics.sectionPadding)
        }
    }

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "Version \(v) (\(b))"
    }

    private func openAppStoreFeedback() {
        let fallback = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review")!
        let deep = URL(string: "macappstore://apps.apple.com/app/id1234567890?action=write-review")
        if let deep, NSWorkspace.shared.open(deep) { return }
        _ = NSWorkspace.shared.open(fallback)
    }
}
