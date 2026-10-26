import SwiftUI

// MARK: - CPU 波形（像素台阶版）

struct Waveform: View {
    var values: [Double]
    var color: Color = Theme.amber
    var showGrid: Bool = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = max(values.count - 1, 1)
            let stepX = w / CGFloat(count)

            ZStack {
                if showGrid {
                    Canvas { ctx, size in
                        var p = Path()
                        for i in 1...3 {
                            let y = size.height * CGFloat(i) / 4
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        for i in 1...6 {
                            let x = size.width * CGFloat(i) / 7
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        ctx.stroke(p, with: .color(Theme.amber.opacity(0.10)), lineWidth: 0.5)
                    }
                    .drawingGroup()
                }

                // 面积
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    var lastY = h
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        // 量化到 1/20 网格，做出数字示波器的台阶感
                        let q = (min(max(v, 0), 1) * 20).rounded() / 20
                        let y = h - CGFloat(q) * h
                        if i == 0 {
                            p.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: lastY))
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        lastY = y
                    }
                    p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * stepX, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.30), color.opacity(0.015)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // 曲线（直角折线，不用圆角，保持像素硬边）
                Path { p in
                    var lastY = h
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let q = (min(max(v, 0), 1) * 20).rounded() / 20
                        let y = h - CGFloat(q) * h
                        if i == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: lastY))
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        lastY = y
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .butt, lineJoin: .miter))
                .shadow(color: color.opacity(0.8), radius: 4)

                // 末端方块指示点
                if let last = values.last {
                    let q = (min(max(last, 0), 1) * 20).rounded() / 20
                    let y = h - CGFloat(q) * h
                    Rectangle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .position(x: CGFloat(values.count - 1) * stepX, y: y)
                        .shadow(color: color, radius: 6)
                }
            }
        }
    }
}

// MARK: - 心电图（ECG）

/// 心电图纸：小格 7pt，大格 35pt，青绿网格
struct ECGPaper: View {
    var body: some View {
        Canvas { ctx, size in
            var small = Path()
            let s: CGFloat = 7
            var x: CGFloat = 0
            while x <= size.width {
                small.move(to: CGPoint(x: x, y: 0))
                small.addLine(to: CGPoint(x: x, y: size.height))
                x += s
            }
            var y: CGFloat = 0
            while y <= size.height {
                small.move(to: CGPoint(x: 0, y: y))
                small.addLine(to: CGPoint(x: size.width, y: y))
                y += s
            }
            ctx.stroke(small, with: .color(Theme.ecgGrid), lineWidth: 0.5)

            var big = Path()
            let b: CGFloat = 35
            var bx: CGFloat = 0
            while bx <= size.width {
                big.move(to: CGPoint(x: bx, y: 0))
                big.addLine(to: CGPoint(x: bx, y: size.height))
                bx += b
            }
            var by: CGFloat = 0
            while by <= size.height {
                big.move(to: CGPoint(x: 0, y: by))
                big.addLine(to: CGPoint(x: size.width, y: by))
                by += b
            }
            ctx.stroke(big, with: .color(Theme.amber.opacity(0.15)), lineWidth: 0.6)
        }
        .drawingGroup()
    }
}

/// 心电图波形：从右往左滚动，末端带扫描头
struct ECGMonitor: View {
    var samples: [Double]
    var tint: Color = Theme.ecgLine
    var active: Bool = true
    /// 纵向增益，1.0 表示一个 R 波峰约占 60% 高度
    var gain: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let baseY = h * 0.66
            let amp = h * 0.52 * gain

