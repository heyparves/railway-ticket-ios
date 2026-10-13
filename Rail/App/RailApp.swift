import SwiftData
import SwiftUI

@main
struct RailApp: App {
    private let modelContainer: ModelContainer
    @State private var container: AppContainer
    @State private var session: SessionStore

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let modelContainer: ModelContainer
        do {
            modelContainer = try Persistence.makeContainer(inMemory: isUITesting)
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
        let container = AppContainer.local(
            modelContainer: modelContainer,
            secureStore: isUITesting ? InMemorySecureStore() : KeychainStore()
        )
        self.modelContainer = modelContainer
        _container = State(initialValue: container)
        _session = State(initialValue: SessionStore(auth: container.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(session)
        }
        .modelContainer(modelContainer)
    }
}
