import Foundation
import ActivityKit
#if !JIKUANG_WIDGET
import UIKit
#endif

// MARK: - 实时活动属性（App 与 Widget 扩展共用）

/// 充电实时活动：灵动岛（紧凑 / 展开 / 最小）+ 锁屏横幅
struct ChargeActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        var percent: Int        // 电量百分比
        var isCharging: Bool
        var powerText: String   // 充电功率文本，如 "45.2 W"
        var etaDate: Date?      // 预计充满时刻，锁屏用 Text(timerInterval:) 自动倒计时
    }

    var deviceName: String
}

// MARK: - App 侧管理器（仅主 App 编译）

#if !JIKUANG_WIDGET

/// 实时活动生命周期管理：
/// - 检测到充电 → 自动开启灵动岛
/// - 电量每变 1% 或每 30 秒 → 更新功率与倒计时
/// - 拔电 / 充满 → 结束（灵动岛停留 60 秒后自动消失）
final class ChargeActivityManager {

    static let shared = ChargeActivityManager()

    private var activity: Activity<ChargeActivityAttributes>?
    private var lastPercent = -1
    private var lastUpdate = Date.distantPast

    private var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// 由 ChargeEstimator 每秒调用一次；内部自动去抖
    func sync(percent: Int, isCharging: Bool, power: Double, minutesToFull: Int?, full: Bool) {

        // 非充电 / 已充满 → 结束
        if !isCharging || full || percent >= 100 {
            end()
            return
        }

        guard enabled else { return }

        let powerText = power > 0.5 ? String(format: "%.1f W", power) : "采样中"
        let eta: Date? = minutesToFull.map { Date().addingTimeInterval(TimeInterval($0) * 60) }
        let state = ChargeActivityAttributes.ContentState(
            percent: percent, isCharging: true, powerText: powerText, etaDate: eta
        )

        if let activity {
            // 电量变了立即更新；否则每 30 秒刷新一次功率数字
            guard percent != lastPercent || Date().timeIntervalSince(lastUpdate) > 30 else { return }
            lastPercent = percent
            lastUpdate = Date()
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            // 首次开启
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

    /// 结束实时活动（保留 60 秒展示最终状态后自动移除）
    func end() {
        guard let activity else { return }
        self.activity = nil
        lastPercent = -1

        let snap = PowerSource.snapshot()
        let state = ChargeActivityAttributes.ContentState(
            percent: PowerSource.percent(snap.level),
            isCharging: false,
            powerText: "-",
            etaDate: nil
        )
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(60))
            )
        }
    }
}

#endif
