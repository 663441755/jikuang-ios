import Foundation
import UIKit
import CoreMotion
import AVFoundation

enum CheckStatus: Equatable {
    case pending, running, pass, warn, fail, manual

    var label: String {
        switch self {
        case .pending: return "待检"
        case .running: return "检测中"
        case .pass: return "通过"
        case .warn: return "注意"
        case .fail: return "异常"
        case .manual: return "交互"
        }
    }

    var isResolved: Bool {
        switch self {
        case .pending, .running: return false
        default: return true
        }
    }

    var countsAsPass: Bool {
        if case .pass = self { return true }
        return false
    }
}

enum CheckKind {
    case screen, touch
    case gyro, accel, magnet, baro, proximity
    case speaker, mic, haptic
    case camera
    case battery, thermal
}

struct CheckItem: Identifiable {
    let id = UUID()
    var group: String
    var name: String
    var symbol: String
    var kind: CheckKind
    var status: CheckStatus = .pending
    var detail: String = ""
    var manual: Bool = false
}

struct CheckResult {
    var status: CheckStatus
    var detail: String
}

final class DetectEngine: ObservableObject {

    @Published var items: [CheckItem] = []
    @Published var running = false
    @Published var finished = false
    @Published var score: Int = 0
    @Published var currentIndex: Int = 0

    private var stepIndex = 0

    init() {
        items = Self.defaultItems()
    }

    static func defaultItems() -> [CheckItem] {
        [
            CheckItem(group: "屏幕", name: "坏点与漏光", symbol: "rectangle.inset.filled", kind: .screen, manual: true),
            CheckItem(group: "屏幕", name: "多点触控", symbol: "hand.tap", kind: .touch, manual: true),

            CheckItem(group: "传感器", name: "陀螺仪", symbol: "gyroscope", kind: .gyro),
            CheckItem(group: "传感器", name: "加速度计", symbol: "accelerometer", kind: .accel),
            CheckItem(group: "传感器", name: "磁力计", symbol: "dot.radiowaves.left.and.right", kind: .magnet),
            CheckItem(group: "传感器", name: "气压计", symbol: "gauge.medium", kind: .baro),
            CheckItem(group: "传感器", name: "距离感应", symbol: "wave.3.right", kind: .proximity),

            CheckItem(group: "音频与马达", name: "扬声器", symbol: "speaker.wave.3.fill", kind: .speaker, manual: true),
            CheckItem(group: "音频与马达", name: "麦克风", symbol: "mic.fill", kind: .mic),
            CheckItem(group: "音频与马达", name: "触感马达", symbol: "waveform.path", kind: .haptic, manual: true),

            CheckItem(group: "影像", name: "摄像头", symbol: "camera.fill", kind: .camera),

            CheckItem(group: "电池与系统", name: "电池状态", symbol: "battery.75", kind: .battery),
            CheckItem(group: "电池与系统", name: "热管理", symbol: "thermometer.medium", kind: .thermal)
        ]
    }

    // MARK: - 检测流程

    func runAll() {
        guard !running else { return }
        running = true
        finished = false
        score = 0
        stepIndex = 0
        currentIndex = 0
        for i in items.indices {
            items[i].status = .pending
            items[i].detail = ""
        }
        step()
    }

    private func step() {
        guard stepIndex < items.count else {
            running = false
            finished = true
            computeScore()
            return
        }

        let i = stepIndex
        currentIndex = i
        items[i].status = .running

        let item = items[i]

        if item.manual {
            // 交互项：标记为待用户操作，不计入自动评分
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self else { return }
                self.items[i].status = .manual
                self.items[i].detail = "需手动测试"
                self.stepIndex += 1
                self.step()
            }
            return
        }

