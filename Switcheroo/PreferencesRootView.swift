import SwiftUI

struct PreferencesRootView: View {
    @State private var selectedTab: PrefsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case .general: GeneralTab()
                    case .about:   AboutTab()
                    }
                }
                .padding(.horizontal, Theme.Metrics.contentPadding)
                .padding(.vertical, Theme.Metrics.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 620, height: 480)
        .background(Theme.Color.background)
        .navigationTitle(selectedTab.title)
    }

    private var tabBar: some View {
        HStack {
            Spacer()
            PreferencesTabBar(selection: $selectedTab)
            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Theme.Color.background)
    }
}
