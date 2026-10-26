import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

enum Theme {
    static let bg = Color(hex: 0x0E1116)
    static let bgTop = Color(hex: 0x151A21)
    static let surf = Color(hex: 0x171B22)
    static let surf2 = Color(hex: 0x1E232B)
    static let line = Color.white.opacity(0.07)
    static let lineStrong = Color.white.opacity(0.12)

    static let amber = Color(hex: 0xFFB84D)
    static let amberDeep = Color(hex: 0xFFA92E)
    static let t1 = Color(hex: 0xE8EBF0)
    static let t2 = Color(hex: 0x9BA3B0)
    static let t3 = Color(hex: 0x5A6270)

    static let green = Color(hex: 0x34D399)
    static let blue = Color(hex: 0x5AC8FA)
    static let purple = Color(hex: 0xA78BFA)
    static let pink = Color(hex: 0xFF5C7A)
    static let orange = Color(hex: 0xFF7A5C)
    static let red = Color(hex: 0xFF4D5E)

    static func thermalColor(_ level: Double) -> Color {
        switch level {
        case ..<38: return green
        case ..<43: return amber
        case ..<48: return orange
        default: return red
        }
    }
}

struct CardStyle: ViewModifier {
    var radius: CGFloat = 20
    var border: Color = Theme.line

    func body(content: Content) -> some View {
        content
            .background(Theme.surf)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}

extension View {
    func card(radius: CGFloat = 20, border: Color = Theme.line) -> some View {
        modifier(CardStyle(radius: radius, border: border))
    }
}

/// 全局背景：深石板灰 + 顶部微光
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Theme.amber.opacity(0.07), .clear],
                center: .init(x: 0.5, y: -0.05),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}
