import Foundation
import UIKit
import Darwin

/// 系统指标采集：CPU / 内存 / 存储 / 网络 / 电池 / 温度估算
/// 全部为公开 API，不使用私有方法
final class SystemMetrics: ObservableObject {

    // MARK: - 输出

    @Published var cpuUsage: Double = 0            // 0...1
    @Published var perCore: [Double] = []
    @Published var memUsed: UInt64 = 0
    @Published var memTotal: UInt64 = 0
    @Published var memApp: UInt64 = 0
    @Published var diskUsed: UInt64 = 0
    @Published var diskTotal: UInt64 = 0
    @Published var netDown: Double = 0             // B/s
    @Published var netUp: Double = 0               // B/s
    @Published var batteryLevel: Double = 0        // 0...1
    @Published var batteryPercent: Int = 0         // 整数百分比（1% 精度）
    @Published var isCharging: Bool = false
    @Published var batteryState: String = "未充电"
    @Published var powerMinutesToFull: Int? = nil   // 系统预估的充满剩余分钟
    @Published var thermalText: String = "正常"
    @Published var thermalLevel: Int = 0
    @Published var estimatedTemp: Double = 31.0
    @Published var uptime: TimeInterval = 0
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var netHistory: [Double] = Array(repeating: 0, count: 40)

    @Published var deviceName: String = "iPhone"
    @Published var hardwareModel: String = "iPhone"
    @Published var systemVersion: String = ""
    @Published var coreCount: Int = 0
    @Published var screenInfo: String = ""

    // MARK: - 内部状态

    private var prevTicks: [UInt32] = []
    private var prevNet: (rx: UInt64, tx: UInt64) = (0, 0)
    private var prevTime = Date()
    private var timer: Timer?

    /// 温度估算用：环境温度 + 热惯性
    private var tempState: Double = 31.5
    private let ambientTemp: Double = 25.0
    private let thermalTau: Double = 45.0   // 秒，热惯性时间常数

    // MARK: - 生命周期

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        hardwareModel = Self.machineIdentifier()
        deviceName = UIDevice.current.name
        systemVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        coreCount = ProcessInfo.processInfo.processorCount
        screenInfo = Self.screenDescription()

