import Foundation
import Observation
import StoreKit

/// Spendly Pro with StoreKit 2: a monthly subscription or a one-time lifetime purchase.
///
/// Entitlements come from the App Store's signed transactions (`Transaction.currentEntitlements`),
/// so there is nothing to keep on a server and nothing to fake locally.
@MainActor
@Observable
final class ProStore {
    static let monthlyID = "com.kaancankurt.spendly.pro.monthly"
    static let lifetimeID = "com.kaancankurt.spendly.pro.lifetime"

    enum LoadState: Equatable {
        case loading
        case loaded
        case unavailable
    }

    private(set) var isPro = false
    private(set) var products: [Product] = []
    private(set) var loadState = LoadState.loading
    private(set) var purchasing: Product.ID?

    @ObservationIgnored private var updates: Task<Void, Never>?

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var lifetime: Product? { products.first { $0.id == Self.lifetimeID } }

    /// Loads products, reads current entitlements, and keeps listening for renewals, refunds and
    /// purchases made on other devices.
    func start() async {
        guard updates == nil else { return }
        #if DEBUG
        // UI tests decide Pro with a launch argument and never touch StoreKit, so purchases left
        // on the simulator by other test runs can't leak in.
        if SpendlyEnvironment.isUITest {
            isPro = ProcessInfo.processInfo.arguments.contains("-uitestPro")
            loadState = .unavailable
            return
        }
        #endif
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        loadState = .loading
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.lifetimeID])
                .sorted { $0.price < $1.price }
            loadState = products.isEmpty ? .unavailable : .loaded
        } catch {
            loadState = .unavailable
        }
    }

    /// Returns true when the purchase went through (false when cancelled or pending).
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        purchasing = product.id
        defer { purchasing = nil }
        switch try await product.purchase() {
        case .success(.verified(let transaction)):
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .success(.unverified):
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement, transaction.revocationDate == nil else { continue }
            // An expired subscription can still be listed for a while; it must not keep Pro on.
            if let expiration = transaction.expirationDate, expiration <= .now { continue }
            if transaction.productID == Self.monthlyID || transaction.productID == Self.lifetimeID {
                active = true
            }
        }
        isPro = active
    }
}
