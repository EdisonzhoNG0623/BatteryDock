import XCTest
@testable import BatteryDockCore

final class CruiseControllerTests: XCTestCase {
    private let controller = CruiseController()
    private let policy = ChargePolicy(upperLimit: 80, cruiseModeEnabled: true, cruiseDelta: 5)

    func testStopsAtUpperLimit() {
        let result = decide(percentage: 80, previous: .chargingToUpperLimit)
        XCTAssertEqual(result.action, .disableCharging)
        XCTAssertEqual(result.phase, .limitReached)
    }

    func testDoesNotMicroChargeInsideCruiseRange() {
        let result = decide(percentage: 77, previous: nil)
        XCTAssertEqual(result.action, .disableCharging)
        XCTAssertEqual(result.phase, .holdingInCruiseRange)
    }

    func testStartsChargingAtLowerLimit() {
        let result = decide(percentage: 75, previous: .holdingInCruiseRange)
        XCTAssertEqual(result.action, .enableCharging)
        XCTAssertEqual(result.phase, .chargingToUpperLimit)
    }

    func testContinuesChargingAcrossCruiseRangeOnceStarted() {
        let result = decide(percentage: 77, previous: .chargingToUpperLimit)
        XCTAssertEqual(result.action, .enableCharging)
        XCTAssertEqual(result.phase, .chargingToUpperLimit)
    }

    func testDoesNothingWhenUnplugged() {
        let snapshot = BatterySnapshot(
            percentage: 70,
            isConnectedToPower: false,
            isCharging: false
        )
        let result = controller.decide(snapshot: snapshot, policy: policy, previousPhase: nil)
        XCTAssertEqual(result.action, .noChange)
        XCTAssertEqual(result.phase, .unplugged)
    }

    func testCruiseDisabledChargesBelowUpperLimit() {
        let plainPolicy = ChargePolicy(upperLimit: 80, cruiseModeEnabled: false, cruiseDelta: 5)
        let snapshot = BatterySnapshot(
            percentage: 77,
            isConnectedToPower: true,
            isCharging: false
        )
        let result = controller.decide(snapshot: snapshot, policy: plainPolicy, previousPhase: nil)
        XCTAssertEqual(result.action, .enableCharging)
    }

    func testOneHundredPercentTargetIgnoresCruiseBand() {
        let fullPolicy = ChargePolicy(upperLimit: 100, cruiseModeEnabled: true, cruiseDelta: 5)
        let snapshot = BatterySnapshot(
            percentage: 98,
            isConnectedToPower: true,
            isCharging: false
        )
        let result = controller.decide(snapshot: snapshot, policy: fullPolicy, previousPhase: nil)
        XCTAssertEqual(result.action, .enableCharging)
        XCTAssertEqual(result.phase, .chargingToUpperLimit)
    }

    private func decide(percentage: Int, previous: CruisePhase?) -> ChargeDecision {
        let snapshot = BatterySnapshot(
            percentage: percentage,
            isConnectedToPower: true,
            isCharging: false
        )
        return controller.decide(snapshot: snapshot, policy: policy, previousPhase: previous)
    }
}
