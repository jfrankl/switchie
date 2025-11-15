import SwiftUI

struct LongPressDelaySettingsView: View {
    @EnvironmentObject private var switcher: Switcher
    @State private var tempDelay: Double = 0

    private let range: ClosedRange<Double> = 0...3.0
    private let step: Double = 0.05

    var body: some View {
        HStack(spacing: 10) {
            // Continuous slider — no `step:` so macOS doesn't draw tick dots.
            // The Stepper provides snap-to-step adjustments separately.
            Slider(value: $tempDelay, in: range) { editing in
                if !editing { apply() }
            }
            .frame(width: 180)

            Stepper(value: $tempDelay, in: range, step: step) { EmptyView() }
                .onChange(of: tempDelay) { _, _ in apply() }

            Text(String(format: "%.2fs", tempDelay))
                .font(Theme.Font.body)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
                .foregroundStyle(Theme.Color.tertiaryLabel)
        }
        .onAppear { tempDelay = switcher.longPressThreshold }
    }

    private func apply() {
        switcher.applyLongPressDelay(tempDelay)
    }
}
