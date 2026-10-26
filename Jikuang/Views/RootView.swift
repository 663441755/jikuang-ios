import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "概览"
    case charge = "充电"
    case monitor = "监控"
    case widget = "小组件"
    case tools = "工具"

    var symbol: String {
        switch self {
        case .home: return "iphone.gen3"
        case .charge: return "bolt.fill"
        case .monitor: return "capsule.portrait"
        case .widget: return "square.grid.2x2"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            Group {
                switch tab {
                case .home: OverviewView()
                case .charge: ChargeView()
                case .monitor: MonitorView()
                case .widget: WidgetPreviewView()
                case .tools: ToolsView()
                }
            }
            .transition(.opacity)

            TabBar(selection: $tab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selection = item
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 17, weight: selection == item ? .semibold : .regular))
                            .frame(height: 19)
                        Text(item.rawValue)
                            .font(Px.cn(8.5, selection == item ? .bold : .medium))
                            .tracking(0.6)
                    }
                    .foregroundColor(selection == item ? Theme.amber : Theme.t3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        if selection == item {
                            Rectangle()
                                .fill(Theme.amber.opacity(0.09))
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .fill(Theme.amber)
                                        .frame(height: 2)
                                        .shadow(color: Theme.amber, radius: 5)
                                }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 2)
        .background {
            Color(hex: 0x06080D)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.amber.opacity(0.28))
                .frame(height: 1)
        }
    }
}
