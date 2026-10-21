import AppKit
import Combine
import RevenueCat
import Security
import SwoopCore

/// RevenueCat identifiers. These must match the Swoop project in the RevenueCat dashboard.
enum RevenueCatConfig {
    static let entitlement = "swoop_pro"
    static let productID = "swoop_lifetime"
    static let fallbackPrice = "$9.99"

    /// Public SDK key. Release builds read it from Info.plist (`RevenueCatAPIKey`).
    /// Debug builds fall back to the Test Store key, which RevenueCat makes crash in release
    /// builds on purpose, so it is never used there.
    static var apiKey: String? {
        if let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            #if DEBUG
            return key
            #else
            return key.hasPrefix("test_") ? nil : key
            #endif
        }
        #if DEBUG
        return "test_hdtchnynYCunrkvcsaYWDwtHzWf"
        #else
        return nil
        #endif
    }

    /// RevenueCat Web Purchase Link (Paddle / Web Billing checkout). When set, "Buy" opens it in
    /// the browser with this Mac's app user ID; otherwise the purchase goes through the SDK
    /// (Test Store while developing).
    static var webPurchaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "RevenueCatWebPurchaseURL") as? String,
              !raw.isEmpty, !raw.hasPrefix("$(") else { return nil }
        return URL(string: raw)
    }
}

/// Trial + lifetime license, backed by RevenueCat's swoop_pro entitlement.
/// Used from the main thread only (menu, settings, event tap all run on the main run loop).
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var status: LicenseStatus = .free
    @Published private(set) var price = RevenueCatConfig.fallbackPrice
    @Published private(set) var isWorking = false
    @Published var message: String?

    private var hasEntitlement = false
    private var package: Package?
    private var started = false
    private lazy var paywall = PaywallController(manager: self)

    var licensingEnabled: Bool { RevenueCatConfig.apiKey != nil }

    // MARK: Start

    func start() {
        guard !started else { return }
        started = true
        guard let key = RevenueCatConfig.apiKey else {
            status = .free
            return
        }
        recompute(trialStart: TrialClock.startDate())
        if status == .expired {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                // Only nag if RevenueCat hasn't found a purchase in the meantime.
                if self?.status == .expired { self?.showPaywall() }
            }
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)

        Task { @MainActor [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        Task { @MainActor [weak self] in await self?.loadOffering() }

        // Coming back from the browser checkout: check right away.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        // The trial runs out while the app stays open.
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.recompute(trialStart: TrialClock.startDate())
        }
    }

    // MARK: State

    @MainActor
    private func apply(_ info: CustomerInfo) {
        hasEntitlement = info.entitlements[RevenueCatConfig.entitlement]?.isActive == true
        recompute(trialStart: TrialClock.startDate())
        if hasEntitlement { paywall.close() }
    }

    private func recompute(trialStart: Date) {
        status = TrialPolicy.status(trialStart: trialStart, now: Date(),
                                    hasEntitlement: hasEntitlement, licensingEnabled: licensingEnabled)
    }

    @MainActor
    private func loadOffering() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let current = offerings.current
            package = current?.lifetime
                ?? current?.availablePackages.first { $0.storeProduct.productIdentifier == RevenueCatConfig.productID }
                ?? current?.availablePackages.first
            if let p = package { price = p.storeProduct.localizedPriceString }
        } catch {
            NSLog("Swoop: could not load offerings: \(error.localizedDescription)")
        }
    }

    func refresh() {
        guard licensingEnabled else { return }
        Task { @MainActor [weak self] in
            guard let info = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent) else { return }
            self?.apply(info)
        }
    }

    // MARK: Gate

    /// True when Swoop may move windows. When the trial is over, shows the paywall instead.
    func allowAction() -> Bool {
        if status.canUseSwoop { return true }
        showPaywall()
        return false
    }

    func showPaywall() {
        paywall.show()
    }

    var statusLine: String {
        switch status {
        case .free: return ""
        case .licensed: return "Swoop Pro: lifetime license"
        case .trial(let days): return days == 1 ? "Free trial: last day" : "Free trial: \(days) days left"
        case .expired: return "Free trial ended"
        }
    }

    // MARK: Buy / restore

    func buy() {
        guard licensingEnabled else { return }
        message = nil
        if let base = RevenueCatConfig.webPurchaseURL {
            // Web Purchase Link + app user ID, so the purchase lands on this Mac's RevenueCat customer.
            let url = base.appendingPathComponent(Purchases.shared.appUserID)
            NSWorkspace.shared.open(url)
            message = "Finish checkout in your browser. Swoop unlocks as soon as you come back."
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.package == nil { await self.loadOffering() }
            guard let package = self.package else {
                self.message = "Couldn't load the price. Check your internet connection and try again."
                return
            }
            self.isWorking = true
            defer { self.isWorking = false }
            do {
                let result = try await Purchases.shared.purchase(package: package)
                if !result.userCancelled { self.apply(result.customerInfo) }
            } catch {
                self.message = Self.describe(error)
            }
        }
    }

    func restore() {
        guard licensingEnabled else { return }
        message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isWorking = true
            defer { self.isWorking = false }
            do {
                let info = try await Purchases.shared.restorePurchases()
                self.apply(info)
                if !self.hasEntitlement {
                    self.message = "No Swoop purchase found for this Mac yet. If you bought it in the browser, open the link in your receipt email on this Mac."
                }
            } catch {
                self.message = Self.describe(error)
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        if let code = error as? RevenueCat.ErrorCode {
            switch code {
            case .networkError, .offlineConnectionError:
                return "You seem to be offline. Check your connection and try again."
            case .purchaseNotAllowedError:
                return "Purchases aren't allowed on this Mac."
            case .paymentPendingError:
                return "Your payment is pending. Swoop unlocks when it goes through."
            default:
                return code.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

/// When the free trial started. Kept in the Keychain so reinstalling Swoop doesn't restart it.
enum TrialClock {
    private static let service = "com.iam8uman.swoop.trial"
    private static let account = "trialStart"

    static func startDate() -> Date {
        #if DEBUG
        // SWOOP_TRIAL_EXPIRED=1 swift run  → see the "trial ended" paywall right away.
        if ProcessInfo.processInfo.environment["SWOOP_TRIAL_EXPIRED"] == "1" {
            return Date().addingTimeInterval(-TrialPolicy.length - 60)
        }
        #endif
        if let stored = read() { return stored }
        let now = Date()
        write(now)
        return now
    }

    private static func read() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, let text = String(data: data, encoding: .utf8),
           let seconds = TimeInterval(text) {
            return Date(timeIntervalSince1970: seconds)
        }
        // Fallback if the Keychain isn't available.
        let fallback = UserDefaults.standard.double(forKey: "SwoopTrialStart")
        return fallback > 0 ? Date(timeIntervalSince1970: fallback) : nil
    }

    private static func write(_ date: Date) {
        let text = String(date.timeIntervalSince1970)
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "SwoopTrialStart")
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(match as CFDictionary)
        var attributes = match
        attributes[kSecValueData as String] = Data(text.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
