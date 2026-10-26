import SwiftUI

struct DetectView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = DetectEngine()

    private var groups: [(String, [CheckItem])] {
        var order: [String] = []
        var map: [String: [CheckItem]] = [:]
        for item in engine.items {
            if map[item.group] == nil {
                order.append(item.group)
                map[item.group] = []
            }
            map[item.group]?.append(item)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private var passCount: Int { engine.items.filter { $0.status == .pass }.count }
    private var warnCount: Int { engine.items.filter { $0.status == .warn || $0.status == .fail }.count }
    private var manualCount: Int { engine.items.filter { $0.status == .manual }.count }
    private var pendingCount: Int { engine.items.filter { $0.status == .pending || $0.status == .running }.count }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    healthCard
                    actionButton
                    itemList
                    disclaimer
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .top) {
            header
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("工具")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Theme.amber)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("设备检测")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.t1)

            Spacer()

            Color.clear.frame(width: 46, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    // MARK: - 健康度

    private var healthCard: some View {
        VStack(spacing: 14) {
            ZStack {
                RingGauge(
                    progress: Double(engine.score) / 100.0,
                    lineWidth: 11,
                    colors: scoreColors
                )
                .frame(width: 132, height: 132)

                VStack(spacing: 0) {
                    Text("\(engine.score)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.t1)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(engine.finished ? scoreLabel : "健康度")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(Theme.t2)
                }
            }
            .padding(.top, 6)

            HStack(spacing: 0) {
                summaryCell(value: "\(passCount)", label: "通过", tint: Theme.green)
                Divider().frame(height: 24).overlay(Theme.line)
                summaryCell(value: "\(warnCount)", label: "注意", tint: Theme.orange)
                Divider().frame(height: 24).overlay(Theme.line)
                summaryCell(value: "\(manualCount + pendingCount)", label: "待检", tint: Theme.t3)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .card()
    }

    private var scoreColors: [Color] {
        if !engine.finished { return [Theme.amber, Theme.amberDeep] }
        switch engine.score {
        case 90...: return [Theme.green, Color(hex: 0x22B07D)]
        case 70..<90: return [Theme.amber, Theme.amberDeep]
        default: return [Theme.orange, Theme.red]
        }
    }

    private var scoreLabel: String {
        switch engine.score {
        case 90...: return "状况良好"
        case 70..<90: return "存在注意项"
        default: return "建议检修"
        }
    }

    private func summaryCell(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8.5))
                .foregroundColor(Theme.t3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 按钮

    private var actionButton: some View {
        Button {
            engine.runAll()
        } label: {
            HStack(spacing: 7) {
                if engine.running {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(hex: 0x1A1206))
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: engine.finished ? "arrow.clockwise" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(engine.running ? "检测中…" : (engine.finished ? "重新检测" : "开始全部检测"))
                    .font(.system(size: 13.5, weight: .bold))
            }
            .foregroundColor(Color(hex: 0x1A1206))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Theme.amber, Theme.amberDeep],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: Theme.amber.opacity(0.35), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(engine.running)
        .opacity(engine.running ? 0.75 : 1)
    }

    // MARK: - 检测项列表

    private var itemList: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.indices), id: \.self) { gi in
                let group = groups[gi]
                GroupLabel(text: group.0)

                VStack(spacing: 0) {
                    ForEach(group.1) { item in
                        itemRow(item)
                        if item.id != group.1.last?.id {
                            Divider().overlay(Theme.line).padding(.leading, 42)
                        }
                    }
                }
                .card(radius: 16)
            }
        }
    }

    private func itemRow(_ item: CheckItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(statusColor(item.status).opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: item.symbol)
                    .font(.system(size: 13))
                    .foregroundColor(statusColor(item.status))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.t1)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.system(size: 9))
                        .foregroundColor(Theme.t3)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            statusBadge(item.status)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func statusColor(_ status: CheckStatus) -> Color {
        switch status {
        case .pass: return Theme.green
        case .warn: return Theme.orange
        case .fail: return Theme.red
        case .running: return Theme.amber
        case .manual: return Theme.blue
        case .pending: return Theme.t3
        }
    }

    private func statusBadge(_ status: CheckStatus) -> some View {
        HStack(spacing: 3) {
            if status == .running {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.amber)
                    .scaleEffect(0.5)
                    .frame(width: 8, height: 8)
            }
            Text(status.label)
                .font(.system(size: 8.5, weight: .semibold))
        }
        .foregroundColor(statusColor(status))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(statusColor(status).opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - 免责

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "lock.shield")
                .font(.system(size: 10))
                .foregroundColor(Theme.t3)
            Text("全部检测在本机完成，不上传任何数据。电池健康度与循环次数受 iOS 限制无法直接读取，因此未列入自动评分；结果为各硬件模块可用性检测的加权汇总。")
                .font(.system(size: 9))
                .foregroundColor(Theme.t3)
                .lineSpacing(2)
        }
        .padding(12)
        .card(radius: 14)
        .padding(.top, 6)
    }
}
