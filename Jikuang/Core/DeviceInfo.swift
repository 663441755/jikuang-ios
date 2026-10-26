import Foundation

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

    static func friendlyName(_ identifier: String) -> String {
        if let name = names[identifier] { return name }
        if identifier.hasPrefix("iPhone") { return "iPhone (\(identifier))" }
        return identifier
    }

    /// 是否有灵动岛（iPhone 14 Pro 及之后 Pro 机型 + 15/16/17/18 全系）
    static func hasDynamicIsland(_ identifier: String) -> Bool {
        let islandModels: Set<String> = [
            "iPhone15,2", "iPhone15,3",
            "iPhone15,4", "iPhone15,5",
            "iPhone16,1", "iPhone16,2",
            "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4",
            "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4",
            "iPhone19,1", "iPhone19,2", "iPhone19,3", "iPhone19,4"
        ]
        return islandModels.contains(identifier)
    }
}
