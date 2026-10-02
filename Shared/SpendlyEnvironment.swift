import Foundation
import SpendlyData
import SwiftData
import WidgetKit

/// Compiled into both the app and the widget extension.
///
/// One store per process, shared by the UI, the App Intents and the widgets, all on the same
/// App Group container — two stores in one process would each cache their own copy of the data.
@MainActor
enum SpendlyEnvironment {
    static let isExtension = Bundle.main.bundleURL.pathExtension == "appex"

    static let store: SwiftDataExpenseStore = {
        let container: ModelContainer
        do {
            // Only the app mirrors to iCloud; extensions read and write the local store.
            container = try SpendlySchema.makeContainer(cloudSync: !isExtension)
        } catch {
            // A broken on-disk store must not brick the app; keep it usable in memory and log loudly.
            assertionFailure("Failed to open store: \(error)")
            container = try! SpendlySchema.makeInMemoryContainer()
        }
        let store = SwiftDataExpenseStore(container: container)
        try? store.seedDefaultCategoriesIfNeeded()
        return store
    }()

    /// Widgets show today's total and the usual entries; refresh them after any change.
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
