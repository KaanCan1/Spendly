import XCTest

final class OverviewUITests: SpendlyUITestCase {
    func testOverviewSumsTheMonthAndListsEntries() {
        launch()
        log("100", as: "food")
        log("40", as: "transport")
        openOverview()

        waitUntil(app.staticTexts["monthTotal"], contains: "₺140")
        XCTAssertTrue(app.buttons["entry-food"].exists)
        XCTAssertTrue(app.buttons["entry-transport"].exists)
        XCTAssertTrue(app.buttons["legend-food"].exists)
    }

    func testFirstBudgetIsFreeAndWarnsAtEightyPercent() {
        launch()
        log("100", as: "food")
        openOverview()

        app.buttons["legend-food"].tap()
        XCTAssertTrue(app.buttons["editLimitButton"].waitForExistence(timeout: 3))
        app.buttons["editLimitButton"].tap()

        XCTAssertTrue(app.buttons["setLimitButton"].waitForExistence(timeout: 3))
        type("120")
        app.buttons["setLimitButton"].tap()
        allowNotificationsIfAsked()

        // ₺100 of ₺120 is 83%: the line turns red and says so.
        let warning = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '83%'")).firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
    }

    func testSecondBudgetNeedsPro() {
        launch()
        log("100", as: "food")
        log("40", as: "transport")
        openOverview()

        app.buttons["legend-food"].tap()
        app.buttons["editLimitButton"].tap()
        type("300")
        app.buttons["setLimitButton"].tap()
        allowNotificationsIfAsked()

        app.buttons["legend-transport"].tap()
        XCTAssertTrue(app.buttons["editLimitButton"].waitForExistence(timeout: 3))
        app.buttons["editLimitButton"].tap()
        XCTAssertTrue(app.staticTexts["paywallTitle"].waitForExistence(timeout: 3))
    }

    func testEditingChangesAmountAndCategory() {
        launch()
        log("245", as: "food")
        openOverview()

        app.buttons["entry-food"].tap()
        XCTAssertTrue(app.staticTexts["editorAmount"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["editorAmount"].label, "245")

        key("key-delete").tap()
        app.buttons.matching(identifier: "chip-coffee").allElementsBoundByIndex.last(where: \.isHittable)?.tap()

        XCTAssertTrue(app.buttons["entry-coffee"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["entry-food"].exists)
        waitUntil(app.staticTexts["monthTotal"], contains: "₺24")
    }

    func testDeleteFromTheEditor() {
        launch()
        log("60", as: "fun")
        openOverview()

        app.buttons["entry-fun"].tap()
        XCTAssertTrue(app.buttons["deleteEntryButton"].waitForExistence(timeout: 3))
        app.buttons["deleteEntryButton"].tap()
        waitUntilGone(app.buttons["entry-fun"])
    }

    func testSwipeToDelete() {
        launch()
        log("60", as: "fun")
        openOverview()

        app.buttons["entry-fun"].swipeLeft()
        // The swipe action, not the keypad's delete key under the sheet.
        let delete = app.buttons.matching(NSPredicate(format: "label ==[c] 'delete' AND identifier != 'key-delete'")).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        waitUntilGone(app.buttons["entry-fun"])
        waitUntil(app.staticTexts["monthTotal"], contains: "₺0")
    }

    func testPreviousMonthIsReachable() {
        launch()
        openOverview()
        app.buttons["previousMonth"].tap()
        XCTAssertTrue(app.buttons["nextMonth"].isEnabled)
        app.buttons["nextMonth"].tap()
        waitUntil(app.staticTexts["monthTotal"], contains: "₺0")
    }
}
