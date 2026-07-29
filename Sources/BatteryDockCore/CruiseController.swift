import Foundation

public struct ChargePolicy: Codable, Equatable, Sendable {
    public var upperLimit: Int
    public var cruiseModeEnabled: Bool
    public var cruiseDelta: Int

    public init(upperLimit: Int = 80, cruiseModeEnabled: Bool = true, cruiseDelta: Int = 5) {
        self.upperLimit = min(max(upperLimit, 20), 100)
        self.cruiseModeEnabled = cruiseModeEnabled
        self.cruiseDelta = min(max(cruiseDelta, 1), 20)
    }

    public var lowerLimit: Int {
        max(5, upperLimit - cruiseDelta)
    }
}

public enum ChargeAction: String, Equatable, Sendable {
    case enableCharging
    case disableCharging
    case noChange
}

public enum CruisePhase: String, Equatable, Sendable {
    case unplugged
    case chargingToUpperLimit
    case holdingInCruiseRange
    case limitReached
}

public struct ChargeDecision: Equatable, Sendable {
    public let action: ChargeAction
    public let phase: CruisePhase
    public let explanation: String

    public init(action: ChargeAction, phase: CruisePhase, explanation: String) {
        self.action = action
        self.phase = phase
        self.explanation = explanation
    }
}

/// A deterministic hysteresis controller. It never actively discharges the battery.
public struct CruiseController: Sendable {
    public init() {}

    public func decide(
        snapshot: BatterySnapshot,
        policy: ChargePolicy,
        previousPhase: CruisePhase?
    ) -> ChargeDecision {
        guard snapshot.isConnectedToPower else {
            return ChargeDecision(
                action: .noChange,
                phase: .unplugged,
                explanation: "未连接电源"
            )
        }

        // A 100% target means the limiter is disabled. Cruise hysteresis must not
        // pause charging inside 95%–100%, otherwise "充满" would stop too early.
        if policy.upperLimit == 100, snapshot.percentage < 100 {
            return ChargeDecision(
                action: .enableCharging,
                phase: .chargingToUpperLimit,
                explanation: "正在充满至 100%，完成后请手动恢复原上限"
            )
        }

        if snapshot.percentage >= policy.upperLimit {
            return ChargeDecision(
                action: .disableCharging,
                phase: .limitReached,
                explanation: "已达到上限 \(policy.upperLimit)%"
            )
        }

        guard policy.cruiseModeEnabled else {
            return ChargeDecision(
                action: .enableCharging,
                phase: .chargingToUpperLimit,
                explanation: "正在充至 \(policy.upperLimit)%"
            )
        }

        if snapshot.percentage <= policy.lowerLimit {
            return ChargeDecision(
                action: .enableCharging,
                phase: .chargingToUpperLimit,
                explanation: "已到巡航下限，充至 \(policy.upperLimit)%"
            )
        }

        if previousPhase == .chargingToUpperLimit {
            return ChargeDecision(
                action: .enableCharging,
                phase: .chargingToUpperLimit,
                explanation: "巡航补电中，继续充至 \(policy.upperLimit)%"
            )
        }

        return ChargeDecision(
            action: .disableCharging,
            phase: .holdingInCruiseRange,
            explanation: "处于巡航区间 \(policy.lowerLimit)%–\(policy.upperLimit)%"
        )
    }
}
