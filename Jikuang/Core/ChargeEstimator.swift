import Foundation
import UIKit

/// 充电功率估算器
///
/// iOS 不提供任何充电功率的公开读数，因此这里采用业界通行的推算方式：
/// 以电量百分比变化量（ΔSoC）乘以电池额定能量（Wh），除以时间差得到电池侧功率，
/// 再除以充电链路效率修正，得到充电器侧功率。
/// 结果标注为「估算值」，与 App Store 同类产品做法一致。
///
/// 电量来源为 IOKit（1% 精度），不是 UIDevice.batteryLevel（5% 量化）。
final class ChargeEstimator: ObservableObject {

    struct Record: Identifiable, Codable {
        var id = UUID()
        var date: Date
        var startLevel: Double
        var endLevel: Double
        var peakPower: Double
        var wattHours: Double
        var duration: TimeInterval
    }

    // MARK: - 输出

    @Published var power: Double = 0          // 充电器侧功率 W
    @Published var batteryPower: Double = 0   // 电池侧功率 W
    @Published var level: Double = 0          // 0...1
    @Published var batteryPercent: Int = 0    // 整数百分比
    @Published var isCharging = false
    @Published var peakPower: Double = 0
    @Published var sessionWh: Double = 0
    @Published var sessionStart: Date?
    @Published var elapsed: TimeInterval = 0
    @Published var fullEstimate: String = "--"
    @Published var fullFromSystem = false     // true = 用的是系统给的充满时间
    @Published var systemMinutesToFull: Int? = nil
    @Published var samples: [Double] = []     // 本次会话逐段功率
    @Published var records: [Record] = []
    @Published var measuring = false
    @Published var historyPower: [Double] = Array(repeating: 0, count: 40)
    @Published var sourceLabel: String = "-"   // 电量数据源，用于排错

    // MARK: - 参数

    /// 电池额定能量（Wh）。按机型族分档，用于换算功率。
    private lazy var batteryWh: Double = {
        let model = SystemMetrics.machineIdentifier()
        if model.contains("17,") || model.contains("18,") || model.contains("19,") || model.contains("20,") { return 19.5 }
        if model.contains("15,") || model.contains("16,") { return 17.1 }
        if model.contains("14,") || model.contains("13,") { return 14.2 }
        return 16.0
    }()

    /// 充电链路效率（充电器 → 电池）
    private let efficiency: Double = 0.87

    // MARK: - 内部状态

    private struct LevelSample {
        let level: Double
        let at: Date
    }

    private var levelSamples: [LevelSample] = []
    private var lastLevel: Double = -1
    private var timer: Timer?
    private var lastChargingState = false
    private var pendingIntervals: [Double] = []   // 最近的功率区间值
    private var lastTick = Date()
    private var startLevelForSession: Double = 0

    private let defaultsKey = "jikuang.charge.records"

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        loadRecords()

        let snap = PowerSource.snapshot()
        level = snap.level
        batteryPercent = PowerSource.percent(snap.level)
        lastLevel = snap.level
        isCharging = snap.isCharging
        lastChargingState = snap.isCharging
        systemMinutesToFull = snap.minutesToFull
        sourceLabel = snap.precise ? "1% 精度" : "5% 量化"

        if isCharging { startSession() }

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 采样

    private func tick() {
        let now = Date()
        // 后台回到前台时 dt 会很大，钳住避免能量一次性暴增
        let dt = min(max(now.timeIntervalSince(lastTick), 0.2), 5.0)
        lastTick = now

        let snap = PowerSource.snapshot()
        level = snap.level
        batteryPercent = PowerSource.percent(snap.level)
        systemMinutesToFull = snap.minutesToFull
        sourceLabel = snap.precise ? "1% 精度" : "5% 量化"

        let currentCharging = snap.isCharging
        if currentCharging != lastChargingState {
            if currentCharging { startSession() } else { endSession() }
            lastChargingState = currentCharging
        }
        isCharging = currentCharging

        guard isCharging else {
            if power > 0 {
                // 拔出后动量衰减
                power = max(power * 0.7 - 0.6, 0)
                if power < 0.2 { power = 0 }
            }
            batteryPower = 0
            measuring = false
            updateFullEstimate()
            return
        }

        if let start = sessionStart {
            elapsed = now.timeIntervalSince(start)
        }

        // 电量为 0 时无法测量
        guard level > 0 else {
            measuring = true
            updateFullEstimate()
            return
        }

        // 电量每变化 1% 记录一个样本（IOKit 为 1% 精度）
        if abs(level - lastLevel) >= 0.005 {
            levelSamples.append(LevelSample(level: level, at: now))
            lastLevel = level
            recomputePower()
        } else if levelSamples.isEmpty {
            levelSamples.append(LevelSample(level: level, at: now))
            if power == 0 { measuring = true }
        }

        if levelSamples.count > 20 {
            levelSamples.removeFirst(levelSamples.count - 20)
        }

        // 能量按当前功率连续积分：数字每秒都在走，而不是等下一次电量跳变
        if power > 0 {
            sessionWh += max(batteryPower, 0) * dt / 3600.0
        }

        updateFullEstimate()
    }

