import Foundation
import ActivityKit
import AppIntents
#if !JIKUANG_WIDGET
import UIKit
#endif

// MARK: - 灵动岛显示的指标类型

enum MetricKind: String, Codable, CaseIterable {
    case net      // 实时网速
    case cpu      // CPU 占用
    case mem      // 内存占用
    case thermal  // 机身温度

    var label: String {
        switch self {
        case .net:     return "实时网速"
        case .cpu:     return "CPU 占用"
        case .mem:     return "内存占用"
        case .thermal: return "机身温度"
        }
    }

    var icon: String {
        switch self {
        case .net:     return "wifi"
        case .cpu:     return "cpu"
        case .mem:     return "memorychip"
        case .thermal: return "thermometer.medium"
        }
    }

    var shortLabel: String {
        switch self {
        case .net:     return "网速"
        case .cpu:     return "CPU"
        case .mem:     return "内存"
        case .thermal: return "温度"
        }
    }

    /// 下一个指标（循环）
    var next: MetricKind {
        let all = MetricKind.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

// MARK: - 实时活动属性（App 与 Widget 扩展共用）

/// 充电实时活动：灵动岛（紧凑 / 展开 / 最小）+ 锁屏横幅
/// 四项指标（网速 / CPU / 内存 / 温度）全部预置在 ContentState 里，
/// 切换时只改 metric 字段，不用重新采集，点击响应是即时的。
struct ChargeActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        var percent: Int            // 电量百分比
        var isCharging: Bool
        var powerText: String       // 充电功率文本，如 "45.2 W"
        var etaDate: Date?          // 预计充满时刻，用 Text(timerInterval:) 自动倒计时

        var metric: MetricKind = .net

        // 四项指标的显示文本
        var netText: String = "--"       // 下行速度（紧凑短格式）
        var netUpText: String = "--"     // 上行速度
        var cpuText: String = "--"
        var memText: String = "--"
        var thermalText: String = "--"

        /// 当前指标对应的主显示值
        var valueText: String {
            switch metric {
            case .net:     return netText
            case .cpu:     return cpuText
            case .mem:     return memText
            case .thermal: return thermalText
            }
        }

        /// 当前指标的副行说明
        var detailText: String {
            switch metric {
            case .net:     return "↑ \(netUpText)"
            case .cpu:     return "全核平均"
            case .mem:     return "占用比例"
            case .thermal: return "估算值"
            }
        }
    }

    var deviceName: String
}

// MARK: - 兼容旧版本遗留的活动数据

extension ChargeActivityAttributes.ContentState {

    /// 手写解码：旧版本（1.0.6 及以前）存活的实时活动没有 metric / 四项文本字段，
    /// 用合成解码会因缺 key 抛错，导致扩展或 App 读取活动内容时崩溃。
    /// 这里全部按 decodeIfPresent + 兜底值处理，任何历史数据都能安全降级。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
        isCharging = try c.decodeIfPresent(Bool.self, forKey: .isCharging) ?? false
        powerText = try c.decodeIfPresent(String.self, forKey: .powerText) ?? "--"
        etaDate = try c.decodeIfPresent(Date.self, forKey: .etaDate)
        metric = (try? c.decode(MetricKind.self, forKey: .metric)) ?? .net
        netText = try c.decodeIfPresent(String.self, forKey: .netText) ?? "--"
        netUpText = try c.decodeIfPresent(String.self, forKey: .netUpText) ?? "--"
        cpuText = try c.decodeIfPresent(String.self, forKey: .cpuText) ?? "--"
        memText = try c.decodeIfPresent(String.self, forKey: .memText) ?? "--"
        thermalText = try c.decodeIfPresent(String.self, forKey: .thermalText) ?? "--"
    }
}

// MARK: - 切换指标按钮（灵动岛展开后点击）

/// LiveActivityIntent 在 App 进程内执行，可直接更新实时活动内容，
/// 同时把选择写入 UserDefaults，后续自动刷新沿用用户选中的指标。
struct CycleMetricIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "切换指标"
    static var description = IntentDescription("在网速 / CPU / 内存 / 温度之间切换灵动岛显示")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let activity = Activity<ChargeActivityAttributes>.activities.first else {
            return .result()
        }

        var state = activity.content.state
        state.metric = state.metric.next
        UserDefaults.standard.set(state.metric.rawValue, forKey: "jikuang.activity.metric")

        await activity.update(ActivityContent(state: state, staleDate: nil))
        return .result()
    }
}

