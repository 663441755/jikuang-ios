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
                    withAnimation(.easeOut(duration: 0.18)) {
                        selection = item
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 18, weight: selection == item ? .semibold : .regular))
                            .frame(height: 22)
                        Text(item.rawValue)
                            .font(.system(size: 8.5, weight: .medium))
                    }
                    .foregroundColor(selection == item ? Theme.amber : Theme.t3)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.25))
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }
}
