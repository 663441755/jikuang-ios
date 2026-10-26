import Foundation
import UIKit
import Darwin

/// 电源状态快照
struct PowerSnapshot {
    var level: Double = 0           // 0...1
    var isCharging: Bool = false
    var isFull: Bool = false
    var pluggedIn: Bool = false
    var minutesToFull: Int? = nil   // 系统预估的充满剩余分钟
    var source: String = "-"
    var precise: Bool = false       // true = 1% 精度
}

/// 电源信息读取
///
/// 为什么不用 UIDevice.batteryLevel：
/// 该属性只给出 5% 量化的值（真机 48% 会返回 0.50），页面上就会显示成 50%。
/// 这里优先走 IOKit 的 PowerSources 接口拿 1% 精度的真实容量，
/// 但 iOS SDK 并没有导出 IOKit.ps 模块，所以改为运行时 dlopen + dlsym 取符号，
/// 取不到就平滑回退到 UIDevice，不会崩。
enum PowerSource {

    private typealias FnCopyInfo = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias FnCopyList = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
    private typealias FnGetDesc = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

    private struct API {
        let info: FnCopyInfo
        let list: FnCopyList
        let desc: FnGetDesc
    }

    private static let api: API? = {
        let paths = [
            "/System/Library/Frameworks/IOKit.framework/IOKit",
            "/usr/lib/libIOPSupport.dylib"
        ]
        for path in paths {
            guard let handle = dlopen(path, RTLD_LAZY) else { continue }
            guard let symInfo = dlsym(handle, "IOPSCopyPowerSourcesInfo"),
                  let symList = dlsym(handle, "IOPSCopyPowerSourcesList"),
                  let symDesc = dlsym(handle, "IOPSGetPowerSourceDescription") else { continue }
            return API(
                info: unsafeBitCast(symInfo, to: FnCopyInfo.self),
                list: unsafeBitCast(symList, to: FnCopyList.self),
                desc: unsafeBitCast(symDesc, to: FnGetDesc.self)
            )
        }
        return nil
    }()

    static var supported: Bool { api != nil }

    /// IOKit 电源信息：1% 精度 + 系统充满预估
    static func read() -> PowerSnapshot? {
        guard let api else { return nil }
        guard let infoPtr = api.info() else { return nil }
        // Copy 规则：+1 持有，作用域结束自动释放
        let blob = Unmanaged<AnyObject>.fromOpaque(infoPtr).takeRetainedValue()
        defer { _ = blob }

        guard let listPtr = api.list(infoPtr) else { return nil }
        let listObj = Unmanaged<AnyObject>.fromOpaque(listPtr).takeRetainedValue()
        guard let list = (listObj as? NSArray) as? [AnyObject] else { return nil }

        for item in list {
            let itemPtr = Unmanaged.passUnretained(item).toOpaque()
            guard let descPtr = api.desc(infoPtr, itemPtr) else { continue }
            let descObj = Unmanaged<AnyObject>.fromOpaque(descPtr).takeUnretainedValue()
            guard let dict = descObj as? NSDictionary,
                  let desc = dict as? [String: Any] else { continue }

            // 键名取自 IOKit Power Sources 的标准字典
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
            snap.precise = true
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
        snap.precise = false
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
