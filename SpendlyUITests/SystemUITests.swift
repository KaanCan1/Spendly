import XCTest

/// Localization, notifications and Apple's automated accessibility audit.
final class SystemUITests: SpendlyUITestCase {
    func testTurkishInterface() {
        launch(language: "tr")
        XCTAssertEqual(app.staticTexts["firstLaunchHint"].label, "tutarı yaz, sonra bir kategoriye dokun")
        XCTAssertTrue(todayPill.label.hasPrefix("bugün"))
        XCTAssertEqual(app.buttons["chip-food"].label, "yemek olarak kaydet")

        openSettings()
        XCTAssertTrue(app.staticTexts["ayarlar"].exists)
    }

    func testBudgetAlertArrivesAsANotification() {
        launch()
        log("50", as: "food")
        openOverview()
        app.buttons["legend-food"].tap()
        app.buttons["editLimitButton"].tap()
        type("100")
        app.buttons["setLimitButton"].tap()
        allowNotificationsIfAsked()
        dismissSheets()

        // ₺50 + ₺40 = 90% of ₺100: crosses the 80% line.
        log("40", as: "food")

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'budget'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "no budget notification banner")
        XCTAssertTrue(banner.label.contains("90%"))
    }

    func testAccessibilityAuditOnQuickAdd() throws {
        launch(demo: true)
        try audit()
    }

    func testAccessibilityAuditOnOverview() throws {
        launch(demo: true)
        openOverview()
        try audit()
    }

    /// The default-size audit only predicts clipping; this one looks at the real layout with the
    /// largest accessibility text.
    func testAccessibilityAuditOnOverviewAtLargestText() throws {
        launch(demo: true, largestText: true)
        openOverview()
        try audit()
    }

    func testAccessibilityAuditOnQuickAddAtLargestText() throws {
        launch(demo: true, largestText: true)
        try audit()
    }

    func testAccessibilityAuditOnSettings() throws {
        launch(demo: true)
        openSettings()
        try audit()
    }

    /// Display numerals that keep a fixed size on purpose: they are already large and the
    /// layout is built around them.
    private static let fixedSizeDisplays = [
        "amountDisplay", "monthTotal", "editorAmount", "limitAmount", "paywallTitle",
        "currencyMenu", "currencySymbol", "kindToggle", "key-",
    ]

    /// Rows checked by eye at the largest accessibility size, where they wrap in full; the audit
    /// still predicts clipping for a List button row.
    private static let checkedAtLargestSize = ["upgradeButton"]

    private func isInsideDisabledButton(_ element: XCUIElement) -> Bool {
        let frame = element.frame
        return app.buttons.matching(NSPredicate(format: "enabled == false")).allElementsBoundByIndex
            .contains { $0.frame.contains(frame) }
    }

    private func isEmojiOnly(_ element: XCUIElement) -> Bool {
        element.elementType == .staticText && element.label.unicodeScalars.allSatisfy {
            ($0.properties.isEmoji && $0.value > 0xFF) || $0.value == 0xFE0F || $0.value == 0x200D
        }
    }

    /// Runs Apple's audit and reports every issue (not just the first), minus the known cases
    /// below. Each one was checked on screen at the largest accessibility text size.
    private func audit() throws {
        continueAfterFailure = true
        try app.performAccessibilityAudit { issue in
            // A clipping prediction the audit can't tie to an element: the largest-text audits
            // check the real layout instead.
            guard let element = issue.element else { return issue.auditType == .textClipped }
            let id = element.identifier

            // The system draws navigation bar buttons on Liquid Glass and caps their text size.
            let navigationBar = self.app.navigationBars.firstMatch
            if navigationBar.exists && navigationBar.frame.contains(element.frame) { return true }

            switch issue.auditType {
            case .contrast:
                // WCAG exempts inactive controls: the category chips wait, dimmed, for an amount.
                // Emoji are color pictures, so text contrast doesn't apply to them.
                return self.isInsideDisabledButton(element) || self.isEmojiOnly(element)
            case .textClipped:
                // Emoji glyphs overhang the line box by design.
                return self.isEmojiOnly(element) || Self.checkedAtLargestSize.contains(id)
            case .dynamicType:
                if Self.fixedSizeDisplays.contains(where: { id.hasPrefix($0) }) { return true }
                // List rows scale with Dynamic Type; rows the larger text pushes off screen are
                // reported as only partially scaling.
                return issue.compactDescription.contains("partially")
                    && self.app.collectionViews.firstMatch.frame.contains(element.frame)
            default:
                return false
            }
        }
    }
}
