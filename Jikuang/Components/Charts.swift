import SwiftUI

// MARK: - CPU 波形图

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
                    Path { p in
                        for i in 1...3 {
                            let y = h * CGFloat(i) / 4
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.045), lineWidth: 0.7)
                }

                // 面积
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - CGFloat(min(max(v, 0), 1)) * h
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * stepX, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.34), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // 曲线
                Path { p in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - CGFloat(min(max(v, 0), 1)) * h
                        if i == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                // 末端点
                if let last = values.last {
                    let y = h - CGFloat(min(max(last, 0), 1)) * h
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(x: CGFloat(values.count - 1) * stepX, y: y)
                        .shadow(color: color.opacity(0.9), radius: 5)
                }
            }
        }
    }
}

// MARK: - 环形进度

struct RingGauge: View {
    var progress: Double        // 0...1
    var lineWidth: CGFloat = 8
    var colors: [Color] = [Theme.amber, Theme.amberDeep]
    var trackOpacity: Double = 0.08

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(trackOpacity), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    AngularGradient(
                        colors: colors + [colors.first ?? Theme.amber],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
                .shadow(color: (colors.first ?? Theme.amber).opacity(0.55), radius: 8)
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
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                Path { p in
                    p.addArc(
                        center: CGPoint(x: w / 2, y: geo.size.height),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(180 + 180 * min(max(progress, 0), 1)),
                        clockwise: false
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.65), tint],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .shadow(color: tint.opacity(0.6), radius: 7)
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
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(Theme.t3)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(tint)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Theme.t3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 分段条

struct SegmentedBar: View {
    var value: Double
    var tint: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                    .animation(.easeOut(duration: 0.4), value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 页面标题

struct PageHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.t1)
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.t3)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

// MARK: - 分组标题

struct GroupLabel: View {
    var text: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            Text(text.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.1)
                .foregroundColor(Theme.t3)
            if let badge {
                Text(badge)
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.4)
                    .foregroundColor(Theme.amber)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Theme.amber.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
