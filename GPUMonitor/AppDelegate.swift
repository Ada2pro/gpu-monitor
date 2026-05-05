import Cocoa
import WidgetKit

@main
struct GPUMonitorApp {
    @MainActor
    private static var menuBarApp: MenuBarApp?

    static func main() {
        let logMessage = "=== GPUMonitorApp: main 被调用 at \(Date()) ===\n"
        let logPath = "/tmp/gpumonitor_debug.log"
        if let data = logMessage.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }

        print("=== GPUMonitorApp: main 被调用 ===")
        NSLog("=== GPUMonitorApp: main 被调用 ===")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        GPUMonitorURLHandler.shared.register()

        let startMessage = "=== GPUMonitorApp: 即将创建 MenuBarApp ===\n"
        if let data = startMessage.data(using: .utf8),
           let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }

        DispatchQueue.main.async {
            menuBarApp = MenuBarApp()
            menuBarApp?.setupAndStart()
        }

        app.run()
    }
}

final class GPUMonitorURLHandler: NSObject, @unchecked Sendable {
    static let shared = GPUMonitorURLHandler()

    func register() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "gpumonitor",
              url.host == "widget" else {
            return
        }

        let delta: Int
        switch url.path {
        case "/previous":
            delta = -1
        case "/next":
            delta = 1
        default:
            return
        }

        let statuses = SharedDataManager.shared.loadStatuses()
        let pageCount = max(1, Int(ceil(Double(statuses.count) / 3.0)))
        SharedDataManager.shared.advancePage(by: delta, pageCount: pageCount)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarApp: MenuBarApp?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let logMessage = "=== AppDelegate: applicationDidFinishLaunching 被调用 at \(Date()) ===\n"
        let logPath = "/tmp/gpumonitor_debug.log"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }

        print("=== AppDelegate: applicationDidFinishLaunching 被调用 ===")
        NSLog("=== AppDelegate: applicationDidFinishLaunching 被调用 ===")

        // 设置激活策略，确保应用保持运行
        NSApp.setActivationPolicy(.accessory)

        menuBarApp = MenuBarApp()
        print("=== AppDelegate: MenuBarApp 已创建 ===")
        NSLog("=== AppDelegate: MenuBarApp 已创建 ===")

        menuBarApp?.setupAndStart()
        print("=== AppDelegate: setupAndStart 已调用 ===")
        NSLog("=== AppDelegate: setupAndStart 已调用 ===")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
