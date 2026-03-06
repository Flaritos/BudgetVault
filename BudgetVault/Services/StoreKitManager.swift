import StoreKit
import SwiftUI

private typealias StoreTransaction = StoreKit.Transaction

@Observable
@MainActor
final class StoreKitManager {

    static let premiumProductID = "com.budgetvault.premium"
    static let tipProductID = "com.budgetvault.tip"

    /// Hardcoded launch pricing end date (set to 30 days after App Store approval).
    /// The actual price change happens in App Store Connect; this banner is cosmetic.
    static let launchPricingEndDate = Date(timeIntervalSince1970: 1_751_328_000) // ~July 1, 2026

    var products: [Product] = []
    var isPremium = false
    var purchaseState: PurchaseState = .idle
    var errorMessage: String?
    var productLoadError: String?

    enum PurchaseState {
        case idle, loading, success, error
    }

    var isLaunchPricing: Bool {
        Date() < Self.launchPricingEndDate
    }

    var premiumProduct: Product? {
        products.first { $0.id == Self.premiumProductID }
    }

    var tipProduct: Product? {
        products.first { $0.id == Self.tipProductID }
    }

    // nonisolated(unsafe) needed so deinit can cancel the task
    private nonisolated(unsafe) var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }

        Task {
            await loadProducts()
            await checkEntitlements()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        productLoadError = nil
        do {
            products = try await Product.products(for: [Self.premiumProductID, Self.tipProductID])
            if products.isEmpty {
                productLoadError = "Unable to load products. Check your connection."
            }
        } catch {
            print("Failed to load products: \(error)")
            productLoadError = "Unable to load products. Check your connection."
        }
    }

    func retryLoadProducts() {
        Task {
            await loadProducts()
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseState = .loading
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkEntitlements()
                purchaseState = .success
                // Cache for instant UI
                UserDefaults.standard.set(isPremium, forKey: "isPremium")

            case .userCancelled:
                purchaseState = .idle
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastPaywallDecline")

            case .pending:
                purchaseState = .idle
                errorMessage = "Purchase is pending approval."

            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .error
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Entitlements

    func checkEntitlements() async {
        var hasPremium = false

        for await result in StoreTransaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.premiumProductID {
                hasPremium = true
            }
        }

        isPremium = hasPremium
        // Cache for instant UI
        UserDefaults.standard.set(isPremium, forKey: "isPremium")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in StoreTransaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                await checkEntitlements()
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