        let snapshot = item
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let result = Self.evaluate(snapshot)
            DispatchQueue.main.async {
                guard let self else { return }
                self.items[i].status = result.status
                self.items[i].detail = result.detail
                self.stepIndex += 1
                self.step()
            }
        }
    }

    private func computeScore() {
        let auto = items.filter { $0.status != .manual }
        guard !auto.isEmpty else { score = 0; return }
        let pass = auto.filter { $0.status == .pass }.count
        let warn = auto.filter { $0.status == .warn }.count
        let total = Double(auto.count)
        let raw = (Double(pass) + Double(warn) * 0.6) / total
        score = Int((raw * 100).rounded())
        if score < 0 { score = 0 }
    }

    // MARK: - 单项真实检测

    static func evaluate(_ item: CheckItem) -> CheckResult {
        switch item.kind {

        case .gyro:
            let m = CMMotionManager()
            let available = m.isGyroAvailable
            m.stopGyroUpdates()
            return available
                ? CheckResult(status: .pass, detail: "三轴陀螺仪可用")
                : CheckResult(status: .fail, detail: "未检测到陀螺仪")

        case .accel:
            let m = CMMotionManager()
            let available = m.isAccelerometerAvailable
            m.stopAccelerometerUpdates()
            return available
                ? CheckResult(status: .pass, detail: "三轴加速度计可用")
                : CheckResult(status: .fail, detail: "未检测到加速度计")

        case .magnet:
            let m = CMMotionManager()
            let available = m.isMagnetometerAvailable
            m.stopMagnetometerUpdates()
            return available
                ? CheckResult(status: .pass, detail: "三轴磁力计可用")
                : CheckResult(status: .warn, detail: "本机无磁力计")

        case .baro:
            let available = CMAltimeter.isRelativeAltitudeAvailable()
            return available
                ? CheckResult(status: .pass, detail: "气压高度计可用")
                : CheckResult(status: .warn, detail: "本机无气压计")

        case .proximity:
            let device = UIDevice.current
            let previous = device.isProximityMonitoringEnabled
            device.isProximityMonitoringEnabled = true
            let available = device.isProximityMonitoringEnabled
            device.isProximityMonitoringEnabled = previous
            return available
                ? CheckResult(status: .pass, detail: "距离传感器已就绪")
                : CheckResult(status: .warn, detail: "距离传感器不可用")

        case .mic:
            let session = AVAudioSession.sharedInstance()
            let hasInput = session.isInputAvailable
            let channels = session.maximumInputNumberOfChannels
            return hasInput
                ? CheckResult(status: .pass, detail: "输入通道 \(channels) 路可用")
                : CheckResult(status: .warn, detail: "未检测到音频输入")

        case .camera:
            var names: [String] = []
            let types: [AVCaptureDevice.DeviceType] = [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInTrueDepthCamera
            ]
            for position in [AVCaptureDevice.Position.back, .front] {
                let discovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: types,
                    mediaType: .video,
                    position: position
                )
                names.append(contentsOf: discovery.devices.map { $0.localizedName })
            }
            if names.isEmpty {
                return CheckResult(status: .fail, detail: "未枚举到摄像头")
            }
            let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
            let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            var parts: [String] = []
            if back { parts.append("后置正常") }
            if front { parts.append("前置正常") }
            let detail = parts.isEmpty ? "发现 \(names.count) 枚镜头" : parts.joined(separator: " · ")
            return CheckResult(status: .pass, detail: detail)

        case .battery:
            let snap = PowerSource.snapshot()
            guard snap.level > 0 else {
                return CheckResult(status: .warn, detail: "电量读数不可用")
            }
            let percent = PowerSource.percent(snap.level)
            let state: String
            if snap.isFull {
                state = "已充满"
            } else if snap.isCharging {
                state = "充电中"
            } else if snap.pluggedIn {
                state = "已连电源"
            } else {
                state = "放电中"
            }
            let status: CheckStatus = snap.level < 0.15 && !snap.isCharging ? .warn : .pass
            return CheckResult(status: status, detail: "\(percent)% · \(state)")

        case .thermal:
            switch ProcessInfo.processInfo.thermalState {
            case .nominal:
                return CheckResult(status: .pass, detail: "散热正常")
            case .fair:
                return CheckResult(status: .warn, detail: "机身偏热，建议降温")
            case .serious:
                return CheckResult(status: .warn, detail: "温度较高，性能可能受限")
            case .critical:
                return CheckResult(status: .fail, detail: "过热，系统已降频")
            @unknown default:
                return CheckResult(status: .pass, detail: "散热正常")
            }

        case .screen, .touch, .speaker, .haptic:
            return CheckResult(status: .manual, detail: "需手动测试")
        }
    }
}
