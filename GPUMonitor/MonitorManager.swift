import Foundation

final class GPUMonitorManager: Sendable {
    private let config: ServerConfig
    private let idleThreshold: IdleThreshold

    init(config: ServerConfig, idleThreshold: IdleThreshold = .default) {
        self.config = config
        self.idleThreshold = idleThreshold
    }

    func checkServer() async -> ServerStatus {
        let sshClient = SSHClient(config: config)

        do {
            let gpus = try await sshClient.getGPUInfo()
            return ServerStatus(
                name: config.name,
                host: config.host,
                port: config.port,
                username: config.username,
                gpus: gpus,
                lastUpdate: Date(),
                isReachable: true,
                errorMessage: nil,
                idleThreshold: idleThreshold
            )
        } catch {
            return ServerStatus(
                name: config.name,
                host: config.host,
                port: config.port,
                username: config.username,
                gpus: [],
                lastUpdate: Date(),
                isReachable: false,
                errorMessage: error.localizedDescription,
                idleThreshold: idleThreshold
            )
        }
    }
}

@MainActor
class MultiServerMonitor {
    private var monitors: [GPUMonitorManager] = []
    private var serverStatuses: [ServerStatus] = []
    private var timer: Timer?
    private let refreshInterval: TimeInterval

    var onStatusUpdate: (([ServerStatus]) -> Void)?

    init(configs: [ServerConfig], refreshInterval: TimeInterval = 30, idleThreshold: IdleThreshold = .default) {
        self.monitors = configs.map { GPUMonitorManager(config: $0, idleThreshold: idleThreshold) }
        self.refreshInterval = refreshInterval
    }

    func startMonitoring() {
        Task {
            await checkAllServers()
        }

        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.checkAllServers()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkAllServers() async {
        var statuses: [ServerStatus] = []

        for monitor in monitors {
            let status = await monitor.checkServer()
            statuses.append(status)
        }

        self.serverStatuses = statuses
        self.onStatusUpdate?(statuses)
    }

    func getStatuses() -> [ServerStatus] {
        return serverStatuses
    }
}
