import Foundation

struct GPUInfo: Codable {
    let index: Int
    let name: String
    let temperature: Int
    let memoryUsed: Int
    let memoryTotal: Int
    let utilization: Int

    var memoryUsagePercent: Int {
        guard memoryTotal > 0 else { return 0 }
        return (memoryUsed * 100) / memoryTotal
    }

    func isIdle(threshold: IdleThreshold) -> Bool {
        if let memoryUsagePercent = threshold.memoryUsagePercent {
            return self.memoryUsagePercent < memoryUsagePercent
        }

        let underUtilization = threshold.utilization.map { utilization < $0 } ?? true
        let underMemory = threshold.memoryMB.map { memoryUsed < $0 } ?? true
        return underUtilization && underMemory
    }

    var memoryUsedGB: Double {
        Double(memoryUsed) / 1024.0
    }

    var memoryTotalGB: Double {
        Double(memoryTotal) / 1024.0
    }

    func statusEmoji(threshold: IdleThreshold) -> String {
        isIdle(threshold: threshold) ? "🟢" : "🔴"
    }

    func displayString(threshold: IdleThreshold) -> String {
        """
        GPU \(index): \(name) [\(isIdle(threshold: threshold) ? "空闲" : "使用中")] \(statusEmoji(threshold: threshold))
          显存: \(String(format: "%.1f", memoryUsedGB))GB / \(String(format: "%.1f", memoryTotalGB))GB (\(memoryUsagePercent)%)
          温度: \(temperature)°C
          利用率: \(utilization)%
        """
    }
}

struct ServerStatus {
    let name: String
    let host: String
    let port: Int
    let username: String
    let gpus: [GPUInfo]
    let lastUpdate: Date
    let isReachable: Bool
    let errorMessage: String?
    let idleThreshold: IdleThreshold

    var allIdle: Bool {
        !gpus.isEmpty && gpus.allSatisfy { $0.isIdle(threshold: idleThreshold) }
    }

    var anyIdle: Bool {
        gpus.contains { $0.isIdle(threshold: idleThreshold) }
    }

    var statusEmoji: String {
        if !isReachable {
            return "⚪"
        }
        if allIdle {
            return "🟢"
        }
        if anyIdle {
            return "🟡"
        }
        return "🔴"
    }

    var displayString: String {
        if !isReachable {
            return "\(statusEmoji) \(name) (\(host)) - 离线\n  错误: \(errorMessage ?? "未知错误")"
        }

        let gpuStrings = gpus.map { $0.displayString(threshold: idleThreshold) }.joined(separator: "\n")
        return "\(statusEmoji) \(name) (\(host))\n\(gpuStrings)"
    }
}

struct ServerConfig: Codable {
    let name: String
    let host: String
    let port: Int
    let username: String
    let authMethod: String
    let keyPath: String?
    let password: String?

    enum CodingKeys: String, CodingKey {
        case name, host, port, username
        case authMethod = "auth_method"
        case keyPath = "key_path"
        case password
    }
}

struct AppConfig: Codable {
    let refreshInterval: Int
    let servers: [ServerConfig]
    let idleThreshold: IdleThreshold

    enum CodingKeys: String, CodingKey {
        case refreshInterval = "refresh_interval"
        case servers
        case idleThreshold = "idle_threshold"
    }
}

struct IdleThreshold: Codable, Sendable {
    let memoryUsagePercent: Int?
    let utilization: Int?
    let memoryMB: Int?

    static let `default` = IdleThreshold(memoryUsagePercent: 10, utilization: nil, memoryMB: nil)

    init(memoryUsagePercent: Int?, utilization: Int?, memoryMB: Int?) {
        self.memoryUsagePercent = memoryUsagePercent
        self.utilization = utilization
        self.memoryMB = memoryMB
    }

    init(from decoder: Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        if let percent = try? singleValueContainer.decode(Int.self) {
            self.init(memoryUsagePercent: percent, utilization: nil, memoryMB: nil)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            memoryUsagePercent: nil,
            utilization: try container.decodeIfPresent(Int.self, forKey: .utilization),
            memoryMB: try container.decodeIfPresent(Int.self, forKey: .memoryMB)
        )
    }

    func encode(to encoder: Encoder) throws {
        if let memoryUsagePercent {
            var container = encoder.singleValueContainer()
            try container.encode(memoryUsagePercent)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(utilization, forKey: .utilization)
        try container.encodeIfPresent(memoryMB, forKey: .memoryMB)
    }

    enum CodingKeys: String, CodingKey {
        case utilization
        case memoryMB = "memory_mb"
    }
}
