import Foundation

public struct BatterySnapshot: Equatable, Sendable {
    public let percentage: Int
    public let isConnectedToPower: Bool
    public let isCharging: Bool
    public let temperatureCelsius: Double?
    public let cycleCount: Int?
    public let maximumCapacityPercent: Int?
    public let timestamp: Date

    public init(
        percentage: Int,
        isConnectedToPower: Bool,
        isCharging: Bool,
        temperatureCelsius: Double? = nil,
        cycleCount: Int? = nil,
        maximumCapacityPercent: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.percentage = min(max(percentage, 0), 100)
        self.isConnectedToPower = isConnectedToPower
        self.isCharging = isCharging
        self.temperatureCelsius = temperatureCelsius
        self.cycleCount = cycleCount
        self.maximumCapacityPercent = maximumCapacityPercent
        self.timestamp = timestamp
    }
}
