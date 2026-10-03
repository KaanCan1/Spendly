import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI

/// The app opens straight to quick add. The overview is a swipe-up sheet on top of it.
struct RootView: View {
    let store: any ExpenseStore

    @Environment(\.scenePhase) private var scenePhase
    /// In the App Group's defaults so widgets and Siri log in the same currency.
    @AppStorage(SharedSettings.currencyCodeKey, store: SharedSettings.defaults)
    private var currencyCode = Currency.deviceDefault()
    @State private var showingOverview = false

    var body: some View {
        QuickAddView(store: store, currencyCode: $currencyCode, showOverview: { showingOverview = true })
            .sheet(isPresented: $showingOverview) {
                OverviewView(store: store, currencyCode: $currencyCode)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(SpendlyRadius.surface)
            }
            .tint(SpendlyColor.signature)
            // Widget links (spendly://add) mean "log something": land on the keypad.
            .onOpenURL { _ in showingOverview = false }
            // Widgets and reminder texts carry live numbers, so refresh them whenever data or currency changes.
            .onChange(of: store.revision) { dataChanged() }
            .onChange(of: currencyCode) { dataChanged() }
            .onChange(of: scenePhase) { _, phase in
                // A widget button or Siri may have logged something while we were in the background.
                if phase == .active { store.refresh() }
            }
    }

    private func dataChanged() {
        ReminderScheduler.reschedule(store: store, currencyCode: currencyCode)
        SpendlyEnvironment.reloadWidgets()
        // Lets Siri match "log coffee in Spendly" against the current category names.
        SpendlyShortcuts.updateAppShortcutParameters()
    }
}
