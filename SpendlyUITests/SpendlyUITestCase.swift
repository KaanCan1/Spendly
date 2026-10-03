import XCTest

/// Shared setup for Spendly's UI tests.
///
/// Every test launches the app with `-uitest`: an empty in-memory store, TRY as the currency and
/// default settings, so tests never depend on each other or on data left on the simulator.
/// Elements are found by accessibility identifier, so the same tests work in any language.
@MainActor
class SpendlyUITestCase: XCTestCase {
    private(set) var app: XCUIApplication!

    @discardableResult
    func launch(demo: Bool = false, pro: Bool = false, language: String = "en", largestText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-uitest",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "tr" ? "tr_TR" : "en_US",
        ]
        if demo { app.launchArguments.append("-demo") }
        if pro { app.launchArguments.append("-uitestPro") }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        self.app = app
        return app
    }

    // MARK: Quick add

    /// Types an amount on the keypad: digits and "." for the decimal separator.
    /// When a sheet with its own keypad (editor, limit) is open, the one on top is used.
    func type(_ amount: String) {
        for character in amount {
            let id = character == "." ? "key-decimal" : "key-\(character)"
            key(id).tap()
        }
    }

    /// The topmost hittable keypad key with this identifier.
    func key(_ id: String) -> XCUIElement {
        let matches = app.buttons.matching(identifier: id)
        return matches.allElementsBoundByIndex.last(where: \.isHittable) ?? matches.firstMatch
    }

    /// Two taps: type the amount, tap the category. `category` is the stored English name.
    func log(_ amount: String, as category: String) {
        type(amount)
        app.buttons["chip-\(category)"].tap()
    }

    var amountText: String { app.staticTexts["amountDisplay"].label }
    var todayPill: XCUIElement { app.buttons["todayPill"] }

    // MARK: Navigation

    func openOverview() {
        todayPill.tap()
        XCTAssertTrue(app.staticTexts["monthTotal"].waitForExistence(timeout: 5), "overview did not open")
    }

    func openSettings() {
        openOverview()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["settingsDone"].waitForExistence(timeout: 5), "settings did not open")
    }

    func openCategories() {
        openSettings()
        app.buttons["categoriesLink"].tap()
        XCTAssertTrue(app.buttons["newCategoryButton"].waitForExistence(timeout: 5), "categories did not open")
    }

    /// Back to the keypad from wherever a test ended: pops the categories screen, closes
    /// settings, then pulls the overview sheet down.
    func dismissSheets() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists, !app.buttons["settingsDone"].exists { back.tap() }
        if app.buttons["settingsDone"].waitForExistence(timeout: 1) { app.buttons["settingsDone"].tap() }
        let total = app.staticTexts["monthTotal"]
        if total.waitForExistence(timeout: 2) {
            total.press(forDuration: 0.05, thenDragTo: app.buttons["key-1"].exists ? app.buttons["key-1"] : app.windows.firstMatch)
        }
        for _ in 0..<2 where total.exists {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
                .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        }
        XCTAssertTrue(app.buttons["key-1"].waitForExistence(timeout: 3), "could not get back to the keypad")
    }

    // MARK: System UI

    /// Answers the notification permission prompt with "Allow" if iOS shows it.
    func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), allow.exists {
            allow.tap()
        }
    }

    // MARK: Assertions

    func waitUntil(_ element: XCUIElement, contains text: String, timeout: TimeInterval = 5,
                   file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\"\(element.label)\" never contained \"\(text)\"", file: file, line: line)
    }

    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5,
                       file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed,
                       "element still visible", file: file, line: line)
    }
}
