import XCTest

final class SettingsUITests: SpendlyUITestCase {
    private func addCategory(named name: String) {
        app.buttons["newCategoryButton"].tap()
        let field = app.textFields["categoryNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(name)
        app.buttons["categorySave"].tap()
        waitUntilGone(field)
        // Rows further down the list aren't created until scrolled to.
        let row = app.buttons["categoryRow-\(name)"]
        for _ in 0..<4 where !row.exists {
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 3), "\(name) was not added")
    }

    func testFreeVersionShowsUpgradeAndLocksExport() {
        launch()
        openSettings()
        XCTAssertTrue(app.buttons["upgradeButton"].exists)
        app.buttons["exportLocked"].tap()
        XCTAssertTrue(app.staticTexts["paywallTitle"].waitForExistence(timeout: 3))
    }

    func testCustomCategoryShowsUpOnTheKeypad() {
        launch()
        openCategories()
        addCategory(named: "gym")

        dismissSheets()
        type("1")
        XCTAssertTrue(app.buttons["chip-gym"].waitForExistence(timeout: 3))
    }

    func testRenamingACategoryUpdatesIt() {
        launch()
        openCategories()
        app.buttons["categoryRow-fun"].tap()
        let field = app.textFields["categoryNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.clearAndType("going out")
        app.buttons["categorySave"].tap()
        XCTAssertTrue(app.buttons["categoryRow-going out"].waitForExistence(timeout: 3))
    }

    func testFourthCustomCategoryNeedsPro() {
        launch()
        openCategories()
        addCategory(named: "gym")
        addCategory(named: "pets")
        addCategory(named: "kids")
        app.buttons["newCategoryButton"].tap()
        XCTAssertTrue(app.staticTexts["paywallTitle"].waitForExistence(timeout: 3))
    }

    func testArchivedCategoryLeavesTheKeypad() {
        launch()
        openCategories()
        app.buttons["categoryRow-fun"].swipeLeft()
        let archive = app.buttons.matching(NSPredicate(format: "label ==[c] 'archive'")).firstMatch
        XCTAssertTrue(archive.waitForExistence(timeout: 3))
        archive.tap()
        waitUntilGone(app.buttons["categoryRow-fun"])

        dismissSheets()
        type("1")
        XCTAssertFalse(app.buttons["chip-fun"].exists)
    }

    func testProRemovesTheLimits() {
        launch(pro: true)
        openCategories()
        addCategory(named: "gym")
        addCategory(named: "pets")
        addCategory(named: "kids")
        addCategory(named: "books")
        XCTAssertFalse(app.staticTexts["paywallTitle"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["proActive"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["exportShareLink"].exists)
    }

    func testPaywallCloses() {
        launch()
        openSettings()
        app.buttons["upgradeButton"].tap()
        XCTAssertTrue(app.staticTexts["paywallTitle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["restoreButton"].exists)
        app.buttons["paywallClose"].tap()
        waitUntilGone(app.staticTexts["paywallTitle"])
    }
}

extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