    private func recomputePower() {
        guard levelSamples.count >= 2 else {
            measuring = true
            return
        }

        // 用最近 3 个电量变化区间求平均功率，抑制抖动
        var energies: [Double] = []
        var durations: [Double] = []

        let tail = Array(levelSamples.suffix(4))
        for i in 1..<tail.count {
            let dLevel = tail[i].level - tail[i - 1].level
            let dt = tail[i].at.timeIntervalSince(tail[i - 1].at)
            guard dLevel > 0, dt > 1 else { continue }
            energies.append(dLevel * batteryWh)
            durations.append(dt / 3600.0)
        }

        guard !energies.isEmpty else {
            if power == 0 { measuring = true }
            return
        }

        let wh = energies.reduce(0, +)
        let hours = durations.reduce(0, +)
        guard hours > 0 else { return }

        let batteryW = wh / hours
        // 合理区间约束：有线最高 45W，最低 0.5W
        let chargerW = min(max(batteryW / efficiency, 0.5), 45)

        pendingIntervals.append(chargerW)
        if pendingIntervals.count > 4 { pendingIntervals.removeFirst() }
        let avg = pendingIntervals.reduce(0, +) / Double(pendingIntervals.count)

        batteryPower = avg * efficiency
        // 首次直接采用，之后轻平滑，避免电量跳 1% 时数字大幅弹跳
        power = power == 0 ? avg : power * 0.4 + avg * 0.6
        measuring = false

        if power > peakPower { peakPower = power }

        samples.append((power * 10).rounded() / 10)
        if samples.count > 30 { samples.removeFirst() }

        var h = historyPower
        h.removeFirst()
        h.append(power)
        historyPower = h
    }

    private func updateFullEstimate() {
        guard isCharging else {
            fullEstimate = level >= 0.99 ? "已充满" : "--"
            fullFromSystem = false
            return
        }

        if level >= 0.995 {
            fullEstimate = "已充满"
            fullFromSystem = systemMinutesToFull != nil
            return
        }

        // 优先用系统自己的充满预估（1 分钟级刷新，比推算准）
        if let minutes = systemMinutesToFull, minutes > 0 {
            fullEstimate = Fmt.duration(Double(minutes) * 60)
            fullFromSystem = true
            return
        }

        fullFromSystem = false
        guard power > 0.5, level > 0.02 else {
            fullEstimate = "--"
            return
        }

        let remainWh = (1.0 - level) * batteryWh
        let remainBatteryW = max(power * efficiency, 0.5)
        let hours = remainWh / remainBatteryW
        let minutes = Int(hours * 60)

        if minutes >= 60 {
            fullEstimate = "\(minutes / 60) 小时 \(minutes % 60) 分"
        } else {
            fullEstimate = "\(max(minutes, 1)) 分钟"
        }
    }

    // MARK: - 充电协议推断

    /// iOS 没有公开接口读取充电器协商协议（PD/QC 档位），
    /// 这里按实测功率落到常见协议档位。iPhone 16 Pro Max 起支持
    /// PD 3.1 AVS（可调电压 20mV 步进），45W 档即由 AVS 协商而来。
    var protocolLabel: String {
        if !isCharging { return "未接入电源" }
        if measuring && power < 0.5 { return "采样中" }

        switch power {
        case ..<0.5:    return "待采样"
        case ..<7.5:    return "慢速充电 · 5V1A"
        case ..<12:     return "常规充电 · 5V2.4A"
        case ..<18:     return "PD 快充 · SPR 9V 档"
        case ..<22:     return "PD 快充 · SPR 20W 档"
        case ..<28:     return "PD 快充 · SPR 30W 档"
        case ..<34:     return "PD 3.0 · 高功率档"
        default:        return "PD 3.1 AVS · EPR 高功率档"
        }
    }

    // MARK: - 会话

    private func startSession() {
        isCharging = true
        sessionStart = Date()
        peakPower = 0
        sessionWh = 0
        samples = []
        pendingIntervals = []
        levelSamples = [LevelSample(level: level, at: Date())]
        lastLevel = level
        startLevelForSession = level
        lastTick = Date()
        measuring = true
    }

    private func endSession() {
        isCharging = false
        guard let start = sessionStart, level > startLevelForSession else {
            sessionStart = nil
            return
        }
        let record = Record(
            date: start,
            startLevel: startLevelForSession,
            endLevel: level,
            peakPower: peakPower,
            wattHours: sessionWh,
            duration: Date().timeIntervalSince(start)
        )
        records.insert(record, at: 0)
        if records.count > 30 { records.removeLast() }
        saveRecords()
        sessionStart = nil
    }

    // MARK: - 持久化

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([Record].self, from: data) else { return }
        records = decoded
    }

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    // MARK: - 额定功率档位

    /// iPhone 常见充电档位，用于柱状图刻度
    static let powerTiers: [Double] = [5, 7.5, 12, 15, 18, 20, 25, 27, 30, 35, 45]
}
