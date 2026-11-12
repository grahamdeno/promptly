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
            switch phase {
            case .active: Task { await model.becameActive() }
            case .inactive, .background: Task { await model.wentToBackground() }
            default: break
            }
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
        .id(model.gumColor)
        .fullScreenCover(item: $model.arrived) { meeting in
            NowView(meeting: meeting)
                .environment(model)
        }
        .onOpenURL { url in
            Task { await model.open(url) }
        }
        .onChange(of: model.linkToOpen) { _, url in
            guard let url else { return }
            if !ScreenshotMode.isOn { openURL(url) }
            model.linkToOpen = nil
        }
    }
}
