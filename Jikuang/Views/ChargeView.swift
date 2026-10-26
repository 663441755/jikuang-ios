import SwiftUI

struct ChargeView: View {
    @EnvironmentObject var charge: ChargeEstimator
    @EnvironmentObject var metrics: SystemMetrics

    private var tint: Color {
        charge.isCharging ? Theme.amber : Theme.t2
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {

                PageHeader(title: "充电", subtitle: "功率为估算值")

                mainCard
                statsRow
                sessionChart
                recordList
                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    // MARK: - 主卡

    private var mainCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)
                        Text(charge.isCharging ? (charge.measuring ? "测量中" : "充电中") : "未充电")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(tint)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12))
                    .clipShape(Capsule())

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", charge.power))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.t1)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("W")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.t3)
                    }

                    Text("当前充电功率 · 估算")
                        .font(.system(size: 9.5))
                        .foregroundColor(Theme.t3)
                }

                Spacer(minLength: 0)

                ZStack {
                    RingGauge(
                        progress: min(charge.power / 35.0, 1),
                        lineWidth: 9,
                        colors: [Theme.amber, Theme.amberDeep]
                    )
                    VStack(spacing: 1) {
                        Text("\(Int(charge.level * 100))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.t1)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Theme.t3)
                    }
                }
                .frame(width: 92, height: 92)
            }

            Divider().overlay(Theme.line)

            HStack(spacing: 0) {
                StatTile(label: "本次时长", value: Fmt.duration(charge.elapsed), tint: Theme.t1)
                StatTile(label: "峰值功率", value: String(format: "%.1f", charge.peakPower), unit: "W", tint: Theme.amber)
                StatTile(label: "充入能量", value: String(format: "%.1f", charge.sessionWh), unit: "Wh", tint: Theme.green)
            }

            HStack {
                Image(systemName: "hourglass")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.t3)
                Text("预计充满")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.t3)
                Spacer()
                Text(charge.fullEstimate)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.t2)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .card()
    }

    // MARK: - 统计

    private var statsRow: some View {
        HStack(spacing: 10) {
            miniStat(
                symbol: "bolt.batteryblock",
                label: "电池侧",
                value: String(format: "%.1f W", charge.batteryPower),
                tint: Theme.green
            )
            miniStat(
                symbol: "thermometer.medium",
                label: "机身温度",
                value: String(format: "%.1f ℃", metrics.estimatedTemp),
                tint: Theme.thermalColor(metrics.estimatedTemp)
            )
        }
    }

    private func miniStat(symbol: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundColor(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8.5))
                    .foregroundColor(Theme.t3)
                Text(value)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.t1)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .card(radius: 16)
    }

    // MARK: - 本次会话曲线

    private var sessionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本次充电曲线")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Theme.t2)
                Spacer()
                Text("每 1% 采样")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.t3)
            }

            if charge.samples.count < 2 {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.t3.opacity(0.6))
                    Text(charge.isCharging ? "正在采集，电量每变化 1% 记录一次" : "接入电源后开始采样")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.t3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 92)
            } else {
                StepChart(values: charge.samples, tint: Theme.amber)
                    .frame(height: 96)

                HStack(spacing: 0) {
                    Text("开始")
                        .font(.system(size: 8.5))
                        .foregroundColor(Theme.t3)
                    Spacer()
                    Text("现在")
                        .font(.system(size: 8.5))
                        .foregroundColor(Theme.t3)
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
                Text("充电记录")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Theme.t2)
                Spacer()
                Text("\(charge.records.count) 条")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.t3)
            }
            .padding(.bottom, 8)

            if charge.records.isEmpty {
                Text("暂无记录，完成一次充电后自动生成")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.t3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ForEach(charge.records.prefix(5)) { record in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.amber.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.amber)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(record.startLevel * 100))% → \(Int(record.endLevel * 100))%")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.t1)
                                .monospacedDigit()
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 9))
                                .foregroundColor(Theme.t3)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "峰值 %.1f W", record.peakPower))
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.t2)
                                .monospacedDigit()
                            Text(String(format: "%.1f Wh · %@", record.wattHours, Fmt.duration(record.duration)))
                                .font(.system(size: 9))
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
            Text("iOS 未开放充电功率读数接口，这里的功率由电量变化速率推算（ΔSoC × 电池额定能量 ÷ 时间 ÷ 链路效率），误差通常在 ±1.5W 内。仅作参考，不能替代专业功率计。")
                .font(.system(size: 9))
                .foregroundColor(Theme.t3)
                .lineSpacing(2)
        }
        .padding(12)
        .card(radius: 14)
    }
}

// MARK: - 阶梯折线图

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
                // 参考线
                Path { p in
                    for i in 1...3 {
                        let y = h * CGFloat(i) / 4
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.045), lineWidth: 0.7)

                // 阶梯面积
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
                        colors: [tint.opacity(0.28), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // 阶梯线
                Path { p in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - CGFloat(v / maxV) * (h - 6)
                        if i == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x - stepX, y: y))
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                // 峰值点
                if let peak = values.max(), let idx = values.firstIndex(of: peak) {
                    let x = CGFloat(idx) * stepX
                    let y = h - CGFloat(peak / maxV) * (h - 6)
                    Circle()
                        .fill(Theme.t1)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                        .shadow(color: tint, radius: 5)
                }
            }
        }
    }
}
