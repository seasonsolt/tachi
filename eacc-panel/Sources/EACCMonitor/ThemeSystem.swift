import SwiftUI

// MARK: - Theme Names matching eacc-screen/packages/shared/src/constants.ts

enum EACCThemeName: String, CaseIterable, Codable {
    case cyber       // 攻殻機動隊 — Ghost in the Shell
    case bladerunner // 銀翼殺手 — Blade Runner
    case matrix      // 黑客帝國 — The Matrix
    case blood       // 血色祭壇 — Blood Altar (NERV)
    case singularity // 奇点 — The Singularity

    var label: String {
        switch self {
        case .cyber: return "攻殻機動隊"
        case .bladerunner: return "銀翼殺手"
        case .matrix: return "黑客帝國"
        case .blood: return "血色祭壇"
        case .singularity: return "奇点"
        }
    }

    var subtitle: String {
        switch self {
        case .cyber: return "Ghost in the Shell"
        case .bladerunner: return "Blade Runner"
        case .matrix: return "The Matrix"
        case .blood: return "Blood Altar"
        case .singularity: return "The Singularity"
        }
    }

    var defaultPersona: CompanionPersona {
        switch self {
        case .cyber: return .laughingMan
        case .bladerunner: return .bladeRunnerEye
        case .matrix: return .matrixAgent
        case .blood: return .nervHex
        case .singularity: return .singularityVoid
        }
    }
}

// MARK: - Theme Color Palette

struct EACCThemeColors {
    let bg: Color
    let cardBg: Color
    let cardBorder: Color
    let accent: Color
    let accentEdge: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    static func forTheme(_ theme: EACCThemeName) -> EACCThemeColors {
        switch theme {
        case .cyber:
            return EACCThemeColors(
                bg: Color(red: 0.04, green: 0.04, blue: 0.06),
                cardBg: Color(red: 0.08, green: 0.09, blue: 0.11),
                cardBorder: Color.white.opacity(0.08),
                accent: Color(red: 0, green: 0.83, blue: 1.0),
                accentEdge: Color(red: 0.39, green: 0.40, blue: 0.95),
                textPrimary: Color.white.opacity(0.88),
                textSecondary: Color.white.opacity(0.58),
                textMuted: Color.white.opacity(0.38)
            )
        case .bladerunner:
            return EACCThemeColors(
                bg: Color(red: 0.04, green: 0.035, blue: 0.04),
                cardBg: Color(red: 0.09, green: 0.07, blue: 0.06),
                cardBorder: Color(red: 0.87, green: 0.69, blue: 0.44).opacity(0.15),
                accent: Color(red: 0.91, green: 0.57, blue: 0.16),
                accentEdge: Color(red: 0.69, green: 0.35, blue: 0.09),
                textPrimary: Color(red: 0.96, green: 0.92, blue: 0.86),
                textSecondary: Color(red: 0.81, green: 0.71, blue: 0.61),
                textMuted: Color(red: 0.59, green: 0.50, blue: 0.40)
            )
        case .matrix:
            return EACCThemeColors(
                bg: Color.black,
                cardBg: Color(red: 0.04, green: 0.06, blue: 0.04),
                cardBorder: Color(red: 0.46, green: 1.0, blue: 0.61).opacity(0.12),
                accent: Color(red: 0, green: 1.0, blue: 0.25),
                accentEdge: Color(red: 0, green: 0.56, blue: 0.07),
                textPrimary: Color(red: 0.93, green: 1.0, blue: 0.94),
                textSecondary: Color(red: 0.64, green: 0.97, blue: 0.71),
                textMuted: Color(red: 0.38, green: 0.72, blue: 0.46)
            )
        case .blood:
            return EACCThemeColors(
                bg: Color(red: 0.047, green: 0.024, blue: 0.024),
                cardBg: Color(red: 0.09, green: 0.05, blue: 0.05),
                cardBorder: Color(red: 0.84, green: 0.60, blue: 0.58).opacity(0.12),
                accent: Color(red: 0.84, green: 0.12, blue: 0.12),
                accentEdge: Color(red: 0.49, green: 0.05, blue: 0.05),
                textPrimary: Color(red: 0.94, green: 0.89, blue: 0.87),
                textSecondary: Color(red: 0.82, green: 0.69, blue: 0.67),
                textMuted: Color(red: 0.61, green: 0.48, blue: 0.47)
            )
        case .singularity:
            return EACCThemeColors(
                bg: Color.black,
                cardBg: Color(red: 0.06, green: 0.06, blue: 0.06),
                cardBorder: Color.white.opacity(0.1),
                accent: Color.white,
                accentEdge: Color(red: 0.53, green: 0.53, blue: 0.53),
                textPrimary: Color.white,
                textSecondary: Color(red: 0.63, green: 0.63, blue: 0.63),
                textMuted: Color(red: 0.4, green: 0.4, blue: 0.4)
            )
        }
    }
}

// MARK: - Blade Runner Pet View (Voight-Kampff Eye)

