import SwiftUI

struct WidgetPreviewView: View {
    @EnvironmentObject var metrics: SystemMetrics

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                PageHeader(title: "小组件", subtitle: "主屏 · 锁屏")

                wallpaperBoard
                sizeList
                noteCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    // MARK: - 壁纸板

    private var wallpaperBoard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                smallWidget
                VStack(spacing: 10) {
                    mediumWidget
                    HStack(spacing: 10) {
                        miniPill(label: "温度", value: String(format: "%.1f℃", metrics.estimatedTemp), tint: Theme.thermalColor(metrics.estimatedTemp))
                        miniPill(label: "CPU", value: "\(Int(metrics.cpuUsage * 100))%", tint: Theme.purple)
                    }
                }
            }

            largeWidget
        }
        .padding(14)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x2A1F3D), Color(hex: 0x141B2B), Color(hex: 0x1E2A24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Theme.amber.opacity(0.22), .clear],
                    center: .init(x: 0.85, y: 0.1),
                    startRadius: 5,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.purple)
                Text("CPU")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
            Text("\(Int(metrics.cpuUsage * 100))")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text("%")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
            Waveform(values: metrics.cpuHistory.suffix(20).map { $0 }, color: Theme.purple, showGrid: false)
                .frame(height: 18)
        }
        .padding(10)
        .frame(width: 118, height: 118, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var mediumWidget: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("机身温度")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                HStack(alignment: .bottom, spacing: 1) {
                    Text(String(format: "%.1f", metrics.estimatedTemp))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text("℃")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 3)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("内存")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(Fmt.bytes(metrics.memUsed))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
        .padding(11)
        .frame(height: 54)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func miniPill(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7.5))
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Theme.amber).frame(width: 4, height: 4)
                    Text("机况")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(Fmt.duration(metrics.uptime))
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                largeCell("温度", String(format: "%.1f", metrics.estimatedTemp), "℃", Theme.thermalColor(metrics.estimatedTemp))
                largeCell("CPU", "\(Int(metrics.cpuUsage * 100))", "%", Theme.purple)
                largeCell("下行", Fmt.speed(metrics.netDown).replacingOccurrences(of: "/s", with: ""), "/s", Theme.blue)
                largeCell("电量", "\(Int(metrics.batteryLevel * 100))", "%", Theme.green)
            }

            SegmentedBar(
                value: metrics.memTotal > 0 ? Double(metrics.memUsed) / Double(metrics.memTotal) : 0,
                tint: Theme.green,
                height: 4
            )
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func largeCell(_ label: String, _ value: String, _ unit: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7.5))
                .foregroundColor(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 尺寸列表

    private var sizeList: some View {
        VStack(spacing: 0) {
            sizeRow("小组件", desc: "CPU 负载 + 波形", done: true)
            Divider().overlay(Theme.line)
            sizeRow("中组件", desc: "温度 + 内存", done: true)
            Divider().overlay(Theme.line)
            sizeRow("大组件", desc: "四指标总览", done: true)
            Divider().overlay(Theme.line)
            sizeRow("锁屏组件", desc: "电量与温度行内显示", done: true)
        }
        .padding(.horizontal, 14)
        .card()
    }

    private func sizeRow(_ title: String, desc: String, done: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.t1)
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.t3)
            }
            Spacer()
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 13))
                .foregroundColor(done ? Theme.green : Theme.t3)
        }
        .padding(.vertical, 10)
    }

    private var noteCard: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(Theme.t3)
            Text("以上为设计稿实景预览。真机小组件需要 Widget Extension 目标，当前版本先锁定视觉规格，下一版接入数据源。")
                .font(.system(size: 9))
                .foregroundColor(Theme.t3)
                .lineSpacing(2)
        }
        .padding(12)
        .card(radius: 14)
    }
}
