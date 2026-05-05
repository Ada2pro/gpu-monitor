import WidgetKit
import SwiftUI
import AppKit

private let serversPerPage = 3

struct GPUWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GPUWidgetEntry {
        GPUWidgetEntry(date: Date(), servers: [], pageIndex: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (GPUWidgetEntry) -> Void) {
        let statuses = SharedDataManager.shared.loadStatuses()
        let pageCount = GPUWidgetProvider.pageCount(for: statuses.count)
        let pageIndex = SharedDataManager.shared.loadPageIndex(pageCount: pageCount)
        let entry = GPUWidgetEntry(date: Date(), servers: statuses, pageIndex: pageIndex)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GPUWidgetEntry>) -> Void) {
        let statuses = SharedDataManager.shared.loadStatuses()
        let pageCount = GPUWidgetProvider.pageCount(for: statuses.count)
        let pageIndex = SharedDataManager.shared.loadPageIndex(pageCount: pageCount)
        let entry = GPUWidgetEntry(date: Date(), servers: statuses, pageIndex: pageIndex)

        let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private static func pageCount(for serverCount: Int) -> Int {
        max(1, Int(ceil(Double(serverCount) / Double(serversPerPage))))
    }
}

struct GPUWidgetEntry: TimelineEntry {
    let date: Date
    let servers: [ServerStatusData]
    let pageIndex: Int
}

struct GPUWidgetEntryView: View {
    var entry: GPUWidgetProvider.Entry
    private var pageCount: Int {
        max(1, Int(ceil(Double(entry.servers.count) / Double(serversPerPage))))
    }

    private var currentPage: Int {
        guard pageCount > 1 else { return 0 }
        return entry.pageIndex
    }

    private var visibleServers: [ServerStatusData] {
        let start = currentPage * serversPerPage
        return Array(entry.servers.dropFirst(start).prefix(serversPerPage))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                Text("GPU 服务器")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.bottom, 4)

            if entry.servers.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ForEach(Array(visibleServers.enumerated()), id: \.offset) { index, server in
                    ServerRowView(server: server)
                    if index < visibleServers.count - 1 { Divider() }
                }

                if pageCount > 1 {
                    if #available(macOS 14.0, *) {
                        PageControlsView(
                            currentPage: currentPage,
                            pageCount: pageCount,
                            serverCount: entry.servers.count
                        )
                    } else {
                        Text("第 \(currentPage + 1)/\(pageCount) 页 · 共 \(entry.servers.count) 台服务器")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack {
                Spacer()
                Text("更新: \(formatTime(entry.date))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .widgetContainerBackground()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

@available(macOS 14.0, *)
private struct PageControlsView: View {
    let currentPage: Int
    let pageCount: Int
    let serverCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Link(destination: URL(string: "gpumonitor://widget/previous")!) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .frame(width: 44, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)

            Text("第 \(currentPage + 1)/\(pageCount) 页 · 共 \(serverCount) 台")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Link(destination: URL(string: "gpumonitor://widget/next")!) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .frame(width: 44, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
    }
}


struct ServerRowView: View {
    let server: ServerStatusData

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(server.host)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            Text(statusText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(statusColor)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.16))
                .cornerRadius(5)
        }
        .frame(height: 30)
    }

    private var statusText: String {
        if !server.isReachable { return "离线" }
        if server.gpuCount <= 0 { return "在线" }
        return "\(server.idleGPUCount)/\(server.gpuCount) 空闲"
    }

    private var statusColor: Color {
        if !server.isReachable {
            return .gray
        }
        if server.idleGPUCount == server.gpuCount {
            return .green
        }
        if server.idleGPUCount > 0 {
            return .orange
        }
        return .red
    }
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(macOS 14.0, *) {
            self.containerBackground(for: .widget) {
                Color(nsColor: .windowBackgroundColor)
            }
        } else {
            self.background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

@main
struct GPUWidget: Widget {
    let kind: String = "GPUWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GPUWidgetProvider()) { entry in
            GPUWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GPU Monitor")
        .description("显示远程 GPU 服务器状态")
        .supportedFamilies([.systemMedium])
    }
}
