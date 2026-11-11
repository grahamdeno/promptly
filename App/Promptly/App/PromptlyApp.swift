import SwiftUI

@main
struct PromptlyApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.becameActive() } }
        }
        .backgroundTask(.appRefresh(AppModel.refreshTaskID)) {
            await model.backgroundRefresh()
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var model = model
        Group {
            if model.onboarded {
                HomeView()
            } else {
                WelcomeView()
            }
        }
        .preferredColorScheme(.light)
        .fullScreenCover(item: $model.arrived) { meeting in
            NowView(meeting: meeting)
                .environment(model)
        }
        .onChange(of: model.linkToOpen) { _, url in
            guard let url else { return }
            openURL(url)
            model.linkToOpen = nil
        }
    }
}
