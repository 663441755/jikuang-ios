import SwiftUI

struct ChargeView: View {
    @EnvironmentObject var charge: ChargeEstimator
    @EnvironmentObject var metrics: SystemMetrics

    private var tint: Color {
        charge.isCharging ? Theme.ecgLine : Theme.t3
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                PageHeader(title: "充电", subtitle: "ECG MODE")

                ecgCard
                statsCard
                sessionChart
                recordList
                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    // MARK: - 心电图主卡

    private var ecgCard: some View {
        VStack(spacing: 12) {

            // 通道状态行
            HStack(spacing: 8) {
                // 闪烁的活动指示块
                Rectangle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: tint, radius: 5)
                    .opacity(charge.isCharging ? 1 : 0.4)

                Text(charge.isCharging ? (charge.measuring ? "MEASURING" : "CHARGING") : "STANDBY")
                    .font(Px.nb(10))
                    .foregroundColor(tint)

                Spacer()

                Text("CH-1")
                    .font(Px.n(8))
                    .foregroundColor(Theme.t3)

                Text(charge.sourceLabel)
                    .font(Px.n(8))
                    .foregroundColor(Theme.amber.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .overlay(Rectangle().stroke(Theme.amber.opacity(0.35), lineWidth: 0.8))
            }

            // 功率读数 + 节律
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", charge.power))
                        .font(Px.nb(50))
                        .foregroundColor(Theme.t1)
                        .contentTransition(.numericText())
                        .shadow(color: Theme.amber.opacity(0.45), radius: 10)
                    Text("W")
                        .font(Px.nb(14))
                        .foregroundColor(Theme.amber)
                        .padding(.bottom, 6)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(charge.bpm)")
                            .font(Px.nb(19))
                            .foregroundColor(Theme.ecgLine)
                            .contentTransition(.numericText())
                        Text("BPM")
                            .font(Px.n(7.5))
                            .foregroundColor(Theme.t3)
                    }
                    Text(charge.protocolLabel)
                        .font(Px.cn(8.5, .medium))
                        .foregroundColor(Theme.t3)
                        .lineLimit(1)
                }
            }

