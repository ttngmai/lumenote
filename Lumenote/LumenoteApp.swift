//

import SwiftUI
import SwiftData

@main
struct LumenoteApp: App {
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    private let container: ModelContainer
    private let learningLog: LearningLog

    init() {
        let container = LearningStore.makeContainer()
        self.container = container
        learningLog = LearningLog(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.colorScheme)
                .modelContainer(container)
                .environment(\.learningLog, learningLog)
        }
    }
}
