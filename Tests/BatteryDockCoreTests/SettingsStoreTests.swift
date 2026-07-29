import Foundation
import XCTest
@testable import BatteryDockCore

final class SettingsStoreTests: XCTestCase {
    func testTopUpOriginalPolicySurvivesRelaunchAndCanBeCleared() throws {
        let suiteName = "BatteryDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let original = ChargePolicy(upperLimit: 80, cruiseModeEnabled: true, cruiseDelta: 5)

        store.saveTopUpOriginalPolicy(original)
        XCTAssertEqual(store.loadTopUpOriginalPolicy(), original)

        store.saveTopUpOriginalPolicy(nil)
        XCTAssertNil(store.loadTopUpOriginalPolicy())
    }
}
