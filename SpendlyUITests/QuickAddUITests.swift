import XCTest

final class QuickAddUITests: SpendlyUITestCase {
    func testFirstLaunchShowsTheHintAndWaitsForAnAmount() {
        launch()
        XCTAssertTrue(app.staticTexts["firstLaunchHint"].waitForExistence(timeout: 5))
        XCTAssertEqual(amountText, "0")
        XCTAssertFalse(app.buttons["chip-food"].isEnabled, "categories must wait for an amount")
        XCTAssertTrue(todayPill.label.contains("₺0"))
    }

    func testTwoTapsLogAnExpense() {
        launch()
        type("85")
        XCTAssertEqual(amountText, "85")
        XCTAssertTrue(app.buttons["chip-coffee"].isEnabled)

        app.buttons["chip-coffee"].tap()

        XCTAssertTrue(app.buttons["undoButton"].waitForExistence(timeout: 3), "undo is offered after saving")
        waitUntil(todayPill, contains: "₺85")
        XCTAssertEqual(amountText, "0", "keypad resets for the next expense")
    }

    func testUndoRemovesTheExpenseItJustLogged() {
        launch()
        log("120", as: "food")
        XCTAssertTrue(app.buttons["undoButton"].waitForExistence(timeout: 3))
        app.buttons["undoButton"].tap()
        waitUntil(todayPill, contains: "₺0")
    }

    /// Regression: a full-screen swipe recognizer used to swallow fast repeated key taps.
    func testFastTypingKeepsEveryDigit() {
        launch()
        for _ in 0..<6 { app.buttons["key-1"].tap() }
        XCTAssertEqual(amountText, "111,111")
        type("00")
        XCTAssertEqual(amountText, "11,111,100")
    }

    func testDecimalDeleteAndLongPressClear() {
        launch()
        type("12.5")
        XCTAssertEqual(amountText, "12.5")
        type(".")
        XCTAssertEqual(amountText, "12.5", "a second separator is ignored")
        type("55")
        XCTAssertEqual(amountText, "12.55")
        type("9")
        XCTAssertEqual(amountText, "12.55", "only two decimals for lira")

        app.buttons["key-delete"].tap()
        XCTAssertEqual(amountText, "12.5")
        app.buttons["key-delete"].press(forDuration: 1.0)
        XCTAssertEqual(amountText, "0")
    }

    func testHabitSuggestionLogsTheUsualAmountInOneTap() {
        launch()
        log("85", as: "coffee")
        let suggestion = app.buttons["suggestion"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 8), "suggestion appears once the undo toast is gone")
        XCTAssertTrue(suggestion.label.contains("₺85"))

        suggestion.tap()
        waitUntil(todayPill, contains: "₺170")
    }

    func testIncomeModeLogsIncomeWithItsOwnCategories() {
        launch()
        app.buttons["kindToggle"].tap()
        XCTAssertTrue(app.buttons["chip-salary"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["chip-coffee"].exists)

        log("500", as: "salary")
        waitUntil(todayPill, contains: "+₺500")

        app.buttons["kindToggle"].tap()
        waitUntil(todayPill, contains: "₺0")
    }

    func testExpenseOnAPastDayStaysOutOfToday() {
        launch()
        app.buttons["dayButton"].tap()
        XCTAssertTrue(app.buttons["day-1"].waitForExistence(timeout: 3))
        app.buttons["day-1"].tap()

        log("40", as: "transport")
        waitUntil(todayPill, contains: "₺0")

        openOverview()
        XCTAssertTrue(app.buttons["entry-transport"].waitForExistence(timeout: 3))
    }

    func testNoteIsSavedWithTheExpense() {
        launch()
        app.buttons["noteButton"].tap()
        let field = app.textFields["noteField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("flat white\n")

        log("85", as: "coffee")
        openOverview()
        XCTAssertTrue(app.buttons["entry-coffee"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["entry-coffee"].label.contains("flat white"), app.buttons["entry-coffee"].label)
    }

    func testCurrencyCanBeSwitchedFromTheKeypad() {
        launch()
        app.buttons["currencyMenu"].tap()
        let dollar = app.buttons.matching(NSPredicate(format: "label CONTAINS 'USD'")).firstMatch
        XCTAssertTrue(dollar.waitForExistence(timeout: 3))
        dollar.tap()
        waitUntil(app.buttons["currencyMenu"], contains: "USD")
        waitUntil(todayPill, contains: "$0")
    }
}
