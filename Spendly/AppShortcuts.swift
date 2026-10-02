import AppIntents

/// Phrases Siri and Spotlight offer with no setup. App-only: one provider per bundle.
struct SpendlyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)",
                "Log \(\.$category) in \(.applicationName)",
            ],
            shortTitle: "Log expense",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenQuickAddIntent(),
            phrases: ["Open \(.applicationName) keypad"],
            shortTitle: "Quick add",
            systemImageName: "number.square"
        )
    }
}
