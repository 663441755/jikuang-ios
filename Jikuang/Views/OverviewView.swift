import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var metrics: SystemMetrics

    private var tempTint: Color { Theme.thermalColor(metrics.estimatedTemp) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                PageHeader(title: "概览", subtitle: metrics.systemVersion)

                deviceCard
                statusStrip
                cpuCard

                HStack(alignment: .top, spacing: 10) {
                    thermalCard
                    netCard
                }

                memoryCard
                diskCard
                infoCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    // MARK: - 设备卡

    private var deviceCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.amber, Theme.amberDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: 0x1A1206))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(DeviceInfo.friendlyName(metrics.hardwareModel))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.t1)
                Text("\(metrics.coreCount) 核 · \(metrics.screenInfo) px")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.t2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("已运行")
                    .font(.system(size: 8.5))
                    .foregroundColor(Theme.t3)
                Text(Fmt.duration(metrics.uptime))
                    .font(Px.n(10.5))
                    .foregroundColor(Theme.t2)
                    .monospacedDigit()
            }
        }
        .padding(14)
        .card()
    }

    // MARK: - 状态带

    private var statusStrip: some View {
        HStack(spacing: 0) {
            stripCell(
                value: String(format: "%.1f", metrics.estimatedTemp),
                unit: "℃",
                label: "机身温度",
                tint: tempTint,
                symbol: "thermometer.medium"
            )
            Divider().frame(height: 26).overlay(Theme.line)
            stripCell(
                value: "\(Int(metrics.cpuUsage * 100))",
                unit: "%",
                label: "CPU",
                tint: Theme.purple,
                symbol: "cpu"
            )
            Divider().frame(height: 26).overlay(Theme.line)
            stripCell(
                value: Fmt.speed(metrics.netDown).replacingOccurrences(of: "/s", with: ""),
                unit: "/s",
                label: "下行",
                tint: Theme.blue,
                symbol: "arrow.down"
            )
        }
        .padding(.vertical, 11)
        .card(radius: 18)
    }

    private func stripCell(value: String, unit: String, label: String, tint: Color, symbol: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(tint)
                Text(value)
                    .font(Px.nb(15))
                    .foregroundColor(Theme.t1)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(Theme.t3)
            }
            Text(label)
                .font(.system(size: 8.5))
                .foregroundColor(Theme.t3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - CPU

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU 负载")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Theme.t2)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(metrics.cpuUsage * 100))")
                            .font(Px.nb(32))
                            .foregroundColor(Theme.t1)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.t3)
                    }
                }
                Spacer()
                Text("\(metrics.coreCount) 核心")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Theme.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.purple.opacity(0.12))
                    .clipShape(Rectangle())
            }

            Waveform(values: metrics.cpuHistory, color: Theme.purple)
                .frame(height: 62)

            if !metrics.perCore.isEmpty {
                HStack(spacing: 3) {
                    ForEach(Array(metrics.perCore.prefix(8).indices), id: \.self) { index in
                        let value = metrics.perCore[index]
                        VStack(spacing: 3) {
                            Rectangle()
                                .fill(Theme.purple.opacity(0.22))
                                .frame(height: 26)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Theme.purple)
                                        .frame(height: max(2, 26 * CGFloat(value)))
                                }
                            Text("\(Int(value * 100))")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(Theme.t3)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .card()
    }

    // MARK: - 温度

    private var thermalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("机身温度")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Theme.t2)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            HStack(alignment: .bottom, spacing: 1) {
                Text(String(format: "%.1f", metrics.estimatedTemp))
                    .font(Px.nb(30))
                    .foregroundColor(tempTint)
                    .monospacedDigit()
                Text("℃")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.t3)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 12)

            HalfGauge(
                progress: Double((metrics.estimatedTemp - 24) / 26),
                tint: tempTint
            )
            .frame(height: 30)
            .padding(.horizontal, 10)

            HStack(spacing: 4) {
                Circle().fill(tempTint).frame(width: 4, height: 4)
                Text(metrics.thermalText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(tempTint)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 网络

    private var netCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("实时网速")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Theme.t2)

            HStack(spacing: 5) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.blue)
                Text(Fmt.speed(metrics.netDown))
                    .font(Px.nb(15))
                    .foregroundColor(Theme.t1)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 5) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.green)
                Text(Fmt.speed(metrics.netUp))
                    .font(Px.n(13))
                    .foregroundColor(Theme.t2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Waveform(values: metrics.netHistory.map { min($0 / 2_000_000, 1) }, color: Theme.blue, showGrid: false)
                .frame(height: 34)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 内存

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("内存")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Theme.t2)
                Spacer()
                Text("\(Fmt.bytes(metrics.memUsed)) / \(Fmt.bytes(metrics.memTotal))")
                    .font(Px.n(10))
                    .foregroundColor(Theme.t2)
                    .monospacedDigit()
            }

            SegmentedBar(
                value: metrics.memTotal > 0 ? Double(metrics.memUsed) / Double(metrics.memTotal) : 0,
                tint: Theme.green,
                height: 6
            )

            HStack(spacing: 0) {
                StatTile(label: "已用", value: Fmt.bytes(metrics.memUsed), tint: Theme.green)
                StatTile(label: "可用", value: Fmt.bytes(max(metrics.memTotal - metrics.memUsed, 0)), tint: Theme.t1)
                StatTile(label: "本 App", value: Fmt.bytes(metrics.memApp), tint: Theme.t2)
            }
        }
        .padding(14)
        .card()
    }

    // MARK: - 存储

    private var diskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("存储")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Theme.t2)
                Spacer()
                Text("\(Fmt.bytes(metrics.diskUsed)) / \(Fmt.bytes(metrics.diskTotal))")
                    .font(Px.n(10))
                    .foregroundColor(Theme.t2)
                    .monospacedDigit()
            }

            SegmentedBar(
                value: metrics.diskTotal > 0 ? Double(metrics.diskUsed) / Double(metrics.diskTotal) : 0,
                tint: Theme.orange,
                height: 6
            )

            HStack(spacing: 0) {
                StatTile(label: "剩余空间", value: Fmt.bytes(max(metrics.diskTotal - metrics.diskUsed, 0)), tint: Theme.t1)
                StatTile(
                    label: "使用率",
                    value: metrics.diskTotal > 0 ? "\(Int(Double(metrics.diskUsed) / Double(metrics.diskTotal) * 100))" : "0",
                    unit: "%",
                    tint: Theme.orange
                )
            }
        }
        .padding(14)
        .card()
    }

    // MARK: - 设备信息

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow("机型标识", metrics.hardwareModel)
            Divider().overlay(Theme.line)
            infoRow("系统版本", metrics.systemVersion)
            Divider().overlay(Theme.line)
            infoRow("屏幕分辨率", metrics.screenInfo)
            Divider().overlay(Theme.line)
            infoRow("运行时长", Fmt.duration(metrics.uptime))
        }
        .padding(.horizontal, 14)
        .card()
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 11))
                .foregroundColor(Theme.t2)
            Spacer()
            Text(value)
                .font(Px.n(11))
                .foregroundColor(Theme.t1)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }
}
