import Foundation

public final class Settings {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static let allowedIntervals: [Int] = [30, 60, 120, 300, 900]

    public var refreshIntervalSeconds: Int {
        get { defaults.object(forKey: "refreshIntervalSeconds") as? Int ?? 60 }
        set {
            let clamped = Self.allowedIntervals.min(by: {
                abs($0 - newValue) < abs($1 - newValue)
            }) ?? 60
            defaults.set(clamped, forKey: "refreshIntervalSeconds")
        }
    }

    public var hiddenRepos: [String] {
        get { defaults.stringArray(forKey: "hiddenRepos") ?? [] }
        set { defaults.set(newValue, forKey: "hiddenRepos") }
    }

    public var lastSeenPRIDs: [String] {
        get { defaults.stringArray(forKey: "lastSeenPRIDs") ?? [] }
        set { defaults.set(newValue, forKey: "lastSeenPRIDs") }
    }

    /// True once the first successful refresh has stored a baseline seen-set.
    /// Used to suppress notifications on the very first refresh after install,
    /// where every PR would otherwise look "new".
    public var hasInitialized: Bool {
        get { defaults.bool(forKey: "hasInitialized") }
        set { defaults.set(newValue, forKey: "hasInitialized") }
    }
}
