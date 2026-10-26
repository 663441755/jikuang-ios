import Foundation
import UIKit
import IOKit.ps

/// 电源状态快照
struct PowerSnapshot {
    var level: Double = 0           // 0...1，1% 精度
    var isCharging: Bool = false
    var isFull: Bool = false
    var pluggedIn: Bool = false
    var minutesToFull: Int? = nil   // 系统预估的充满剩余分钟
    var source: String = "-"
}

/// 电源信息读取
///
/// 为什么不直接用 UIDevice.batteryLevel：
/// 该属性的精度是 5% 量化（真机 48% 会返回 0.50），显示上会差好几个点。
/// IOKit 的 Power Sources 接口能拿到 1% 精度的真实容量，还能拿到系统自己的
/// 充满时间预估，是这里的主数据源；UIDevice 仅在 IOKit 不可用时兜底。
enum PowerSource {

    static func read() -> PowerSnapshot? {
        guard let infoRef = IOPSCopyPowerSourcesInfo() else { return nil }
        let blob = infoRef.takeRetainedValue()

        guard let listRef = IOPSCopyPowerSourcesList(blob) else { return nil }
        let listRaw = listRef.takeRetainedValue()
        guard let list = (listRaw as NSArray) as? [AnyObject] else { return nil }

        for item in list {
            guard let descRef = IOPSGetPowerSourceDescription(blob, item) else { continue }
            guard let desc = (descRef.takeUnretainedValue() as NSDictionary) as? [String: Any] else { continue }

            // 键名为 IOKit Power Sources 的标准字符串，直接用字面量避免 CFString 桥接差异
            let current = desc["Current Capacity"] as? Int ?? -1
            let maxCap = desc["Max Capacity"] as? Int ?? 100
            guard maxCap > 0, current >= 0 else { continue }

            var snap = PowerSnapshot()
            snap.level = min(max(Double(current) / Double(maxCap), 0), 1)
            snap.isCharging = desc["Is Charging"] as? Bool ?? false
            snap.isFull = desc["Is Charged"] as? Bool ?? false
            snap.pluggedIn = (desc["Power Source State"] as? String) == "AC Power"

            if let t = desc["Time to Full Charge"] as? Int, t > 0 {
                snap.minutesToFull = t
            }
            snap.source = "IOKit"
            return snap
        }
        return nil
    }

    /// UIDevice 兜底（5% 量化）
    static func fallback() -> PowerSnapshot {
        UIDevice.current.isBatteryMonitoringEnabled = true

        var snap = PowerSnapshot()
        let level = UIDevice.current.batteryLevel
        snap.level = level < 0 ? 0 : Double(level)

        switch UIDevice.current.batteryState {
        case .charging:
            snap.isCharging = true
            snap.pluggedIn = true
        case .full:
            snap.isCharging = true
            snap.isFull = true
            snap.pluggedIn = true
        case .unplugged:
            break
        default:
            break
        }
        snap.source = "UIDevice"
        return snap
    }

    static func snapshot() -> PowerSnapshot {
        read() ?? fallback()
    }

    /// 四舍五入到整数百分比，避免 0.29 × 100 = 28.999 被截成 28
    static func percent(_ level: Double) -> Int {
        Int((level * 100).rounded())
    }
}
