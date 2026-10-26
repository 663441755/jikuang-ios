import SwiftUI
import AVFoundation

struct ToolItem: Identifiable {
    let id = UUID()
    var name: String
    var symbol: String
    var tint: Color
    var pro: Bool = false
    var action: ToolAction = .soon
}

enum ToolAction {
    case detect
    case torch
    case soon
    case haptics
    case touch
    case screen
    case compass
    case gps
    case footprint
    case gyro
    case magnet
    case pressure
    case altitude
    case proximity
    case qr
    case decibel
    case password
}

struct ActiveTool: Identifiable {
    let id: ToolAction
}

struct ToolsView: View {
    @State private var showDetect = false
    @State private var active: ActiveTool?
    @State private var toast: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    PageHeader(title: "工具", subtitle: "20 项 · 16 项可用")

                    GroupLabel(text: "系统")
                    grid(systemTools)

                    GroupLabel(text: "传感器")
                    grid(sensorTools)

                    GroupLabel(text: "网络", badge: "PRO")
                    grid(networkTools)

                    GroupLabel(text: "实用")
                    grid(utilityTools)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.t1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial)
                        .clipShape(Rectangle())
                        .overlay(Rectangle().stroke(Theme.lineStrong, lineWidth: 1))
                        .padding(.bottom, 100)
                        .transition(.opacity)
                }
            }
        }
        .fullScreenCover(isPresented: $showDetect) {
            DetectView()
        }
        .sheet(item: $active) { tool in
            toolContent(tool.id)
        }
    }

    @ViewBuilder
    private func toolContent(_ action: ToolAction) -> some View {
        switch action {
        case .haptics: HapticsToolView()
        case .touch: TouchToolView()
        case .screen: ScreenToolView()
        case .compass: CompassToolView()
        case .gps: GpsToolView()
        case .footprint: FootprintToolView()
        case .gyro: GyroToolView()
        case .magnet: MagnetToolView()
        case .pressure: PressureToolView()
        case .altitude: AltitudeToolView()
        case .proximity: ProximityToolView()
        case .qr: QRToolView()
        case .decibel: DecibelToolView()
        case .password: PasswordToolView()
        default: DetectView()
        }
    }

    // MARK: - 网格

    private func grid(_ items: [ToolItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items) { item in
                Button {
                    handle(item)
                } label: {
                    ToolCell(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handle(_ item: ToolItem) {
        switch item.action {
        case .detect:
            showDetect = true
        case .torch:
            toggleTorch()
        case .soon:
            withAnimation(.easeOut(duration: 0.2)) {
                toast = "\(item.name) · PRO 版功能"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeIn(duration: 0.25)) {
                    toast = nil
                }
            }
        default:
            withAnimation(.easeOut(duration: 0.18)) {
                active = ActiveTool(id: item.action)
            }
        }
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            toast = "本机无手电筒"
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
            toast = device.torchMode == .on ? "手电筒已开启" : "手电筒已关闭"
        } catch {
            toast = "无法控制手电筒"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { toast = nil }
        }
    }

    // MARK: - 数据

    private var systemTools: [ToolItem] {
        [
            ToolItem(name: "手电筒", symbol: "flashlight.on.fill", tint: Theme.amber, action: .torch),
            ToolItem(name: "触感反馈", symbol: "waveform.path", tint: Theme.purple, action: .haptics),
            ToolItem(name: "多点触控", symbol: "hand.tap", tint: Theme.blue, action: .touch),
            ToolItem(name: "记录足迹", symbol: "point.topleft.down.to.point.bottomright.curvepath", tint: Theme.green, action: .footprint)
        ]
    }

    private var sensorTools: [ToolItem] {
        [
            ToolItem(name: "指南针", symbol: "location.north.line", tint: Theme.pink, action: .compass),
            ToolItem(name: "GPS", symbol: "location.fill", tint: Theme.blue, action: .gps),
            ToolItem(name: "陀螺仪", symbol: "gyroscope", tint: Theme.purple, action: .gyro),
            ToolItem(name: "磁力计", symbol: "dot.radiowaves.left.and.right", tint: Theme.orange, action: .magnet),
            ToolItem(name: "气压计", symbol: "gauge.medium", tint: Theme.green, action: .pressure),
            ToolItem(name: "海拔计", symbol: "mountain.2.fill", tint: Theme.amber, action: .altitude),
            ToolItem(name: "距离感应", symbol: "wave.3.right", tint: Theme.blue, action: .proximity),
            ToolItem(name: "屏幕检测", symbol: "circle.lefthalf.filled", tint: Theme.t2, action: .screen)
        ]
    }

    private var networkTools: [ToolItem] {
        [
            ToolItem(name: "Ping", symbol: "wave.3.forward.circle", tint: Theme.blue, pro: true),
            ToolItem(name: "Telnet", symbol: "apple.terminal", tint: Theme.green, pro: true),
            ToolItem(name: "SSH", symbol: "lock.shield", tint: Theme.purple, pro: true),
            ToolItem(name: "天气", symbol: "cloud.sun.fill", tint: Theme.amber, pro: true)
        ]
    }

    private var utilityTools: [ToolItem] {
        [
            ToolItem(name: "设备检测", symbol: "viewfinder", tint: Theme.amber, action: .detect),
            ToolItem(name: "二维码", symbol: "qrcode", tint: Theme.t2, action: .qr),
            ToolItem(name: "分贝仪", symbol: "mic.fill", tint: Theme.pink, action: .decibel),
            ToolItem(name: "密码生成", symbol: "key.fill", tint: Theme.green, action: .password)
        ]
    }
}

struct ToolCell: View {
    var item: ToolItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(item.tint.opacity(0.11))
                    .frame(width: 36, height: 36)
                Image(systemName: item.symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(item.tint)
            }

            Text(item.name)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(Color(hex: 0xCFD4DD))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(Theme.surf)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Theme.line, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if item.pro {
                Text("PRO")
                    .font(.system(size: 6.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundColor(Theme.amber)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1.5)
                    .background(Theme.amber.opacity(0.14))
                    .clipShape(Rectangle())
                    .padding(5)
            }
        }
    }
}
