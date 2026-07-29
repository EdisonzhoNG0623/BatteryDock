import Foundation

public enum ChargeBackendError: LocalizedError, Sendable {
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        }
    }
}

public protocol ChargeControlling: Sendable {
    var displayName: String { get }
    var isAvailable: Bool { get }
    func synchronize(policy: ChargePolicy) throws
}

/// Safe default until a signed privileged helper has been installed.
public struct MonitorOnlyChargeBackend: ChargeControlling {
    public let displayName = "监控模式"
    public let isAvailable = false

    public init() {}

    public func synchronize(policy: ChargePolicy) throws {
        throw ChargeBackendError.unavailable("尚未安装 BatteryDock 充电控制 Helper")
    }
}

/// Uses a separately installed, open-source `batt` daemon as the privileged boundary.
/// BatteryDock never invokes sudo or handles an administrator password.
public struct ExternalBattChargeBackend: ChargeControlling {
    public let executableURL: URL
    public let displayName = "batt 开源控制服务"
    public let isAvailable = true

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }

    public static func detect(fileManager: FileManager = .default) -> ExternalBattChargeBackend? {
        let candidates = [
            "/opt/homebrew/bin/batt",
            "/usr/local/bin/batt",
            "/usr/local/sbin/batt",
        ]
        guard let path = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        return ExternalBattChargeBackend(executableURL: URL(fileURLWithPath: path))
    }

    public func synchronize(policy: ChargePolicy) throws {
        _ = try run(["limit", String(policy.upperLimit)])
        let delta = policy.cruiseModeEnabled ? policy.cruiseDelta : 1
        _ = try run(["lower-limit-delta", String(delta)])
    }

    @discardableResult
    private func run(_ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()

        let standardOutput = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "batt 控制服务调用失败"
            throw ChargeBackendError.unavailable(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: standardOutput, encoding: .utf8) ?? ""
    }
}