            ZStack {
                ECGPaper()
                    .opacity(active ? 1 : 0.45)

                // 基线
                Rectangle()
                    .fill(Theme.amber.opacity(0.18))
                    .frame(height: 0.6)
                    .position(x: w / 2, y: baseY)

                wavePath(w: w, baseY: baseY, amp: amp)
                    .stroke(tint.opacity(0.22), style: StrokeStyle(lineWidth: 6, lineCap: .butt, lineJoin: .miter))
                    .blur(radius: 3)

                wavePath(w: w, baseY: baseY, amp: amp)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .butt, lineJoin: .miter))

                // 扫描头
                if let last = samples.last, samples.count > 1 {
                    let x = w - 1
                    let y = baseY - CGFloat(last) * amp
                    Rectangle()
                        .fill(tint)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: min(max(y, 2), h - 2))
                        .shadow(color: tint, radius: 7)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.30), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 1, height: h)
                        .position(x: x, y: h / 2)
                }
            }
            .clipped()
        }
    }

    private func wavePath(w: CGFloat, baseY: CGFloat, amp: CGFloat) -> Path {
        Path { p in
            guard samples.count > 1 else { return }
            let stepX = w / CGFloat(samples.count - 1)
            var lastY = baseY
            for (i, v) in samples.enumerated() {
                let x = CGFloat(i) * stepX
                let y = min(max(baseY - CGFloat(v) * amp, 2), baseY + amp * 0.35)
                if i == 0 {
                    p.move(to: CGPoint(x: x, y: y))
                } else {
                    // 水平 → 垂直，两级台阶，模拟数字采样
                    p.addLine(to: CGPoint(x: x, y: lastY))
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                lastY = y
            }
        }
    }
}

// MARK: - 分段环形仪表（像素版）

struct RingGauge: View {
    var progress: Double        // 0...1
    var lineWidth: CGFloat = 8
    var colors: [Color] = [Theme.amber, Theme.amberDeep]
    var trackOpacity: Double = 0.08

    private let segments = 28

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2 - lineWidth / 2

            ZStack {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle()
                        .fill(
                            Double(i) / Double(segments) < min(max(progress, 0), 1)
                                ? (colors.first ?? Theme.amber)
                                : Color.white.opacity(trackOpacity)
                        )
                        .frame(width: max(lineWidth * 0.5, 2), height: lineWidth)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(Double(i) / Double(segments) * 360))
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - 半环仪表（温度）

struct HalfGauge: View {
    var progress: Double        // 0...1
    var tint: Color
    var lineWidth: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let radius = min(w / 2, geo.size.height) - lineWidth / 2

            ZStack {
                Path { p in
                    p.addArc(
                        center: CGPoint(x: w / 2, y: geo.size.height),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))

                Path { p in
                    p.addArc(
                        center: CGPoint(x: w / 2, y: geo.size.height),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(180 + 180 * min(max(progress, 0), 1)),
                        clockwise: false
                    )
                }
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .shadow(color: tint.opacity(0.7), radius: 6)
            }
        }
    }
}

// MARK: - 统计块

struct StatTile: View {
    var label: String
    var value: String
    var unit: String? = nil
    var tint: Color = Theme.t1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Px.cn(9, .medium))
                .foregroundColor(Theme.t3)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Px.nb(15))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(Px.n(8))
                        .foregroundColor(Theme.t3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 分段进度条（方块版）

struct SegmentedBar: View {
    var value: Double
    var tint: Color
    var height: CGFloat = 5
    var blockWidth: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 2
            let count = max(Int((geo.size.width + gap) / (blockWidth + gap)), 4)
            let filled = Int((min(max(value, 0), 1) * Double(count)).rounded())

            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(i < filled ? tint : Color.white.opacity(0.07))
                        .frame(height: height)
                }
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}

// MARK: - 页面标题

struct PageHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // 标题前的荧光块
            Rectangle()
                .fill(Theme.amber)
                .frame(width: 5, height: 17)
                .offset(y: -2)
                .shadow(color: Theme.amber.opacity(0.9), radius: 6)

            Text(title)
                .font(Px.cn(22, .heavy))
                .tracking(0.6)
                .foregroundColor(Theme.t1)

            Spacer()

            if let subtitle {
                Text(subtitle.uppercased())
                    .font(Px.n(9))
                    .foregroundColor(Theme.t3)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

// MARK: - 分组标题

struct GroupLabel: View {
    var text: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            Text("//")
                .font(Px.n(9))
                .foregroundColor(Theme.amber.opacity(0.55))

            Text(text)
                .font(Px.cn(10.5, .bold))
                .tracking(1.0)
                .foregroundColor(Theme.t2)

            if let badge {
                Text(badge)
                    .font(Px.n(7.5))
                    .foregroundColor(Theme.bg)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Theme.amber)
            }

            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
