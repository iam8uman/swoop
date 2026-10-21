import Foundation

/// Where a copy of Swoop stands: paid, in its free trial, or trial over.
public enum LicenseStatus: Equatable, Sendable {
    /// Licensing isn't set up in this build (no RevenueCat key): everything is free.
    case free
    /// The swoop_pro entitlement is active.
    case licensed
    /// Inside the free trial, with whole days left (at least 1).
    case trial(daysLeft: Int)
    /// Trial used up and no license.
    case expired

    /// Window actions are allowed.
    public var canUseSwoop: Bool {
        if case .expired = self { return false }
        return true
    }
}

public enum TrialPolicy {
    public static let length: TimeInterval = 14 * 24 * 60 * 60

    public static func status(trialStart: Date, now: Date, hasEntitlement: Bool, licensingEnabled: Bool = true) -> LicenseStatus {
        guard licensingEnabled else { return .free }
        if hasEntitlement { return .licensed }
        // A clock set back before the trial started doesn't add days.
        let elapsed = max(0, now.timeIntervalSince(trialStart))
        let remaining = length - elapsed
        guard remaining > 0 else { return .expired }
        return .trial(daysLeft: max(1, Int((remaining / 86_400).rounded(.up))))
    }
}