            // 波形
            ECGMonitor(
                samples: charge.ecg,
                tint: charge.isCharging ? Theme.ecgLine : Theme.t3,
                active: charge.isCharging
            )
            .frame(height: 168)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))

            // 电参数读数
            HStack(spacing: 0) {
                eParam(label: "VOLTAGE", value: String(format: "%.1f", charge.voltageEstimate), unit: "V", tint: Theme.amber)
                eParam(label: "CURRENT", value: String(format: "%.2f", charge.currentEstimate), unit: "A", tint: Theme.purple)
                eParam(label: "BATTERY", value: String(format: "%.1f", charge.batteryPower), unit: "W", tint: Theme.pink)
            }
            .padding(.top, 2)

            HStack {
                Image(systemName: "hourglass")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.t3)
                Text("预计充满")
                    .font(Px.cn(9.5))
                    .foregroundColor(Theme.t3)
                Text(charge.fullFromSystem ? "SYS" : "EST")
                    .font(Px.n(7.5))
                    .foregroundColor(charge.fullFromSystem ? Theme.ecgLine : Theme.t3)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .overlay(
                        Rectangle().stroke(
                            (charge.fullFromSystem ? Theme.ecgLine : Theme.t3).opacity(0.4),
                            lineWidth: 0.8
                        )
                    )
                Spacer()
                if let m = charge.fullMinutes {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(m >= 60 ? "\(m / 60):\(String(format: "%02d", m % 60))" : "\(m)")
                            .font(Px.nb(13))
                            .foregroundColor(Theme.t1)
                            .contentTransition(.numericText())
                        Text(m >= 60 ? "HR" : "MIN")
                            .font(Px.n(7.5))
                            .foregroundColor(Theme.t3)
                    }
                } else {
                    Text(charge.fullEstimate)
                        .font(Px.cn(11))
                        .foregroundColor(Theme.t2)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .card()
    }

    /// 时长显示：仪表式 MM:SS（超过 1 小时 H:MM:SS），避免中文与像素数字混排
    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private func eParam(label: String, value: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Px.n(7))
                .foregroundColor(Theme.t3)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(Px.nb(15))
                    .foregroundColor(tint)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(Px.n(8))
                    .foregroundColor(Theme.t3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 统计

    private var statsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                StatTile(label: "本次时长", value: clock(charge.elapsed), tint: Theme.t1)
                StatTile(label: "峰值功率", value: String(format: "%.1f", charge.peakPower), unit: "W", tint: Theme.amber)
                StatTile(label: "充入能量", value: String(format: "%.1f", charge.sessionWh), unit: "Wh", tint: Theme.ecgLine)
            }

            Divider().overlay(Theme.line)

            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "bolt.batteryblock")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.ecgLine)
                    Text("电量")
                        .font(Px.cn(9))
                        .foregroundColor(Theme.t3)
                    Text("\(charge.batteryPercent)%")
                        .font(Px.nb(12))
                        .foregroundColor(Theme.t1)
                        .contentTransition(.numericText())
                }

                Spacer()

                SegmentedBar(value: charge.level, tint: Theme.ecgLine, height: 6)
                    .frame(width: 108)
            }

            HStack(spacing: 7) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.thermalColor(metrics.estimatedTemp))
                Text("机身温度")
                    .font(Px.cn(9))
                    .foregroundColor(Theme.t3)
                Spacer()
                Text(String(format: "%.1f ℃", metrics.estimatedTemp))
                    .font(Px.nb(12))
                    .foregroundColor(Theme.thermalColor(metrics.estimatedTemp))
            }
        }
        .padding(14)
        .card()
    }

    // MARK: - 本次会话曲线

    private var sessionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("// 本次充电曲线")
                    .font(Px.cn(9.5, .medium))
                    .foregroundColor(Theme.t2)
                Spacer()
                Text(charge.isCharging ? "LIVE" : "IDLE")
                    .font(Px.n(8))
                    .foregroundColor(charge.isCharging ? Theme.ecgLine : Theme.t3)
            }

            if charge.samples.count < 2 {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.t3.opacity(0.6))
                    Text(charge.isCharging ? "正在采集，电量每变化 1% 记录一次" : "接入电源后开始采样")
                        .font(Px.cn(9.5))
                        .foregroundColor(Theme.t3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 84)
            } else {
                StepChart(values: charge.samples, tint: Theme.amber)
                    .frame(height: 92)

                HStack(spacing: 0) {
                    Text("START")
                        .font(Px.n(7.5))
                        .foregroundColor(Theme.t3)
                    Spacer()
                    Text("NOW")
                        .font(Px.n(7.5))
                        .foregroundColor(Theme.amber)
                }
            }
        }
        .padding(14)
        .card()
    }

    // MARK: - 历史记录

    private var recordList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("// 充电记录")
                    .font(Px.cn(9.5, .medium))
                    .foregroundColor(Theme.t2)
                Spacer()
                Text("\(charge.records.count)")
                    .font(Px.n(9))
                    .foregroundColor(Theme.t3)
            }
            .padding(.bottom, 8)

            if charge.records.isEmpty {
                Text("暂无记录，完成一次充电后自动生成")
                    .font(Px.cn(9.5))
                    .foregroundColor(Theme.t3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ForEach(charge.records.prefix(5)) { record in
                    HStack(spacing: 10) {
                        ZStack {
                            Rectangle()
                                .fill(Theme.amber.opacity(0.12))
                                .frame(width: 26, height: 26)
                                .overlay(Rectangle().stroke(Theme.amber.opacity(0.35), lineWidth: 0.8))
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.amber)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(record.startLevel * 100))% > \(Int(record.endLevel * 100))%")
                                .font(Px.nb(11))
                                .foregroundColor(Theme.t1)
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(Px.cn(8.5))
                                .foregroundColor(Theme.t3)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "PK %.1fW", record.peakPower))
                                .font(Px.n(10))
                                .foregroundColor(Theme.t2)
                            Text(String(format: "%.1fWh · %@", record.wattHours, Fmt.duration(record.duration)))
                                .font(Px.cn(8.5))
                                .foregroundColor(Theme.t3)
                        }
                    }
                    .padding(.vertical, 8)

                    if record.id != charge.records.prefix(5).last?.id {
                        Divider().overlay(Theme.line)
                    }
                }
            }
        }
        .padding(14)
        .card()
    }

    // MARK: - 说明

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(Theme.t3)
            Text("心电图波形为功率的可视化表达：振幅与节律由实测功率驱动，并非真实电生理信号。iOS 未开放充电功率与充电器协商协议的读数接口，功率由电量变化速率推算（误差通常 ±1.5W 内），电压/电流为按 PD 档位推断值（本机支持 PD 3.1 AVS/EPR，45W 即经 AVS 协商）。仅作参考，不能替代专业功率计。")
                .font(Px.cn(9))
                .foregroundColor(Theme.t3)
                .lineSpacing(2)
        }
        .padding(12)
        .card(radius: 14, corners: false)
    }
}

// MARK: - 阶梯折线图（像素版）

struct StepChart: View {
    var values: [Double]
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxV = max(values.max() ?? 1, 1)
            let count = max(values.count - 1, 1)
            let stepX = w / CGFloat(count)

            ZStack {
                // 网格
                Canvas { ctx, size in
                    var p = Path()
                    var y: CGFloat = 0
                    while y <= size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        y += size.height / 6
                    }
                    var x: CGFloat = 0
                    while x <= size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        x += size.width / 8
                    }
                    ctx.stroke(p, with: .color(Theme.amber.opacity(0.08)), lineWidth: 0.5)
                }
                .drawingGroup()

                // 面积
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - CGFloat(v / maxV) * (h - 6)
                        if i == 0 {
                            p.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x - stepX, y: y))
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.26), tint.opacity(0.015)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // 阶梯线
                Path { p in
                    var lastY = h
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - CGFloat(v / maxV) * (h - 6)
                        if i == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: lastY))
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        lastY = y
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .butt, lineJoin: .miter))
                .shadow(color: tint.opacity(0.7), radius: 3)

                // 峰值方块
                if let peak = values.max(), let idx = values.firstIndex(of: peak) {
                    let x = CGFloat(idx) * stepX
                    let y = h - CGFloat(peak / maxV) * (h - 6)
                    Rectangle()
                        .fill(Theme.t1)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                        .shadow(color: tint, radius: 5)
                }
            }
        }
    }
}
