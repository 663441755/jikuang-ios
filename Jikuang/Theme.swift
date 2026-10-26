import SwiftUI
import UIKit
import CoreText

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - 赛博配色 + 像素风主题
//
// 配色取自霓虹 / 合成波（synthwave）体系：近黑底 + 霓虹青主色 + 品红辅助。
// 保留原有语义命名（amber/green/blue…）是为了全项目一处改色、全局生效。

enum Theme {
    // 底色（近黑，带一点蓝，避免纯黑死板）
    static let bg = Color(hex: 0x05060A)
    static let bgTop = Color(hex: 0x0A0E16)
    static let surf = Color(hex: 0x0B1018)
    static let surf2 = Color(hex: 0x111A26)

    // 描边统一走青色系，透明度做出「荧光管」层次
    static let line = Color(hex: 0x00F0FF, alpha: 0.16)
    static let lineStrong = Color(hex: 0x00F0FF, alpha: 0.34)

    // 主色：霓虹青
    static let amber = Color(hex: 0x00F0FF)
    static let amberDeep = Color(hex: 0x00A8C0)

    // 文字层级
    static let t1 = Color(hex: 0xDFFBFF)
    static let t2 = Color(hex: 0x8AA6BC)
    static let t3 = Color(hex: 0x4A5C70)

    // 语义色（赛博化）
    static let green = Color(hex: 0x39FF14)
    static let blue = Color(hex: 0x38BDF8)
    static let purple = Color(hex: 0xB14AF7)
    static let pink = Color(hex: 0xFF2E97)
    static let orange = Color(hex: 0xFF8A00)
    static let red = Color(hex: 0xFF2E4C)
    static let yellow = Color(hex: 0xF9F002)

    // 心电图专用
    static let ecgLine = Color(hex: 0x39FF14)
    static let ecgGrid = Color(hex: 0x00F0FF, alpha: 0.10)

    static func thermalColor(_ level: Double) -> Color {
        switch level {
        case ..<38: return green
        case ..<43: return yellow
        case ..<48: return orange
        default: return red
        }
    }
}

// MARK: - 像素字体
//
// Silkscreen（OFL 1.1，可商用内嵌）只有拉丁字形，中文由 CoreText 自动回落到系统字体。
// 因此数字、英文、单位走 Px.n / Px.nb，中文标签走 Px.cn，避免行高错乱。

enum Px {
    static let regular = "Silkscreen-Regular"
    static let bold = "Silkscreen-Bold"

    /// 首次访问时主动注册字体并检测是否可用。
    /// 不依赖 Info.plist 的 UIAppFonts 是否配对路径：找不到就整体降级为系统等宽字，
    /// 这样最坏情况只是「不够像素」，绝不会出现空白或崩溃。
    static let pixelOK: Bool = {
        let subs: [String?] = [nil, "Fonts", "Resources/Fonts"]
        for name in [Px.regular, Px.bold] {
            for sub in subs {
                if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: sub) {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
        return UIFont(name: Px.regular, size: 12) != nil
    }()

    private static func pixel(_ name: String, _ size: CGFloat) -> Font? {
        guard pixelOK, UIFont(name: name, size: size) != nil else { return nil }
        return .custom(name, size: size)
    }

    /// 数字 / 英文 / 单位（像素字形）
    static func n(_ size: CGFloat) -> Font {
        pixel(regular, size) ?? .system(size: size, weight: .medium, design: .monospaced)
    }
    /// 数字 / 英文加粗
    static func nb(_ size: CGFloat) -> Font {
        pixel(bold, size) ?? .system(size: size, weight: .bold, design: .monospaced)
    }
    /// 中文标签：系统字 + 加大字重，配合字距做出「点阵标题」观感
    static func cn(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - 像素面板

/// 四角 L 形描边，HUD / 终端界面的标志性装饰
struct PixelCorners: View {
    var color: Color = Theme.lineStrong
    var len: CGFloat = 9

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            Path { p in
                // 左上
                p.move(to: CGPoint(x: 0, y: len))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: len, y: 0))
                // 右上
                p.move(to: CGPoint(x: w - len, y: 0))
                p.addLine(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: len))
                // 左下
                p.move(to: CGPoint(x: 0, y: h - len))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: len, y: h))
                // 右下
                p.move(to: CGPoint(x: w - len, y: h))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w, y: h - len))
            }
            .stroke(color, lineWidth: 1.2)
        }
    }
}

/// 像素卡片：直角 + 细描边 + 四角装饰 + 左上高光
struct CardStyle: ViewModifier {
    var radius: CGFloat = 20          // 保留参数以兼容旧调用，实际不使用（像素风一律直角）
    var border: Color = Theme.line
    var corners: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Theme.surf
                    LinearGradient(
                        colors: [Theme.amber.opacity(0.045), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                }
            )
            .clipShape(Rectangle())
            .overlay(Rectangle().stroke(border, lineWidth: 1))
            .overlay {
                if corners {
                    PixelCorners(color: Theme.amber.opacity(0.42))
                }
            }
    }
}

extension View {
    func card(radius: CGFloat = 20, border: Color = Theme.line, corners: Bool = true) -> some View {
        modifier(CardStyle(radius: radius, border: border, corners: corners))
    }
}

// MARK: - 全局背景

/// 近黑底 + 点阵网格 + 顶部青色辉光 + CRT 扫描线
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bg

            // 点阵网格
            Canvas { ctx, size in
                var p = Path()
                let step: CGFloat = 16
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        p.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                        x += step
                    }
                    y += step
                }
                ctx.fill(p, with: .color(Theme.amber.opacity(0.11)))
            }
            .drawingGroup()

            // 顶部青色辉光
            RadialGradient(
                colors: [Theme.amber.opacity(0.10), .clear],
                center: .init(x: 0.5, y: -0.02),
                startRadius: 0,
                endRadius: 440
            )

            // 底部品红辉光
            RadialGradient(
                colors: [Theme.pink.opacity(0.07), .clear],
                center: .init(x: 0.5, y: 1.04),
                startRadius: 0,
                endRadius: 400
            )

            // CRT 扫描线
            Canvas { ctx, size in
                var p = Path()
                var y: CGFloat = 0
                while y < size.height {
                    p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                    y += 4
                }
                ctx.fill(p, with: .color(.black.opacity(0.22)))
            }
            .drawingGroup()
            .opacity(0.55)
        }
        .ignoresSafeArea()
    }
}
