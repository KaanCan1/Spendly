import SwiftUI

@main
struct SpendlyApp: App {
    init() {
        #if DEBUG
        DemoData.seedIfRequested(SpendlyEnvironment.store)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: SpendlyEnvironment.store)
        }
    }
}