struct BladeRunnerPetView: View {
    let mood: CompanionMood
    let accent: Color

    @State private var isFloating = false
    @State private var isScanning = false
    @State private var irisScale = false

    private let amber = Color(red: 0.91, green: 0.57, blue: 0.16)
    private let deepAmber = Color(red: 0.69, green: 0.35, blue: 0.09)

    var body: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(amber.opacity(0.12))
                .frame(width: 96, height: 96)
                .blur(radius: 12)

            // Outer scan ring
            Circle()
                .stroke(amber.opacity(0.25), lineWidth: 1)
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(isScanning ? 360 : 0))
                .overlay(alignment: .top) {
                    Circle()
                        .fill(amber.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .offset(y: -2)
                }

            // Tick marks
            ForEach(0..<12, id: \.self) { i in
                Rectangle()
                    .fill(amber.opacity(0.35))
                    .frame(width: 1, height: 6)
                    .offset(y: -38)
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Inner scan ring
            Circle()
                .stroke(amber.opacity(0.4), lineWidth: 1.5)
                .frame(width: 62, height: 62)
                .rotationEffect(.degrees(isScanning ? -360 : 0))

            // Iris
            Circle()
                .fill(
                    RadialGradient(
                        colors: [amber, deepAmber, .black],
                        center: .center,
                        startRadius: 4,
                        endRadius: 24
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(amber.opacity(0.6), lineWidth: 1))
                .scaleEffect(irisScale ? 1.08 : 0.95)

            // Pupil
            Circle()
                .fill(.black)
                .frame(width: pupilSize, height: pupilSize)
                .overlay(
                    Circle()
                        .fill(amber.opacity(0.3))
                        .frame(width: 4, height: 4)
                        .offset(x: -3, y: -3)
                )

            // Crosshair
            Rectangle()
                .fill(amber.opacity(0.2))
                .frame(width: 0.5, height: 92)
            Rectangle()
                .fill(amber.opacity(0.2))
                .frame(width: 92, height: 0.5)

            // Scanning line
            Rectangle()
                .fill(amber.opacity(0.5))
                .frame(width: 1.5, height: 44)
                .offset(y: -22)
                .rotationEffect(.degrees(isScanning ? 360 : 0))
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isFloating = true
                irisScale = true
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                isScanning = true
            }
        }
    }

    private var pupilSize: CGFloat {
        switch mood {
        case .feasting: return 16
        case .alert: return 14
        case .expecting: return 12
        case .dozing: return 8
        case .sleeping: return 6
        }
    }
}

// MARK: - Matrix Pet View (Digital Code Entity)

struct MatrixPetView: View {
    let mood: CompanionMood
    let accent: Color

    @State private var isFloating = false
    @State private var isGlowing = false

    private let green = Color(red: 0, green: 1.0, blue: 0.25)

    private static let glyphs = ["ア", "ウ", "カ", "キ", "ネ", "ノ", "ワ", "ン"]

    var body: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(green.opacity(isGlowing ? 0.18 : 0.08))
                .frame(width: 98, height: 98)
                .blur(radius: 14)

            // Orbiting characters
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45
                let radius: CGFloat = 42
                Text(Self.glyphs[i])
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(green.opacity(charOpacity(i)))
                    .offset(
                        x: radius * cos(angle * .pi / 180),
                        y: radius * sin(angle * .pi / 180)
                    )
            }

            // Core orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [green.opacity(0.9), green.opacity(0.3), .black],
                        center: .center,
                        startRadius: 2,
                        endRadius: coreRadius
                    )
                )
                .frame(width: coreRadius * 2, height: coreRadius * 2)

            // Inner pulse ring
            Circle()
                .stroke(green.opacity(0.5), lineWidth: 1)
                .frame(width: 30, height: 30)
                .scaleEffect(isGlowing ? 1.3 : 1.0)
                .opacity(isGlowing ? 0 : 1)

            // Core glyph
            Text(coreGlyph)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(green)
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    private var coreRadius: CGFloat {
        switch mood {
        case .feasting: return 22
        case .alert: return 20
        case .expecting: return 18
        case .dozing: return 15
        case .sleeping: return 12
        }
    }

    private var coreGlyph: String {
        switch mood {
        case .feasting: return "覚"
        case .alert: return "見"
        case .expecting: return "待"
        case .dozing: return "夢"
        case .sleeping: return "眠"
        }
    }

    private func charOpacity(_ index: Int) -> Double {
        let base: Double
        switch mood {
        case .feasting: base = 0.8
        case .alert: base = 0.6
        case .expecting: base = 0.45
        case .dozing: base = 0.25
        case .sleeping: base = 0.12
        }
        return base * (1.0 - Double(index) * 0.06)
    }
}

// MARK: - NERV Hex Pet View (Evangelion / Blood Altar)

struct NervHexPetView: View {
    let mood: CompanionMood
    let accent: Color

    @State private var isFloating = false
    @State private var isPulsing = false

