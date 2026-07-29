import Foundation

public enum BatteryProbeError: LocalizedError, Sendable {
    case commandFailed(String)
    case unrecognizedOutput

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message): return message
        case .unrecognizedOutput: return "无法识别 macOS 电池信息"
        }
    }
}

public protocol BatteryProbing: Sendable {
    func read() throws -> BatterySnapshot
}

public struct SystemBatteryProbe: BatteryProbing {
    public init() {}

    public func read() throws -> BatterySnapshot {
        let power = try run("/usr/bin/pmset", arguments: ["-g", "batt"])
        guard let percentage = firstInteger(matching: #"(\d+)%"#, in: power) else {
            throw BatteryProbeError.unrecognizedOutput
        }

        let lowerPower = power.lowercased()
        let connected = lowerPower.contains("ac power")
        let charging = lowerPower.contains("; charging;") || lowerPower.contains("finishing charge")

        let registry = (try? run(
            "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "AppleSmartBattery", "-l"]
        )) ?? ""

        let rawTemperature = firstInteger(matching: #"\"Temperature\" = (\d+)"#, in: registry)
        let temperature = rawTemperature.map { Double($0) / 100.0 - 273.15 }
        let cycles = firstInteger(matching: #"\"CycleCount\" = (\d+)"#, in: registry)
        let rawMax = firstInteger(matching: #"\"AppleRawMaxCapacity\" = (\d+)"#, in: registry)
        let design = firstInteger(matching: #"\"DesignCapacity\" = (\d+)"#, in: registry)
        let health: Int?
        if let rawMax, let design, design > 0 {
            health = Int((Double(rawMax) / Double(design) * 100.0).rounded())
        } else {
            health = nil
        }

        return BatterySnapshot(
            percentage: percentage,
            isConnectedToPower: connected,
            isCharging: charging,
            temperatureCelsius: temperature,
            cycleCount: cycles,
            maximumCapacityPercent: health
        )
    }

    private func run(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "命令执行失败"
            throw BatteryProbeError.commandFailed(message)
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func firstInteger(matching pattern: String, in input: String) -> Int? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: input,
                range: NSRange(input.startIndex..., in: input)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: input)
        else { return nil }
        return Int(input[range])
    }
}
