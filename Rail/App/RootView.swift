import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKey.appearance) private var appearance = Appearance.system
    @State private var showsSplash = !ProcessInfo.processInfo.arguments.contains("-uiTesting")
    @ObserveInjection var inject

    var body: some View {
        ZStack {
            content
            if showsSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.35)) { showsSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(1)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .enableInjection()
    }

    private var content: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView { hasCompletedOnboarding = true }
            } else {
                switch session.phase {
                case .launching:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedOut:
                    AuthFlowView()
                case .signedIn:
                    MainTabView()
                }
            }
        }
        .animation(.default, value: session.phase)
        .animation(.default, value: hasCompletedOnboarding)
        .task {
            #if DEBUG
            await DemoSeeder.applyLaunchArguments(container: container, session: session)
            #endif
            await session.restore()
        }
    }
}
