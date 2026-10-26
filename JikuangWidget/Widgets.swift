import WidgetKit
import SwiftUI

// MARK: - 数据

struct BatteryEntry: TimelineEntry {
    let date: Date
    let percent: Int
    let charging: Bool
    let state: String
    let tempText: String
    let storageText: String
}

struct BatteryProvider: TimelineProvider {

    func placeholder(in context: Context) -> BatteryEntry { makeEntry() }
    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        completion(makeEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        // WidgetKit 最低刷新约 15 分钟，取 20 分钟一个周期；
        // App 前台运行时会在电量变化时主动 reload，实时性由 App 补足
        let next = Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date().addingTimeInterval(1200)
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }

    private func makeEntry() -> BatteryEntry {
        let snap = PowerSource.snapshot()

        let tempText: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: tempText = "正常"
        case .fair: tempText = "偏热"
        case .serious: tempText = "较热"
        case .critical: tempText = "过热"
        @unknown default: tempText = "正常"
        }

        let storageText: String = {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            guard let vals = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) else { return "--" }
            let total = Int64(vals.volumeTotalCapacity ?? 0)
            let free = vals.volumeAvailableCapacityForImportantUsage ?? 0
            guard total > 0, total > free else { return "--" }
            return String(format: "%.0f GB", Double(total - free) / 1e9)
        }()

        let state = snap.isFull ? "已充满" : (snap.isCharging ? "充电中" : "使用中")
        return BatteryEntry(
            date: Date(),
            percent: PowerSource.percent(snap.level),
            charging: snap.isCharging,
            state: state,
            tempText: tempText,
            storageText: storageText
        )
    }
}

// MARK: - 主屏 · 圆环

struct GaugeWidgetView: View {
    var entry: BatteryEntry

    var tint: Color { entry.charging ? Color(red: 1.0, green: 0.72, blue: 0.30) : Color(red: 0.35, green: 0.83, blue: 0.60) }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(0.02, Double(entry.percent) / 100))
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(entry.percent)")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 78, height: 78)

            Text(entry.state)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .containerBackground(for: .widget) { Color(white: 0.08) }
    }
}

// MARK: - 主屏 · 中号

struct MediumWidgetView: View {
    var entry: BatteryEntry

    var tint: Color { entry.charging ? Color(red: 1.0, green: 0.72, blue: 0.30) : Color(red: 0.35, green: 0.83, blue: 0.60) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.02, Double(entry.percent) / 100))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(entry.percent)")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 7) {
                row(symbol: "bolt.fill", label: "状态", value: entry.state, tint: tint)
                row(symbol: "thermometer.medium", label: "热状态", value: entry.tempText, tint: .orange)
                row(symbol: "internaldrive.fill", label: "可用存储", value: entry.storageText, tint: .cyan)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .containerBackground(for: .widget) { Color(white: 0.08) }
    }

    private func row(symbol: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundColor(tint)
                .frame(width: 13)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - 锁屏

struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BatteryEntry

    var tint: Color { entry.charging ? Color(red: 1.0, green: 0.72, blue: 0.30) : Color(red: 0.35, green: 0.83, blue: 0.60) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.02, Double(entry.percent) / 100))
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(entry.percent)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            .containerBackground(for: .widget) { ClearView() }

        case .accessoryInline:
            Text("机况 \(entry.percent)% · \(entry.state)")
                .containerBackground(for: .widget) { ClearView() }

        default:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.charging ? "bolt.fill" : "iphone.gen3")
                        .font(.system(size: 10))
                        .foregroundColor(tint)
                    Text("机况")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text("\(entry.percent)% · \(entry.state)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("热 \(entry.tempText) · 存 \(entry.storageText)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .containerBackground(for: .widget) { ClearView() }
        }
    }
}

struct ClearView: View {
    var body: some View {
        Color.clear
    }
}

// MARK: - 注册

struct GaugeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "jikuang.gauge", provider: BatteryProvider()) { entry in
            GaugeWidgetView(entry: entry)
        }
        .configurationDisplayName("电量仪表")
        .description("实时电量与充电状态")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "jikuang.medium", provider: BatteryProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("机况概览")
        .description("电量、热状态与可用存储")
        .supportedFamilies([.systemMedium])
    }
}

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "jikuang.lock", provider: BatteryProvider()) { entry in
            LockWidgetView(entry: entry)
        }
        .configurationDisplayName("锁屏电量")
        .description("锁屏上的机况速览")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

@main
struct JikuangWidgetBundle: WidgetBundle {
    var body: some Widget {
        GaugeWidget()
        MediumWidget()
        LockWidget()
    }
}
