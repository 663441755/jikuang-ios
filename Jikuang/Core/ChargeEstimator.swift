import Foundation
import UIKit
import Darwin

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

    // MARK: - 心电图数据（充电页主视图）

    /// 滚动波形缓冲：约 4.3 秒 @ 16Hz，负值向下、正值向上
    /// （窗口取 4 秒级：一屏 4~6 个心跳，与真实监护仪观感一致）
    @Published var ecg: [Double] = []
    /// 由功率映射出的显示节律（视觉用，非真实心率）
    @Published var bpm: Int = 58
    /// 预计充满的分钟数；nil = 无数据 / 已充满
    @Published var fullMinutes: Int? = nil
    private var ecgPhase: Double = 0
    private let ecgCapacity = 72
    private let ecgStep: Double = 0.06
    private var ecgTimer: Timer?

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

        // 心电图需要比 1Hz 更高的采样率，单独一条 16Hz 定时器
        ecg = Array(repeating: 0, count: ecgCapacity)
        let et = Timer(timeInterval: ecgStep, repeats: true) { [weak self] _ in
            self?.ecgTick()
        }
        RunLoop.main.add(et, forMode: .common)
        ecgTimer = et
    }

    deinit {
        timer?.invalidate()
        ecgTimer?.invalidate()
    }

    // MARK: - 心电图

    /// 推进一个采样点。
    /// 波形本身是按心电复合波（P-QRS-T）合成的可视化，
    /// 但**振幅与节律由真实功率驱动**——功率越高波峰越高、跳动越快。
    /// iOS 无法读取真实电生理数据，这里只借用心电图的视觉语言表达功率。
    private func ecgTick() {
        let ratio = min(max(power / 45.0, 0), 1)
        let amp = isCharging ? (0.30 + 0.70 * ratio) : 0.09
        // 节律控制在 66~96：配合 4.3 秒窗口，一屏 4~6 个心跳
        let targetBPM = isCharging ? 66.0 + 30.0 * ratio : 58.0
        bpm = Int(targetBPM.rounded())

        // 相位按当前节律推进；period 越短跳得越快
        let period = 60.0 / max(targetBPM, 30)
        ecgPhase += ecgStep / period
        if ecgPhase >= 1 { ecgPhase -= 1 }

        var v = ecgWave(ecgPhase) * amp
        // 基线噪声：非充电时抖动更明显，像导联未接
        v += Double.random(in: -1...1) * (isCharging ? 0.006 : 0.020)

        var arr = ecg
        arr.append(v)
        if arr.count > ecgCapacity {
            arr.removeFirst(arr.count - ecgCapacity)
        }
        ecg = arr
    }

    /// 单周期心电复合波，p ∈ [0,1)
    private func ecgWave(_ p: Double) -> Double {
        let pr = (p - 0.150) / 0.030   // P 波
        let qr = (p - 0.252) / 0.009   // Q
        let rr = (p - 0.272) / 0.011   // R 主峰
        let sr = (p - 0.294) / 0.013   // S
        let tr = (p - 0.430) / 0.050   // T 波

        var v = 0.0
        v += 0.13 * exp(-pr * pr)
        v -= 0.10 * exp(-qr * qr)
        v += 1.00 * exp(-rr * rr)
        v -= 0.26 * exp(-sr * sr)
        v += 0.26 * exp(-tr * tr)
        return v
    }

    // MARK: - 电压 / 电流推断

    /// 充电电压档位推断（PD 协商电压在充电芯片内，iOS 不对外提供）
    var voltageEstimate: Double {
        guard isCharging, power >= 0.5 else { return 0 }
        switch power {
        case ..<12:  return 5.0
        case ..<18:  return 9.0
        case ..<28:  return 15.0
        default:     return 20.0
        }
    }

    /// 电流 = 功率 ÷ 推断电压
    var currentEstimate: Double {
        guard voltageEstimate > 0 else { return 0 }
        return power / voltageEstimate
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
            fullMinutes = nil
            return
        }

        if level >= 0.995 {
            fullEstimate = "已充满"
            fullFromSystem = systemMinutesToFull != nil
            fullMinutes = 0
            return
        }

        // 优先用系统自己的充满预估（1 分钟级刷新，比推算准）
        if let minutes = systemMinutesToFull, minutes > 0 {
            fullEstimate = Fmt.duration(Double(minutes) * 60)
            fullFromSystem = true
            fullMinutes = minutes
            return
        }

        fullFromSystem = false
        guard power > 0.5, level > 0.02 else {
            fullEstimate = "--"
            fullMinutes = nil
            return
        }

        // 两段式 CC-CV 估算：80% 前近似恒流（当前功率），
        // 80% 后进入涓流，平均速率按当前约 30% 计。
        // 之前单段恒功率模型会严重低估（65% 时报 10 分钟，实际约 25 分钟）。
        let batteryW = max(power * efficiency, 0.5)

        var hours: Double = 0
        if level < 0.80 {
            hours += (0.80 - level) * batteryWh / batteryW
        }
        if level < 0.995 {
            // 涓流段：80→100% 固定按当前速率的 30% 摊
            hours += 0.20 * batteryWh / max(batteryW * 0.30, 0.15)
        }
        let minutes = Int(hours * 60)

        if minutes >= 60 {
            fullEstimate = "\(minutes / 60) 小时 \(minutes % 60) 分"
        } else {
            fullEstimate = "\(max(minutes, 1)) 分钟"
        }
        fullMinutes = max(minutes, 1)
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
        // 重置心电波形，新会话从头画起
        ecgPhase = 0
        ecg = Array(repeating: 0, count: ecgCapacity)
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
