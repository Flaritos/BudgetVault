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

    /// Audit 2026-04-22 P1-34: per-install 30-day launch window. The
    /// old hardcoded `Date(timeIntervalSince1970: 1_782_950_400)` meant
    /// if App Review slipped past July 1 2026 the banner would be
    /// expired on first launch — marketing shipped dead copy. Now we
    /// stamp the install date on first StoreKitManager construction
    /// and give every user a 30-day window from their own first open.
    private static let launchPricingWindow: TimeInterval = 30 * 24 * 60 * 60

    /// Audit 2026-04-23 R2: pure getter — reads the stamped install
    /// date if present, otherwise assumes "stamped now" for display
    /// purposes WITHOUT mutating UserDefaults. Stamping happens once
    /// in `stampInstallDateIfNeeded()`, called from `init()`.
    ///
    /// Prior implementation wrote to UserDefaults inside the getter,
    /// which polluted StoreKitManagerTests (first test run permanently
    /// stamped the install date into the prod defaults store).
    static var launchPricingEndDate: Date {
        let stamped = UserDefaults.standard.double(forKey: AppStorageKeys.installDate)
        let installDate = stamped > 0
            ? Date(timeIntervalSince1970: stamped)
            : Date() // Not stamped yet; use "now" for display, don't persist.
        return installDate.addingTimeInterval(launchPricingWindow)
    }

    /// Stamps the install date if not already set. Idempotent.
    /// Called once from `init()` on first app launch so the 30-day
    /// window anchors to the user's actual first open.
    static func stampInstallDateIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.double(forKey: AppStorageKeys.installDate) == 0 {
            defaults.set(Date().timeIntervalSince1970, forKey: AppStorageKeys.installDate)
        }
    }

    var products: [Product] = []
    var isPremium = false
    var purchaseState: PurchaseState = .idle
    var errorMessage: String?
    // Audit 2026-04-22 P0-16: toggled true when the last purchase error
    // was recoverable by retry (e.g. network flake). The paywall uses
    // this to show a Retry button alongside the error copy.
    var errorIsRetryable = false
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
        // Audit 2026-04-23 R2: stamp install date on first launch,
        // side-effect-free from `launchPricingEndDate` getter.
        Self.stampInstallDateIfNeeded()

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
        errorIsRetryable = false

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
                    Self.setPremiumKeychain(true, callsite: "purchase-success")
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
            storeKitLog.error("Purchase failed: \(error.localizedDescription, privacy: .private)")
            purchaseState = .error
            let mapped = Self.mapPurchaseError(error)
            errorMessage = mapped.message
            errorIsRetryable = mapped.retryable
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        errorIsRetryable = false
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            storeKitLog.error("Restore failed: \(error.localizedDescription, privacy: .private)")
            let mapped = Self.mapPurchaseError(error)
            errorMessage = "Restore failed. \(mapped.message)"
            errorIsRetryable = mapped.retryable
        }
    }

    // Audit 2026-04-22 P0-16: previously surfaced raw
    // `error.localizedDescription` — users saw cryptic enum-name strings
    // for common cases like "no network." Map the shipped StoreKit error
    // types (`StoreKitError`, `Product.PurchaseError`) into purpose-built
    // copy and flag `retryable` so the UI can offer a Retry affordance
    // only where it actually helps.
    private static func mapPurchaseError(_ error: Error) -> (message: String, retryable: Bool) {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return ("Couldn't reach the App Store. Check your connection and try again.", true)
            case .systemError:
                return ("Something went wrong on Apple's end. Please try again in a moment.", true)
            case .userCancelled:
                return ("", false)
            case .notAvailableInStorefront:
                return ("This purchase isn't available in your region yet.", false)
            case .notEntitled:
                return ("Your Apple ID can't make this purchase — check Screen Time restrictions in iOS Settings.", false)
            case .unknown:
                return ("Purchase failed for an unknown reason. Try again, or contact support if this keeps happening.", true)
            @unknown default:
                return (storeKitError.localizedDescription, false)
            }
        }
        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return ("This product isn't available right now. Please try again later.", true)
            case .purchaseNotAllowed:
                return ("Purchases aren't allowed on this Apple ID. Check Screen Time / parental controls in iOS Settings.", false)
            case .ineligibleForOffer:
                return ("You're not eligible for this offer.", false)
            case .invalidQuantity, .invalidOfferIdentifier, .invalidOfferPrice, .invalidOfferSignature, .missingOfferParameters:
                return ("This offer is misconfigured. Please contact support.", false)
            @unknown default:
                return (purchaseError.localizedDescription, false)
            }
        }
        // Verification failure (thrown from checkVerified) falls through
        // to here along with any other exotic error. Generic copy + no
        // retry because retrying an unverified receipt will produce the
        // same result.
        return ("We couldn't verify this purchase. Tap Restore Purchases to sync, or contact support if this keeps happening.", false)
    }

    // MARK: - Entitlements

    func checkEntitlements() async {
        #if DEBUG
        // In debug builds, respect manually-set isPremium flag for testing
        if UserDefaults.standard.bool(forKey: AppStorageKeys.debugPremiumOverride) {
            isPremium = true
            UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
            Self.setPremiumKeychain(true, callsite: "debug-override")
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
            Self.setPremiumKeychain(true, callsite: "checkEntitlements")
        } else {
            KeychainService.delete(forKey: "isPremium")
        }
    }

    // Audit 2026-04-22 P1-36: previously we called `KeychainService.set`
    // and discarded its OSStatus. The most common failure mode is
    // `errSecInteractionNotAllowed` (device locked right after a
    // purchase completes) — which silently dropped the premium flag.
    // checkEntitlements re-runs on each foreground + transaction
    // update so transient failures self-heal; we just need a log trail
    // so the opaque "bought premium, app forgot by next launch" user
    // reports are diagnosable from Console.app.
    private static func setPremiumKeychain(_ value: Bool, callsite: String) {
        let status = KeychainService.set(value, forKey: "isPremium")
        guard status != errSecSuccess else { return }
        storeKitLog.error("Keychain set(isPremium=\(value, privacy: .public)) from \(callsite, privacy: .public) failed: OSStatus=\(status, privacy: .public)")
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
