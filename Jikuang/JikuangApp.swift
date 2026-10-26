import SwiftUI

@main
struct JikuangApp: App {
    @StateObject private var metrics = SystemMetrics()
    @StateObject private var charge = ChargeEstimator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(metrics)
                .environmentObject(charge)
                .modifier(ActivityBridge())
                .preferredColorScheme(.dark)
                .tint(Theme.amber)
        }
    }
}

/// 把 SystemMetrics / ChargeEstimator 的实时数据桥接给灵动岛实时活动
///
/// 每秒触发一次，由 ChargeActivityManager 内部按指标节流
/// （网速 5 秒 / 其它 20 秒 / 电量变化立即），避免超出 iOS 更新预算。
struct ActivityBridge: ViewModifier {

    @EnvironmentObject private var metrics: SystemMetrics
    @EnvironmentObject private var charge: ChargeEstimator

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content.onReceive(ticker) { _ in
            let memRatio = metrics.memTotal > 0
                ? Double(metrics.memUsed) / Double(metrics.memTotal)
                : 0

            ChargeActivityManager.shared.sync(
                percent: charge.batteryPercent,
                isCharging: charge.isCharging,
                power: charge.power,
                minutesToFull: charge.systemMinutesToFull,
                full: charge.batteryPercent >= 100,
                cpu: metrics.cpuUsage,
                memRatio: memRatio,
                thermal: metrics.estimatedTemp,
                netDown: metrics.netDown,
                netUp: metrics.netUp
            )
        }
    }
}
