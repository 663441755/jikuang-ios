import Foundation
import UIKit

enum DeviceInfo {

    static let names: [String: String] = [
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone 17 Air",
        "iPhone19,1": "iPhone 18 Pro",
        "iPhone19,2": "iPhone 18 Pro Max",
        "iPhone19,3": "iPhone 18",
        "iPhone19,4": "iPhone 18 Air"
    ]

    /// 明确有灵动岛的机型
    private static let islandModels: Set<String> = [
        "iPhone15,2", "iPhone15,3",
        "iPhone15,4", "iPhone15,5",
        "iPhone16,1", "iPhone16,2",
        "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4",
        "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4",
        "iPhone19,1", "iPhone19,2", "iPhone19,3", "iPhone19,4"
    ]

    /// 明确无灵动岛的机型（刘海屏 / SE）
    private static let notchModels: Set<String> = [
        "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8",
        "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4",
        "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5",
        "iPhone14,6", "iPhone14,7", "iPhone14,8",
        "iPhone17,5"
    ]

    static func friendlyName(_ identifier: String) -> String {
        if let name = names[identifier] { return name }
        if identifier.hasPrefix("iPhone") { return "iPhone (\(identifier))" }
        return identifier
    }

    // MARK: - 机型标识

    /// 读 utsname.machine。用原始字节解析，比 Mirror 反射可靠
    static func machineIdentifier() -> String {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return "Unknown" }
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }

    // MARK: - 灵动岛判定

    /// 是否有灵动岛
    ///
    /// 三级判定，逐层兜底：
    /// 1. 机型标识白名单命中
    /// 2. 未知机型 → 用顶部安全区高度（灵动岛机型 ≥ 50pt，刘海屏 44~47pt）
    /// 3. 安全区取不到（布局未完成）→ 用物理分辨率兜底
    static func hasDynamicIsland(_ identifier: String) -> Bool {
        if islandModels.contains(identifier) { return true }
        if notchModels.contains(identifier) { return false }

        let inset = topSafeArea()
        if inset > 0 { return inset >= 50 }

        return nativeScreenHeight() >= 2556
    }

    /// 顶部安全区高度（小组件扩展内无 UIApplication，走不了这条路径）
    static func topSafeArea() -> CGFloat {
        #if JIKUANG_WIDGET
        return 0
        #else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let key = scene.windows.first(where: { $0.isKeyWindow }) {
                return key.safeAreaInsets.top
            }
        }
        for scene in scenes {
            if let window = scene.windows.first {
                return window.safeAreaInsets.top
            }
        }
        return 0
        #endif
    }

    /// 物理像素高度
    static func nativeScreenHeight() -> CGFloat {
        #if JIKUANG_WIDGET
        return 0
        #else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            let bounds = scene.screen.nativeBounds
            if bounds.height > 0 {
                return max(bounds.width, bounds.height)
            }
        }
        let bounds = UIScreen.main.nativeBounds
        return max(bounds.width, bounds.height)
        #endif
    }

    /// 供监控页显示的判定依据
    static func islandDiagnostic(_ identifier: String) -> String {
        let inset = Int(topSafeArea().rounded())
        let height = Int(nativeScreenHeight().rounded())
        return "\(identifier) · 安全区 \(inset)pt · 屏高 \(height)px"
    }
}
