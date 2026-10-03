import StoreKit
import StoreKitTest
import XCTest
@testable import Spendly

/// Runs the real StoreKit 2 code against Spendly.storekit through an `SKTestSession`:
/// products, purchases, renewals, expiry and refunds, with no App Store account.
@MainActor
final class ProStoreTests: XCTestCase {
    /// Held for the whole test: StoreKit testing stops the moment the session is released.
    private var session: SKTestSession?

    @discardableResult
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Spendly")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        self.session = session
        // Leave no purchases behind on the simulator for the next run (or the UI tests).
        nonisolated(unsafe) let cleanup = session
        addTeardownBlock { cleanup.clearTransactions() }
        return session
    }

    private func loadedStore() async throws -> ProStore {
        let pro = ProStore()
        await pro.loadProducts()
        XCTAssertEqual(pro.loadState, .loaded)
        return pro
    }

    func testBothProductsLoadWithTheirPrices() async throws {
        try makeSession()
        let pro = try await loadedStore()
        let monthly = try XCTUnwrap(pro.monthly)
        let lifetime = try XCTUnwrap(pro.lifetime)
        // StoreKit testing parses the configured prices with the simulator's region, so compare
        // shape rather than exact amounts: both priced, lifetime dearer, monthly a subscription.
        XCTAssertFalse(monthly.displayPrice.isEmpty)
        XCTAssertGreaterThan(lifetime.price, monthly.price)
        XCTAssertEqual(monthly.type, .autoRenewable)
        XCTAssertEqual(lifetime.type, .nonConsumable)
        XCTAssertFalse(pro.isPro)
    }

    /// Entitlement changes (expiry, refund) reach `currentEntitlements` a moment later.
    private func waitUntilNotPro(_ pro: ProStore, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<25 where pro.isPro {
            try? await Task.sleep(for: .milliseconds(200))
            await pro.refreshEntitlements()
        }
        XCTAssertFalse(pro.isPro, "Pro was not revoked", file: file, line: line)
    }

    func testLifetimePurchaseUnlocksPro() async throws {
        try makeSession()
        let pro = try await loadedStore()
        let purchased = try await pro.purchase(XCTUnwrap(pro.lifetime))
        XCTAssertTrue(purchased)
        XCTAssertTrue(pro.isPro)
    }

    func testMonthlySubscriptionUnlocksProUntilItExpires() async throws {
        let session = try makeSession()
        let pro = try await loadedStore()
        try await pro.purchase(XCTUnwrap(pro.monthly))
        XCTAssertTrue(pro.isPro)

        // The user turns off auto-renew, then the period ends. (With auto-renew on, StoreKit
        // testing renews the subscription the moment it expires.)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProStore.monthlyID })
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        try session.expireSubscription(productIdentifier: ProStore.monthlyID)
        await waitUntilNotPro(pro)
    }

    func testRefundTakesProAway() async throws {
        let session = try makeSession()
        let pro = try await loadedStore()
        try await pro.purchase(XCTUnwrap(pro.lifetime))
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProStore.lifetimeID })

        try session.refundTransaction(identifier: transaction.identifier)
        await waitUntilNotPro(pro)
    }

    func testFailedPurchaseKeepsTheFreeVersion() async throws {
        let session = try makeSession()
        session.failTransactionsEnabled = true
        let pro = try await loadedStore()
        _ = try? await pro.purchase(XCTUnwrap(pro.lifetime))
        XCTAssertFalse(pro.isPro)
    }

    func testRestoreFindsAnEarlierPurchase() async throws {
        try makeSession()
        let first = try await loadedStore()
        try await first.purchase(XCTUnwrap(first.lifetime))

        // A fresh store (a reinstall, a second device) learns about it from the App Store.
        let second = ProStore()
        XCTAssertFalse(second.isPro)
        await second.restore()
        XCTAssertTrue(second.isPro)
    }
}
