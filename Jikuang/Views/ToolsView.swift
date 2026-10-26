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
}

struct ToolsView: View {
    @State private var showDetect = false
    @State private var toast: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    PageHeader(title: "工具", subtitle: "20 项")

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
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.lineStrong, lineWidth: 1))
                        .padding(.bottom, 100)
                        .transition(.opacity)
                }
            }
        }
        .fullScreenCover(isPresented: $showDetect) {
            DetectView()
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
                toast = "\(item.name) · 下一版接入"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeIn(duration: 0.25)) {
                    toast = nil
                }
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
            ToolItem(name: "触感反馈", symbol: "waveform.path", tint: Theme.purple),
            ToolItem(name: "多点触控", symbol: "hand.tap", tint: Theme.blue),
            ToolItem(name: "记录足迹", symbol: "point.topleft.down.to.point.bottomright.curvepath", tint: Theme.green)
        ]
    }

    private var sensorTools: [ToolItem] {
        [
            ToolItem(name: "指南针", symbol: "location.north.line", tint: Theme.pink),
            ToolItem(name: "GPS", symbol: "location.fill", tint: Theme.blue),
            ToolItem(name: "陀螺仪", symbol: "gyroscope", tint: Theme.purple),
            ToolItem(name: "磁力计", symbol: "dot.radiowaves.left.and.right", tint: Theme.orange),
            ToolItem(name: "气压计", symbol: "gauge.medium", tint: Theme.green),
            ToolItem(name: "海拔计", symbol: "mountain.2.fill", tint: Theme.amber),
            ToolItem(name: "距离感应", symbol: "wave.3.right", tint: Theme.blue),
            ToolItem(name: "色温调节", symbol: "circle.lefthalf.filled", tint: Theme.t2)
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
            ToolItem(name: "二维码", symbol: "qrcode", tint: Theme.t2),
            ToolItem(name: "分贝仪", symbol: "mic.fill", tint: Theme.pink),
            ToolItem(name: "密码生成", symbol: "key.fill", tint: Theme.green)
        ]
    }
}

struct ToolCell: View {
    var item: ToolItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(5)
            }
        }
    }
}