// MARK: - App 侧管理器（仅主 App 编译）

#if !JIKUANG_WIDGET

/// 实时活动生命周期管理：
/// - 检测到充电 → 自动开启灵动岛
/// - 电量变 1%、网速指标 5 秒、其他指标 20 秒 → 刷新内容
/// - 拔电 / 充满 → 结束（灵动岛停留 60 秒后自动消失）
final class ChargeActivityManager {

    static let shared = ChargeActivityManager()
    static let metricKey = "jikuang.activity.metric"

    private var activity: Activity<ChargeActivityAttributes>?
    private var lastPercent = -1
    private var lastUpdate = Date.distantPast
    private var didCleanupStale = false

    private var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// 当前用户选择的指标（持久化，重启 App 后保持）
    private var currentMetric: MetricKind {
        MetricKind(rawValue: UserDefaults.standard.string(forKey: Self.metricKey) ?? "") ?? .net
    }

    /// 由 ActivityBridge 每秒调用一次；内部按指标节流更新
    func sync(percent: Int,
              isCharging: Bool,
              power: Double,
              minutesToFull: Int?,
              full: Bool,
              cpu: Double,
              memRatio: Double,
              thermal: Double,
              netDown: Double,
              netUp: Double) {

        // 非充电 / 已充满 → 结束
        if !isCharging || full || percent >= 100 {
            end()
            return
        }

        guard enabled else { return }

        let powerText = power > 0.5 ? String(format: "%.1f W", power) : "采样中"
        let eta: Date? = minutesToFull.map { Date().addingTimeInterval(TimeInterval($0) * 60) }
        let metric = currentMetric

        let state = ChargeActivityAttributes.ContentState(
            percent: percent,
            isCharging: true,
            powerText: powerText,
            etaDate: eta,
            metric: metric,
            netText: compactSpeed(netDown),
            netUpText: compactSpeed(netUp),
            cpuText: String(format: "%.0f%%", min(max(cpu, 0), 1) * 100),
            memText: String(format: "%.0f%%", min(max(memRatio, 0), 1) * 100),
            thermalText: String(format: "%.1f℃", thermal)
        )

        // App 重启 / 升级后引用丢失：接管进程内已有的活动，避免重复创建两个灵动岛
        if activity == nil {
            activity = Activity<ChargeActivityAttributes>.activities.first
        }

        if let activity {
            // 网速要更跟手：5 秒一刷；其余指标 20 秒一刷；电量变化立即刷
            let interval: TimeInterval = metric == .net ? 5 : 20
            guard percent != lastPercent || Date().timeIntervalSince(lastUpdate) > interval else { return }
            lastPercent = percent
            lastUpdate = Date()
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            lastPercent = percent
            lastUpdate = Date()
            let attr = ChargeActivityAttributes(deviceName: UIDevice.current.name)
            activity = try? Activity.request(
                attributes: attr,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        }
    }

    /// 紧凑模式用的短格式：1.2M / 320K / 84B
    private func compactSpeed(_ value: Double) -> String {
        if value < 1024 { return String(format: "%.0fB", value) }
        if value < 1024 * 1024 { return String(format: "%.0fK", value / 1024) }
        if value < 1024 * 1024 * 1024 { return String(format: "%.1fM", value / 1024 / 1024) }
        return String(format: "%.1fG", value / 1024 / 1024 / 1024)
    }

    /// 结束实时活动（保留 60 秒展示最终状态后自动移除）
    func end() {
        // 优先结束自己持有的活动；否则清理一次进程内残留活动
        // （升级前遗留 / App 重启后引用丢失的情况），只清一次避免每秒重复调用
        var target: Activity<ChargeActivityAttributes>?
        if let activity {
            target = activity
        } else if !didCleanupStale {
            didCleanupStale = true
            target = Activity<ChargeActivityAttributes>.activities.first
        }

        guard let target else { return }
        activity = nil
        lastPercent = -1

        let snap = PowerSource.snapshot()
        let state = ChargeActivityAttributes.ContentState(
            percent: PowerSource.percent(snap.level),
            isCharging: false,
            powerText: "-",
            etaDate: nil,
            metric: currentMetric
        )
        Task {
            await target.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(60))
            )
        }
    }
}

#endif
