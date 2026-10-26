import SwiftUI

struct MonitorView: View {
    @EnvironmentObject var metrics: SystemMetrics
    @State private var expanded = false

    private var islandSupported: Bool {
        DeviceInfo.hasDynamicIsland(metrics.hardwareModel)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                PageHeader(title: "监控", subtitle: "灵动岛 · 悬浮窗")

                supportCard
                islandDemo
                slotsRow
                pipCard
                noteCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    // MARK: - 支持状态

    private var supportCard: some View {
        HStack(spacing: 11) {
            ZStack {
                Rectangle()
                    .fill((islandSupported ? Theme.green : Theme.orange).opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: islandSupported ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(islandSupported ? Theme.green : Theme.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(islandSupported ? "本机支持灵动岛" : "本机无灵动岛")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Theme.t1)
                Text(islandSupported ? "\(DeviceInfo.friendlyName(metrics.hardwareModel)) · 可显示实时活动" : "将自动降级为通知栏与悬浮窗")
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.t3)
                Text(DeviceInfo.islandDiagnostic(metrics.hardwareModel))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundColor(Theme.t3.opacity(0.75))
            }
            Spacer()
        }
        .padding(13)
        .card(radius: 16)
    }

    // MARK: - 灵动岛演示

    private var islandDemo: some View {
        VStack(spacing: 16) {
            Text("形态预览")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Theme.t2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 模拟机身顶部
            VStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: expanded ? 330 : 124, height: expanded ? 92 : 36)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    islandContent
                        .padding(.horizontal, expanded ? 16 : 10)
                }
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x1A1F27), Color(hex: 0x12161C)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .clipShape(Rectangle())

            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                    expanded.toggle()
                }
            } label: {
                Text(expanded ? "收起" : "点按展开")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.amber.opacity(0.12))
                    .clipShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .card()
    }

    private var islandContent: some View {
        Group {
            if expanded {
                HStack(spacing: 12) {
                    VStack(spacing: 3) {
                        Image(systemName: "cpu")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.purple)
                        Text("\(Int(metrics.cpuUsage * 100))%")
                            .font(Px.nb(12))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.thermalColor(metrics.estimatedTemp))
                        Text(String(format: "%.1f°", metrics.estimatedTemp))
                            .font(Px.nb(12))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.amber)
                        Text("\(metrics.batteryPercent)%")
                            .font(Px.nb(12))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.blue)
                        Text(Fmt.speed(metrics.netDown).replacingOccurrences(of: "/s", with: ""))
                            .font(Px.nb(12))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.purple)
                    Text("\(Int(metrics.cpuUsage * 100))%")
                        .font(Px.nb(11))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Circle()
                        .fill(Theme.green)
                        .frame(width: 4, height: 4)
                }
            }
        }
    }

    // MARK: - 左右槽位

    private var slotsRow: some View {
        HStack(spacing: 10) {
            slotCard(symbol: "cpu", title: "左槽位", value: "CPU", tint: Theme.purple)
            slotCard(symbol: "thermometer.medium", title: "右槽位", value: "温度", tint: Theme.thermalColor(metrics.estimatedTemp))
            slotCard(symbol: "bolt.fill", title: "状态位", value: "功率", tint: Theme.amber)
        }
    }

    private func slotCard(symbol: String, title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundColor(tint)
            Text(title)
                .font(.system(size: 8.5))
                .foregroundColor(Theme.t3)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.t1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(radius: 15)
    }

    // MARK: - 悬浮窗

    private var pipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("画中画悬浮窗")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Theme.t2)
                Spacer()
                Text("实验特性")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.orange.opacity(0.12))
                    .clipShape(Rectangle())
            }

            // 网格背景 + 悬浮窗
            GeometryReader { geo in
                ZStack(alignment: .bottomTrailing) {
                    LinearGradient(
                        colors: [Color(hex: 0x1E2530), Color(hex: 0x141A22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Path { p in
                        var x: CGFloat = 0
                        while x <= geo.size.width {
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: geo.size.height))
                            x += 18
                        }
                        var y: CGFloat = 0
                        while y <= geo.size.height {
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                            y += 18
                        }
                    }
                    .stroke(Color.white.opacity(0.045), lineWidth: 0.6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Circle().fill(Theme.green).frame(width: 4, height: 4)
                            Text("实时监控")
                                .font(.system(size: 7.5, weight: .semibold))
                                .foregroundColor(Theme.t2)
                        }
                        Text("\(Int(metrics.cpuUsage * 100))%")
                            .font(Px.nb(17))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        Text(String(format: "%.1f℃", metrics.estimatedTemp))
                            .font(Px.n(9))
                            .foregroundColor(Theme.amber)
                            .monospacedDigit()
                    }
                    .padding(9)
                    .frame(width: 92, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(Rectangle())
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(10)
                }
            }
            .frame(height: 130)
            .clipShape(Rectangle())
        }
        .padding(14)
        .card()
    }

    // MARK: - 说明

    private var noteCard: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(Theme.t3)
            Text("灵动岛实时活动需要 Widget Extension 才能上岛，当前版本为 App 内预览。悬浮窗使用 AVPictureInPictureController 承载自绘帧，属于系统未公开支持的用法，上架审核存在风险，正式版建议以灵动岛为主。")
                .font(.system(size: 9))
                .foregroundColor(Theme.t3)
                .lineSpacing(2)
        }
        .padding(12)
        .card(radius: 14)
    }
}
