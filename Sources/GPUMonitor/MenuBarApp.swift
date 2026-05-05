import Cocoa
import Foundation

class MenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var monitor: MultiServerMonitor?
    private var appConfig: AppConfig?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("=== GPU Monitor 启动 ===")
        DispatchQueue.main.async {
            self.setupMenuBar()
            self.loadConfiguration()
            self.startMonitoring()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⚪ GPU"
            NSLog("按钮标题已设置")
        }

        menu = NSMenu()
        statusItem.menu = menu
        NSLog("菜单栏设置完成")
    }

    private func loadConfiguration() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gpu_monitor/config.json")

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            createDefaultConfig(at: configPath)
            return
        }

        do {
            let data = try Data(contentsOf: configPath)
            appConfig = try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            print("配置文件加载失败: \(error)")
            showError("配置文件加载失败: \(error.localizedDescription)")
        }
    }

    private func createDefaultConfig(at path: URL) {
        let defaultConfig = """
        {
          "refresh_interval": 30,
          "idle_threshold": 10,
          "servers": [
            {
              "name": "GPU Server 1",
              "host": "192.168.1.100",
              "port": 22,
              "username": "root",
              "auth_method": "key",
              "key_path": "~/.ssh/id_rsa",
              "password": null
            }
          ]
        }
        """

        do {
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try defaultConfig.write(to: path, atomically: true, encoding: .utf8)
            showError("已创建默认配置文件，请编辑: \(path.path)")
        } catch {
            print("创建配置文件失败: \(error)")
        }
    }

    private func startMonitoring() {
        guard let config = appConfig else { return }

        monitor = MultiServerMonitor(
            configs: config.servers,
            refreshInterval: TimeInterval(config.refreshInterval),
            idleThreshold: config.idleThreshold
        )

        monitor?.onStatusUpdate = { [weak self] statuses in
            Task { @MainActor in
                self?.updateMenu(with: statuses)
            }
        }

        monitor?.startMonitoring()
    }

    private func updateMenu(with statuses: [ServerStatus]) {
        menu.removeAllItems()

        let overallStatus = getOverallStatus(statuses)
        if let button = statusItem.button {
            button.title = "\(overallStatus) GPU"
        }

        for status in statuses {
            let serverItem = NSMenuItem(title: "\(status.statusEmoji) \(status.name) (\(status.host))", action: nil, keyEquivalent: "")
            serverItem.isEnabled = false
            menu.addItem(serverItem)

            if status.isReachable {
                for gpu in status.gpus {
                    let isIdle = gpu.isIdle(threshold: status.idleThreshold)
                    let gpuTitle = "  GPU \(gpu.index): \(gpu.name) [\(isIdle ? "空闲" : "使用中")] \(gpu.statusEmoji(threshold: status.idleThreshold))"
                    let gpuItem = NSMenuItem(title: gpuTitle, action: nil, keyEquivalent: "")
                    gpuItem.isEnabled = false
                    menu.addItem(gpuItem)

                    let memoryInfo = NSMenuItem(
                        title: "    显存: \(String(format: "%.1f", gpu.memoryUsedGB))GB / \(String(format: "%.1f", gpu.memoryTotalGB))GB (\(gpu.memoryUsagePercent)%)",
                        action: nil,
                        keyEquivalent: ""
                    )
                    memoryInfo.isEnabled = false
                    menu.addItem(memoryInfo)

                    let tempInfo = NSMenuItem(
                        title: "    温度: \(gpu.temperature)°C  利用率: \(gpu.utilization)%",
                        action: nil,
                        keyEquivalent: ""
                    )
                    tempInfo.isEnabled = false
                    menu.addItem(tempInfo)
                }

                let connectItem = NSMenuItem(
                    title: "  → 连接到此服务器",
                    action: nil,
                    keyEquivalent: ""
                )
                connectItem.isEnabled = false
                menu.addItem(connectItem)

                // Terminal 连接
                let terminalItem = NSMenuItem(
                    title: "    • 在 Terminal 中打开",
                    action: #selector(connectToServerInTerminal(_:)),
                    keyEquivalent: ""
                )
                terminalItem.representedObject = status
                terminalItem.target = self
                menu.addItem(terminalItem)

                // VSCode 连接
                let vscodeItem = NSMenuItem(
                    title: "    • 在 VSCode 中打开",
                    action: #selector(connectToServerInVSCode(_:)),
                    keyEquivalent: ""
                )
                vscodeItem.representedObject = status
                vscodeItem.target = self
                menu.addItem(vscodeItem)
            } else {
                let errorItem = NSMenuItem(
                    title: "  错误: \(status.errorMessage ?? "未知错误")",
                    action: nil,
                    keyEquivalent: ""
                )
                errorItem.isEnabled = false
                menu.addItem(errorItem)
            }

            menu.addItem(NSMenuItem.separator())
        }

        let refreshItem = NSMenuItem(title: "刷新", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let configItem = NSMenuItem(title: "打开配置文件", action: #selector(openConfig), keyEquivalent: ",")
        configItem.target = self
        menu.addItem(configItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func getOverallStatus(_ statuses: [ServerStatus]) -> String {
        let reachableStatuses = statuses.filter { $0.isReachable }

        if reachableStatuses.isEmpty {
            return "⚪"
        }

        if reachableStatuses.allSatisfy({ $0.allIdle }) {
            return "🟢"
        }

        if reachableStatuses.contains(where: { $0.anyIdle }) {
            return "🟡"
        }

        return "🔴"
    }

    @objc private func connectToServerInTerminal(_ sender: NSMenuItem) {
        guard let status = sender.representedObject as? ServerStatus else { return }

        // 使用 Terminal 打开 SSH 连接
        let sshCommand = "ssh -p \(status.port) \(status.username)@\(status.host)"
        let script = "tell application \"Terminal\" to do script \"\(sshCommand)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
        } catch {
            showError("无法打开 Terminal: \(error.localizedDescription)")
        }
    }

    @objc private func connectToServerInVSCode(_ sender: NSMenuItem) {
        guard let status = sender.representedObject as? ServerStatus else { return }

        // 使用 VSCode 打开 SSH 连接
        let sshTarget = "ssh-remote+\(status.username)@\(status.host):\(status.port)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Visual Studio Code", "--args", "--folder-uri", "vscode-remote://\(sshTarget)/root"]

        do {
            try process.run()
        } catch {
            showError("无法打开 VSCode: \(error.localizedDescription)")
        }
    }

    @objc private func refreshNow() {
        Task {
            await monitor?.checkAllServers()
        }
    }

    @objc private func openConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gpu_monitor/config.json")

        NSWorkspace.shared.open(configPath)
    }

    @objc private func quit() {
        monitor?.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "GPU Monitor"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
