import StoreKit
import SwiftUI
import os
import BudgetVaultShared

private let storeKitLog = Logger(subsystem: "io.budgetvault.app", category: "storekit")

private typealias StoreTransaction = StoreKit.Transaction

@Observable
@MainActor
final class StoreKitManager {

    static let premiumProductID = "io.budgetvault.premium"
    static let tipProductID = "io.budgetvault.tip"

    /// Hardcoded launch pricing end date (set to 30 days after App Store approval).
    /// The actual price change happens in App Store Connect; this banner is cosmetic.
    static let launchPricingEndDate = Date(timeIntervalSince1970: 1_782_950_400) // July 1, 2026 UTC

    var products: [Product] = []
    var isPremium = false
    var purchaseState: PurchaseState = .idle
    var errorMessage: String?
    var productLoadError: String?
    var showPendingAlert = false
    var showPostPurchaseWelcome = false

    enum PurchaseState {
        case idle, loading, success, error
    }

    var isLaunchPricing: Bool {
        Date() < Self.launchPricingEndDate
    }

    /// Returns a countdown string like "92d 14h 23m" for launch pricing, or nil if expired.
    var launchCountdownComponents: (days: Int, hours: Int, minutes: Int)? {
        guard isLaunchPricing else { return nil }
        let remaining = Self.launchPricingEndDate.timeIntervalSince(Date())
        guard remaining > 0 else { return nil }
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return (days, hours, minutes)
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
            // NOTE: The displayPrice shown during dev/sim runs comes from
            // BudgetVault/Configuration.storekit (StoreKit Testing). The
            // production price is driven by App Store Connect and does
            // NOT use this file. Sim storekitd daemons sometimes cache
            // stale prices in com.apple.storekitd/Cache.db across erases.
            // If sim shows a different price than Configuration.storekit:
            //   1. Confirm the bundled file via `find ... Configuration.storekit`
            //   2. Know that users will see App Store Connect's price, period.
            if products.isEmpty {
                productLoadError = "Unable to load products. Check your connection."
            }
        } catch {
            storeKitLog.error("Failed to load products: \(error.localizedDescription, privacy: .private)")
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
                // Audit fix: only show the success state if the
                // entitlement actually landed. If checkEntitlements
                // doesn't flip `isPremium` to true (silent verification
                // failure, stale cache, etc.), leave purchaseState
                // idle so the user can retry instead of seeing a
                // "Thanks!" screen that didn't actually unlock anything.
                if isPremium {
                    purchaseState = .success
                    showPostPurchaseWelcome = true
                    UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
                    KeychainService.set(true, forKey: "isPremium")
                } else {
                    purchaseState = .error
                    errorMessage = "Purchase went through, but we couldn't verify it yet. Tap Restore Purchases below to sync."
                }

            case .userCancelled:
                purchaseState = .idle
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppStorageKeys.lastPaywallDecline)

            case .pending:
                purchaseState = .idle
                showPendingAlert = true

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
        #if DEBUG
        // In debug builds, respect manually-set isPremium flag for testing
        if UserDefaults.standard.bool(forKey: AppStorageKeys.debugPremiumOverride) {
            isPremium = true
            UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
            KeychainService.set(true, forKey: "isPremium")
            return
        }
        #endif

        var hasPremium = false

        for await result in StoreTransaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.premiumProductID {
                hasPremium = true
            }
        }

        isPremium = hasPremium
        // Cache for instant UI
        UserDefaults.standard.set(isPremium, forKey: AppStorageKeys.isPremium)

        // Keychain is the authoritative source of truth for premium status.
        // Sync Keychain to match StoreKit's verified entitlement state.
        if hasPremium {
            KeychainService.set(true, forKey: "isPremium")
        } else {
            KeychainService.delete(forKey: "isPremium")
        }
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