        refresh()
        _ = readCPUTicks()   // 预热一次，避免首帧 100%
        prevNet = readNetwork()
        prevTime = Date()

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.readBattery()
        }
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.readBattery()
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 刷新

    func refresh() {
        readCPU()
        readMemory()
        readDisk()
        readNetworkSpeed()
        readBattery()
        readThermal()
        uptime = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - CPU

    private func readCPUTicks() -> [UInt32] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )
        guard result == KERN_SUCCESS, let info else { return [] }

        defer {
            _ = vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let stride = Int(CPU_STATE_MAX)
        var ticks: [UInt32] = []
        ticks.reserveCapacity(Int(cpuCount) * stride)
        for i in 0..<Int(cpuCount) {
            for j in 0..<stride {
                ticks.append(UInt32(bitPattern: info[i * stride + j]))
            }
        }
        return ticks
    }

    private func readCPU() {
        let ticks = readCPUTicks()
        guard !ticks.isEmpty else { return }

        if prevTicks.count == ticks.count {
            let stride = Int(CPU_STATE_MAX)
            var totalDelta: Double = 0
            var perCoreDelta: [Double] = []
            var idleTotal: Double = 0

            for c in 0..<(ticks.count / stride) {
                let base = c * stride
                let user = Double(ticks[base + Int(CPU_STATE_USER)] &- prevTicks[base + Int(CPU_STATE_USER)])
                let system = Double(ticks[base + Int(CPU_STATE_SYSTEM)] &- prevTicks[base + Int(CPU_STATE_SYSTEM)])
                let nice = Double(ticks[base + Int(CPU_STATE_NICE)] &- prevTicks[base + Int(CPU_STATE_NICE)])
                let idle = Double(ticks[base + Int(CPU_STATE_IDLE)] &- prevTicks[base + Int(CPU_STATE_IDLE)])
                let busy = user + system + nice
                let all = busy + idle
                perCoreDelta.append(all > 0 ? busy / all : 0)
                totalDelta += busy
                idleTotal += idle
            }

            let overall = (totalDelta + idleTotal) > 0 ? totalDelta / (totalDelta + idleTotal) : 0
            let clamped = min(max(overall, 0), 1)

            // 一阶平滑，避免数字乱跳
            cpuUsage = cpuUsage * 0.45 + clamped * 0.55
            perCore = perCoreDelta

            var h = cpuHistory
            h.removeFirst()
            h.append(cpuUsage)
            cpuHistory = h
        }
        prevTicks = ticks
    }

    // MARK: - 内存

    private func readMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory

        guard kr == KERN_SUCCESS else {
            memTotal = total
            return
        }

        let page = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * page
        let inactive = UInt64(stats.inactive_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let free = UInt64(stats.free_count) * page
        let speculative = UInt64(stats.speculative_count) * page

        var used = active + inactive + wired + compressed
        if used > total { used = total }

        memTotal = total
        memUsed = used
        // App 常驻内存
        memApp = Self.residentMemory()

        _ = free
        _ = speculative
    }

    static func residentMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        return kr == KERN_SUCCESS ? info.resident_size : 0
    }

    // MARK: - 存储

    private func readDisk() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) else {
            return
        }
        let total = UInt64(values.volumeTotalCapacity ?? 0)
        let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        diskTotal = total
        diskUsed = total > free ? total - free : 0
    }

    // MARK: - 网络

    private func readNetwork() -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(first) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = cursor {
            let family = cur.pointee.ifa_addr?.pointee.sa_family
            if family == UInt8(AF_LINK), let data = cur.pointee.ifa_data {
                let d = data.assumingMemoryBound(to: if_data.self).pointee
                rx &+= UInt64(d.ifi_ibytes)
                tx &+= UInt64(d.ifi_obytes)
            }
            cursor = cur.pointee.ifa_next
        }
        return (rx, tx)
    }

    private func readNetworkSpeed() {
        let now = Date()
        let current = readNetwork()
        let dt = now.timeIntervalSince(prevTime)

        if dt > 0.2, current.rx >= prevNet.rx, current.tx >= prevNet.tx {
            let down = Double(current.rx - prevNet.rx) / dt
            let up = Double(current.tx - prevNet.tx) / dt
            netDown = netDown * 0.35 + down * 0.65
            netUp = netUp * 0.35 + up * 0.65

            var h = netHistory
            h.removeFirst()
            h.append(netDown)
            netHistory = h
        }

        prevNet = current
        prevTime = now
    }

    // MARK: - 电池

    private func readBattery() {
        let snap = PowerSource.snapshot()
        batteryLevel = snap.level
        isCharging = snap.isCharging
        batteryPercent = PowerSource.percent(snap.level)

        if snap.isFull {
            batteryState = "已充满"
        } else if snap.isCharging {
            batteryState = "充电中"
        } else if snap.pluggedIn {
            batteryState = "已连电源"
        } else {
            batteryState = "使用中"
        }
        powerMinutesToFull = snap.minutesToFull
    }

    // MARK: - 温度估算（一阶热模型）

    private func readThermal() {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            thermalLevel = 0
            thermalText = "正常"
        case .fair:
            thermalLevel = 1
            thermalText = "偏热"
        case .serious:
            thermalLevel = 2
            thermalText = "较热"
        case .critical:
            thermalLevel = 3
            thermalText = "过热"
        @unknown default:
            thermalLevel = 0
            thermalText = "正常"
        }

        // 目标温度由当前负载决定，再按热惯性逼近
        let load = cpuUsage
        let target = ambientTemp + 24.0 * load
        let dt = 1.0
        tempState += (target - tempState) * (dt / thermalTau)

        // 充电额外发热
        if isCharging { tempState += 0.04 }

        // 系统热状态作为下界修正
        let lowerBound = ambientTemp + Double(thermalLevel) * 5.0
        if tempState < lowerBound { tempState = lowerBound }

        // 合理区间约束
        tempState = min(max(tempState, ambientTemp + 3), 52)
        estimatedTemp = (tempState * 10).rounded() / 10
    }

    // MARK: - 设备信息

    static func machineIdentifier() -> String {
        DeviceInfo.machineIdentifier()
    }

    static func screenDescription() -> String {
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let w = Int(bounds.width * scale)
        let h = Int(bounds.height * scale)
        return "\(max(w, h)) × \(min(w, h))"
    }
}

// MARK: - 格式化工具

enum Fmt {
    static func bytes(_ value: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = value
        var i = 0
        while v >= 1024 && i < units.count - 1 {
            v /= 1024
            i += 1
        }
        return String(format: v >= 100 ? "%.0f %@" : "%.1f %@", v, units[i])
    }

    static func bytes(_ value: UInt64) -> String {
        bytes(Double(value))
    }

    static func speed(_ value: Double) -> String {
        if value < 1024 { return String(format: "%.0f B/s", value) }
        if value < 1024 * 1024 { return String(format: "%.1f KB/s", value / 1024) }
        return String(format: "%.1f MB/s", value / 1024 / 1024)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let d = s / 86400
        let h = (s % 86400) / 3600
        let m = (s % 3600) / 60
        if d > 0 { return "\(d)天 \(h)小时" }
        if h > 0 { return "\(h)小时 \(m)分" }
        if m > 0 { return "\(m)分钟" }
        return "\(max(s, 1))秒"
    }

    static func percent(_ value: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f%%", value * 100)
    }
}
