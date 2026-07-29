import Foundation

public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "chargePolicy"
    private let topUpKey = "topUpOriginalPolicy"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ChargePolicy {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(ChargePolicy.self, from: data)
        else { return ChargePolicy() }
        return value
    }

    public func save(_ policy: ChargePolicy) {
        guard let data = try? JSONEncoder().encode(policy) else { return }
        defaults.set(data, forKey: key)
    }

    public func loadTopUpOriginalPolicy() -> ChargePolicy? {
        guard let data = defaults.data(forKey: topUpKey) else { return nil }
        return try? JSONDecoder().decode(ChargePolicy.self, from: data)
    }

    public func saveTopUpOriginalPolicy(_ policy: ChargePolicy?) {
        guard let policy else {
            defaults.removeObject(forKey: topUpKey)
            return
        }
        guard let data = try? JSONEncoder().encode(policy) else { return }
        defaults.set(data, forKey: topUpKey)
    }
}