    private let nervRed = Color(red: 0.84, green: 0.12, blue: 0.12)
    private let nervDark = Color(red: 0.49, green: 0.05, blue: 0.05)

    var body: some View {
        ZStack {
            // Red ambient glow
            Circle()
                .fill(nervRed.opacity(isPulsing ? 0.16 : 0.06))
                .frame(width: 96, height: 96)
                .blur(radius: 12)

            // Outer hexagon
            HexagonShape()
                .stroke(nervRed.opacity(0.35), lineWidth: 1.5)
                .frame(width: 86, height: 86)

            // Middle hexagon
            HexagonShape()
                .stroke(nervRed.opacity(0.25), lineWidth: 1)
                .frame(width: 66, height: 66)

            // Inner hexagon filled
            HexagonShape()
                .fill(nervRed.opacity(faceOpacity * 0.3))
                .frame(width: 48, height: 48)

            // NERV leaf
            Canvas { context, size in
                drawNervLeaf(&context, size)
            }
            .frame(width: 40, height: 40)

            // Warning stripe marks at hex vertices
            ForEach(0..<6, id: \.self) { i in
                Rectangle()
                    .fill(nervRed.opacity(0.3))
                    .frame(width: 3, height: 10)
                    .offset(y: -42)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var faceOpacity: Double {
        switch mood {
        case .feasting: return 0.95
        case .alert: return 0.8
        case .expecting: return 0.65
        case .dozing: return 0.45
        case .sleeping: return 0.25
        }
    }

    private func drawNervLeaf(_ context: inout GraphicsContext, _ size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2
        let s = min(size.width, size.height) / 2

        // Leaf shape
        var leaf = Path()
        leaf.move(to: CGPoint(x: cx, y: cy - s * 0.9))
        leaf.addCurve(
            to: CGPoint(x: cx + s * 0.45, y: cy + s * 0.6),
            control1: CGPoint(x: cx + s * 0.55, y: cy - s * 0.4),
            control2: CGPoint(x: cx + s * 0.55, y: cy + s * 0.2)
        )
        leaf.addLine(to: CGPoint(x: cx, y: cy + s * 0.85))
        leaf.addLine(to: CGPoint(x: cx - s * 0.45, y: cy + s * 0.6))
        leaf.addCurve(
            to: CGPoint(x: cx, y: cy - s * 0.9),
            control1: CGPoint(x: cx - s * 0.55, y: cy + s * 0.2),
            control2: CGPoint(x: cx - s * 0.55, y: cy - s * 0.4)
        )
        leaf.closeSubpath()
        context.fill(leaf, with: .color(nervRed.opacity(faceOpacity)))

        // Center vein
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: cy - s * 0.7))
        stem.addLine(to: CGPoint(x: cx, y: cy + s * 0.65))
        context.stroke(stem, with: .color(nervDark.opacity(faceOpacity)), lineWidth: 1.5)
    }
}

// MARK: - Singularity Pet View (The Void)

struct SingularityPetView: View {
    let mood: CompanionMood
    let accent: Color

    @State private var isFloating = false
    @State private var isWarping = false
    @State private var diskAngle = false

    var body: some View {
        ZStack {
            // Gravitational lensing rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(ringOpacity(i)), lineWidth: 0.5)
                    .frame(
                        width: CGFloat(50 + i * 18),
                        height: CGFloat(50 + i * 18)
                    )
                    .scaleEffect(isWarping ? 1.05 : 0.95)
            }

            // Event horizon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), .white.opacity(0.3), .black],
                        center: .center,
                        startRadius: 2,
                        endRadius: horizonRadius
                    )
                )
                .frame(width: horizonRadius * 2, height: horizonRadius * 2)

            // Void center
            Circle()
                .fill(.black)
                .frame(width: voidCenter, height: voidCenter)

            // Accretion disk
            Ellipse()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: 70, height: 14)
                .rotationEffect(.degrees(diskAngle ? 360 : 0))
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isFloating = true
                isWarping = true
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                diskAngle = true
            }
        }
    }

    private var horizonRadius: CGFloat {
        switch mood {
        case .feasting: return 26
        case .alert: return 23
        case .expecting: return 20
        case .dozing: return 17
        case .sleeping: return 14
        }
    }

    private var voidCenter: CGFloat {
        switch mood {
        case .feasting: return 10
        case .alert: return 12
        case .expecting: return 14
        case .dozing: return 18
        case .sleeping: return 22
        }
    }

    private func ringOpacity(_ index: Int) -> Double {
        let base: Double
        switch mood {
        case .feasting: base = 0.4
        case .alert: base = 0.3
        case .expecting: base = 0.25
        case .dozing: base = 0.15
        case .sleeping: base = 0.08
        }
        return base * (1.0 - Double(index) * 0.15)
    }
}

// MARK: - Hexagon Shape

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(Double(i) * 60.0 - 90.0) * .pi / 180.0
            let point = CGPoint(
                x: center.x + radius * CoreGraphics.cos(angle),
                y: center.y + radius * CoreGraphics.sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
