import Foundation
import AppIntents
import WidgetKit

// Codable version of ServerStatus for sharing between app and widget
struct ServerStatusData: Codable {
    let name: String
    let host: String
    let isReachable: Bool
    let statusEmoji: String
    let gpuCount: Int
    let idleGPUCount: Int
    let lastUpdate: Date
    let errorMessage: String?
}

final class SharedDataManager: @unchecked Sendable {
    static let shared = SharedDataManager()

    private let appGroupIdentifier = "group.com.gpumonitor.shared"
    private let legacyPreferencesSuiteName = "com.gpumonitor.app"
    private let widgetBundleIdentifier = "com.gpumonitor.app.widget"
    private let statusKey = "serverStatuses"
    private let statusFileName = "server-statuses.json"
    private let pageFileName = "widget-page.txt"

    private init() {}

    private var appGroupStatusFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(statusFileName)
    }

    private var appGroupPageFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(pageFileName)
    }

    private var widgetDocumentsStatusFileURL: URL? {
        widgetDocumentsURL?.appendingPathComponent(statusFileName)
    }

    private var widgetDocumentsPageFileURL: URL? {
        widgetDocumentsURL?.appendingPathComponent(pageFileName)
    }

    private var widgetDocumentsURL: URL? {
        if Bundle.main.bundleIdentifier == widgetBundleIdentifier {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
            .appendingPathComponent(widgetBundleIdentifier)
            .appendingPathComponent("Data/Documents")
    }

    private var writableStatusFileURLs: [URL] {
        [appGroupStatusFileURL, widgetDocumentsStatusFileURL].compactMap { $0 }.uniquePaths()
    }

    private var readableStatusFileURLs: [URL] {
        [widgetDocumentsStatusFileURL, appGroupStatusFileURL].compactMap { $0 }.uniquePaths()
    }

    private var writablePageFileURLs: [URL] {
        [appGroupPageFileURL, widgetDocumentsPageFileURL].compactMap { $0 }.uniquePaths()
    }

    private var readablePageFileURLs: [URL] {
        [widgetDocumentsPageFileURL, appGroupPageFileURL].compactMap { $0 }.uniquePaths()
    }

    private var legacyUserDefaults: UserDefaults? {
        UserDefaults(suiteName: legacyPreferencesSuiteName)
    }

    func saveStatuses(_ statuses: [ServerStatusData]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let encoded = try? encoder.encode(statuses) {
            saveStatusData(encoded)
            print("Saved \(statuses.count) server statuses to shared container")
        }
    }

    func loadStatuses() -> [ServerStatusData] {
        guard let data = loadStatusData() ?? migrateLegacyStatuses() else {
            print("No data found in shared container")
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let statuses = try? decoder.decode([ServerStatusData].self, from: data) {
            print("Loaded \(statuses.count) server statuses from shared container")
            return statuses
        }

        return []
    }

    func loadPageIndex(pageCount: Int) -> Int {
        guard pageCount > 1 else { return 0 }

        for fileURL in readablePageFileURLs {
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8),
                  let pageIndex = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }

            return normalizedPageIndex(pageIndex, pageCount: pageCount)
        }

        return 0
    }

    func advancePage(by delta: Int, pageCount: Int) {
        guard pageCount > 1 else {
            savePageIndex(0)
            return
        }

        let nextPage = normalizedPageIndex(loadPageIndex(pageCount: pageCount) + delta, pageCount: pageCount)
        savePageIndex(nextPage)
    }

    private func savePageIndex(_ pageIndex: Int) {
        let fileURLs = writablePageFileURLs
        guard !fileURLs.isEmpty else { return }

        let data = Data("\(pageIndex)".utf8)
        for fileURL in fileURLs {
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: fileURL, options: .atomic)
            } catch {
                NSLog("Failed to write widget page file %@: %@", fileURL.path, String(describing: error))
            }
        }
    }

    private func normalizedPageIndex(_ pageIndex: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return ((pageIndex % pageCount) + pageCount) % pageCount
    }

    private func saveStatusData(_ data: Data) {
        let fileURLs = writableStatusFileURLs
        guard !fileURLs.isEmpty else {
            NSLog("No shared status file URLs are available")
            return
        }

        for fileURL in fileURLs {
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: fileURL, options: .atomic)
                NSLog("Wrote shared status file: %@", fileURL.path)
            } catch {
                NSLog("Failed to write shared status file %@: %@", fileURL.path, String(describing: error))
            }
        }
    }

    private func loadStatusData() -> Data? {
        for fileURL in readableStatusFileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                NSLog("Read shared status file: %@", fileURL.path)
                return data
            } catch {
                NSLog("Failed to read shared status file %@: %@", fileURL.path, String(describing: error))
            }

        }

        return nil
    }

    private func migrateLegacyStatuses() -> Data? {
        guard let data = legacyUserDefaults?.data(forKey: statusKey) else {
            return nil
        }

        saveStatusData(data)
        print("Migrated server statuses to shared container")
        return data
    }
}

private extension Array where Element == URL {
    func uniquePaths() -> [URL] {
        var seen = Set<String>()
        return filter { url in
            seen.insert(url.standardizedFileURL.path).inserted
        }
    }
}

@available(macOS 14.2, *)
struct PreviousGPUPageIntent: AppIntent {
    static let title: LocalizedStringResource = "上一页"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        updateGPUWidgetPage(by: -1)
        return .result()
    }
}

@available(macOS 14.2, *)
struct NextGPUPageIntent: AppIntent {
    static let title: LocalizedStringResource = "下一页"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        updateGPUWidgetPage(by: 1)
        return .result()
    }
}

@available(macOS 14.2, *)
private func updateGPUWidgetPage(by delta: Int) {
    let statuses = SharedDataManager.shared.loadStatuses()
    let pageCount = max(1, Int(ceil(Double(statuses.count) / 3.0)))
    SharedDataManager.shared.advancePage(by: delta, pageCount: pageCount)
    WidgetCenter.shared.reloadAllTimelines()
}

// Extension to convert ServerStatus to ServerStatusData
extension ServerStatus {
    func toData() -> ServerStatusData {
        ServerStatusData(
            name: name,
            host: host,
            isReachable: isReachable,
            statusEmoji: statusEmoji,
            gpuCount: gpus.count,
            idleGPUCount: gpus.filter { $0.isIdle(threshold: idleThreshold) }.count,
            lastUpdate: lastUpdate,
            errorMessage: errorMessage
        )
    }
}
