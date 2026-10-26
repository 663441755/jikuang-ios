import Foundation
import Darwin

/// 网速采样
///
/// 通过 getifaddrs 读取所有网卡（AF_LINK）的累计收发字节，
/// 两次采样的字节差 ÷ 时间差 = 瞬时网速。
/// 每次调用内部自行间隔采样，进程内自洽 —— 小组件扩展与主 App
/// 无需共享存储（App Group），自签安装时也不用额外配置能力。
enum NetSpeed {

    struct Counters {
        var rx: UInt64   // 累计接收字节
        var tx: UInt64   // 累计发送字节
    }

    /// 当前累计字节计数
    static func counters() -> Counters {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return Counters(rx: 0, tx: 0)
        }
        defer { freeifaddrs(first) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = cursor {
            if cur.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = cur.pointee.ifa_data {
                let d = data.assumingMemoryBound(to: if_data.self).pointee
                rx &+= UInt64(d.ifi_ibytes)
                tx &+= UInt64(d.ifi_obytes)
            }
            cursor = cur.pointee.ifa_next
        }
        return Counters(rx: rx, tx: tx)
    }

    /// 瞬时网速（阻塞 gap 秒做两次采样）
    /// 返回值：down = 下行 B/s，up = 上行 B/s
    static func instantSpeed(gap: TimeInterval = 1.2) -> (down: Double, up: Double) {
        let a = counters()
        let t0 = Date()
        Thread.sleep(forTimeInterval: gap)
        let b = counters()
        let dt = Date().timeIntervalSince(t0)

        guard dt > 0.3 else { return (0, 0) }
        let down = b.rx >= a.rx ? Double(b.rx - a.rx) / dt : 0
        let up = b.tx >= a.tx ? Double(b.tx - a.tx) / dt : 0
        return (down, up)
    }

    /// 网速显示格式
    static func format(_ value: Double) -> String {
        if value < 1024 { return String(format: "%.0f B/s", value) }
        if value < 1024 * 1024 { return String(format: "%.1f KB/s", value / 1024) }
        return String(format: "%.1f MB/s", value / 1024 / 1024)
    }
}
