import SwiftUI

// MARK: - Theme Names matching eacc-screen/packages/shared/src/constants.ts

enum EACCThemeName: String, CaseIterable, Codable {
    case cyber       // 攻殻機動隊 — Ghost in the Shell
    case matrix      // 母体代码 — Matrix Code
    case amber       // 琥珀 — Amber
    case voidTheme = "void" // 虚無 — The Void

    var label: String {
        switch self {
        case .cyber: return "攻殻機動隊"
        case .matrix: return "母体代码"
        case .amber: return "琥珀"
        case .voidTheme: return "虚無"
        }
    }

    var subtitle: String {
        switch self {
        case .cyber: return "Ghost in the Shell"
        case .matrix: return "Matrix Code"
        case .amber: return "Amber"
        case .voidTheme: return "The Void"
        }
    }

    var defaultPersona: CompanionPersona {
        switch self {
        case .cyber: return .laughingMan
        case .matrix: return .matrixAgent
        case .amber: return .amberEye
        case .voidTheme: return .voidMonolith
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
        case .amber:
            return EACCThemeColors(
                bg: Color(red: 0.03, green: 0.035, blue: 0.06),
                cardBg: Color(red: 0.09, green: 0.07, blue: 0.06),
                cardBorder: Color(red: 0.87, green: 0.69, blue: 0.44).opacity(0.15),
                accent: Color(red: 0.91, green: 0.57, blue: 0.16),
                accentEdge: Color(red: 0.49, green: 0.05, blue: 0.05),
                textPrimary: Color(red: 0.96, green: 0.92, blue: 0.86),
                textSecondary: Color(red: 0.81, green: 0.71, blue: 0.61),
                textMuted: Color(red: 0.59, green: 0.50, blue: 0.40)
            )
        case .voidTheme:
            return EACCThemeColors(
                bg: Color(red: 0.96, green: 0.96, blue: 0.94),
                cardBg: Color(red: 0.93, green: 0.93, blue: 0.91),
                cardBorder: Color.black.opacity(0.08),
                accent: Color(red: 0.1, green: 0.1, blue: 0.1),
                accentEdge: Color(red: 0.4, green: 0.4, blue: 0.4),
                textPrimary: Color(red: 0.1, green: 0.1, blue: 0.1),
                textSecondary: Color(red: 0.4, green: 0.4, blue: 0.4),
                textMuted: Color(red: 0.6, green: 0.6, blue: 0.6)
            )
        }
    }
}

// MARK: - Blade Runner Pet View — レプリカント (Replicant)
// Organic almond eye with amber iris, radial striations, dilating pupil.
// Inspired by Blade Runner's Voight-Kampff close-ups — alive, warm, watching.
// Eye openness changes with mood like the Voight-Kampff measuring emotional response.

struct BladeRunnerPetView: View {
    let mood: CompanionMood
    let accent: Color
    var motionScale: CGFloat = 1.0

    @State private var isFloating = false

    private let amber = Color(red: 0.91, green: 0.57, blue: 0.16)
    private let deepAmber = Color(red: 0.69, green: 0.35, blue: 0.09)

    var body: some View {
        ZStack {
            // Warm ambient glow
            Circle()
                .fill(amber.opacity(glowLevel))
                .frame(width: 100, height: 100)
                .blur(radius: 16)

            // Canvas-rendered organic eye
            Canvas { context, size in
                drawEye(&context, size)
            }
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 * motionScale : 3 * motionScale)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }

    private var glowLevel: Double {
        switch mood {
        case .feasting: return 0.22
        case .alert: return 0.16
        case .expecting: return 0.10
        case .dozing: return 0.06
        case .sleeping: return 0.03
        }
    }

    private var faceAlpha: Double {
        switch mood {
        case .feasting: return 0.95
        case .alert: return 0.85
        case .expecting: return 0.70
        case .dozing: return 0.45
        case .sleeping: return 0.25
        }
    }

    private var pupilR: CGFloat {
        switch mood {
        case .feasting: return 26
        case .alert: return 22
        case .expecting: return 18
        case .dozing: return 14
        case .sleeping: return 10
        }
    }

    // How open the eye is — controls the curvature of upper/lower lids
    private var openness: CGFloat {
        switch mood {
        case .feasting: return 1.0
        case .alert: return 0.88
        case .expecting: return 0.72
        case .dozing: return 0.35
        case .sleeping: return 0.12
        }
    }

    // All coordinates in 300×300 base space, scaled to actual size.
    private func drawEye(_ context: inout GraphicsContext, _ size: CGSize) {
        let s = min(size.width, size.height)
        let sc = s / 300.0
        let cx = s / 2
        let cy = s / 2
        let o = openness

        // Build almond eye path
        var eyePath = Path()
        eyePath.move(to: CGPoint(x: cx - 105.0 * sc, y: cy))
        eyePath.addCurve(
            to: CGPoint(x: cx + 105.0 * sc, y: cy),
            control1: CGPoint(x: cx - 40.0 * sc, y: cy - 72.0 * o * sc),
            control2: CGPoint(x: cx + 40.0 * sc, y: cy - 72.0 * o * sc))
        eyePath.addCurve(
            to: CGPoint(x: cx - 105.0 * sc, y: cy),
            control1: CGPoint(x: cx + 40.0 * sc, y: cy + 72.0 * o * sc),
            control2: CGPoint(x: cx - 40.0 * sc, y: cy + 72.0 * o * sc))
        eyePath.closeSubpath()

        // Clipped layer: iris, pupil, highlights all inside the eye shape
        context.drawLayer { ec in
            ec.opacity = faceAlpha
            ec.clip(to: eyePath)

            // Sclera (dark warm tone)
            ec.fill(
                Path(ellipseIn: CGRect(x: cx - 130.0 * sc, y: cy - 130.0 * sc,
                                       width: 260.0 * sc, height: 260.0 * sc)),
                with: .color(Color(red: 0.12, green: 0.08, blue: 0.04)))

            // Iris circle
            let iR = 52.0
            ec.fill(
                Path(ellipseIn: CGRect(x: cx - iR * sc, y: cy - iR * sc,
                                       width: iR * 2.0 * sc, height: iR * 2.0 * sc)),
                with: .color(amber.opacity(0.65)))

            // Iris striations (radial lines — the organic detail)
            for i in 0..<16 {
                let angle = Double(i) * 22.5 * .pi / 180.0
                var line = Path()
                line.move(to: CGPoint(
                    x: cx + 16.0 * sc * cos(angle),
                    y: cy + 16.0 * sc * sin(angle)))
                line.addLine(to: CGPoint(
                    x: cx + 50.0 * sc * cos(angle),
                    y: cy + 50.0 * sc * sin(angle)))
                ec.stroke(line, with: .color(deepAmber.opacity(0.5)), lineWidth: 1.2 * sc)
            }

            // Iris border ring
            ec.stroke(
                Path(ellipseIn: CGRect(x: cx - iR * sc, y: cy - iR * sc,
                                       width: iR * 2.0 * sc, height: iR * 2.0 * sc)),
                with: .color(deepAmber.opacity(0.8)), lineWidth: 2.0 * sc)

            // Pupil (dilates with mood)
            let pR = pupilR
            ec.fill(
                Path(ellipseIn: CGRect(x: cx - pR * sc, y: cy - pR * sc,
                                       width: pR * 2.0 * sc, height: pR * 2.0 * sc)),
                with: .color(.black))

            // Specular highlights (city lights reflected in the replicant's eye)
            ec.fill(
                Path(ellipseIn: CGRect(x: cx - 8.0 * sc, y: cy - 12.0 * sc,
                                       width: 7.0 * sc, height: 7.0 * sc)),
                with: .color(.white.opacity(0.5)))
            ec.fill(
                Path(ellipseIn: CGRect(x: cx + 5.0 * sc, y: cy + 4.0 * sc,
                                       width: 4.0 * sc, height: 4.0 * sc)),
                with: .color(.white.opacity(0.2)))
        }

        // Eye outline (unclipped — always visible)
        context.drawLayer { oc in
            oc.opacity = faceAlpha
            oc.stroke(eyePath, with: .color(amber.opacity(0.6)), lineWidth: 1.5 * sc)
        }
    }
}

// MARK: - Matrix Pet View — 母体代码 (Matrix Code)
// Pure Matrix treatment: terminal glass, falling glyphs, scanline, and machine-green glow.
// No eye metaphor here; the pet reads like a shard of the code itself.

struct MatrixPetView: View {
    let mood: CompanionMood
    let accent: Color
    var motionScale: CGFloat = 1.0

    @State private var isFloating = false
    @State private var isGlowing = false

    private let green = Color(red: 0, green: 1.0, blue: 0.25)
    private static let glyphs = ["0", "1", "7", "3", "マ", "ト", "リ", "ク", "ス", "電", "脈", "碼"]
    private static let columnCount = 10
    private static let trailLength = 9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // Keep only a tiny atmospheric core, not a visible silhouette.
                Circle()
                    .fill(green.opacity((glowLevel * 0.04) + (isGlowing ? 0.004 : 0)))
                    .frame(width: 44, height: 44)
                    .blur(radius: 10)

                Canvas { context, size in
                    drawMatrixCode(&context, size, time: time)
                }
                .frame(width: 94, height: 94)

                scanline(time: time)
                    .frame(width: 88)
            }
            .frame(width: 108, height: 108)
            .offset(y: isFloating ? -3 * motionScale : 3 * motionScale)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    private func scanline(time: TimeInterval) -> some View {
        let phase = CGFloat((sin(time * 1.45) + 1) * 0.5)
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        green.opacity(0.12 * screenOpacity),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 10)
            .blur(radius: 4)
            .offset(y: -24 + phase * 48)
    }

    private var glowLevel: Double {
        switch mood {
        case .feasting: return 0.24
        case .alert: return 0.18
        case .expecting: return 0.12
        case .dozing: return 0.06
        case .sleeping: return 0.03
        }
    }

    private var screenOpacity: Double {
        switch mood {
        case .feasting: return 1.0
        case .alert: return 0.86
        case .expecting: return 0.68
        case .dozing: return 0.42
        case .sleeping: return 0.24
        }
    }

    private func drawMatrixCode(_ context: inout GraphicsContext, _ size: CGSize, time: TimeInterval) {
        let font = Font.system(size: 10.5, weight: .semibold, design: .monospaced)
        let width = size.width
        let height = size.height
        let stepX = width / CGFloat(Self.columnCount + 1)
        let stepY: CGFloat = 10

        for column in 0..<Self.columnCount {
            let drift = CGFloat(sin(time * 0.55 + Double(column) * 0.7)) * 2.4
            let x = stepX * CGFloat(column + 1) + drift
            let speed = 20.0 + Double(column % 4) * 4.0
            let seed = Double(column) * 0.37
            let headY = CGFloat((time * speed + seed * 40).truncatingRemainder(dividingBy: Double(height + 28)) - 20)

            for trail in 0..<Self.trailLength {
                let y = headY - CGFloat(trail) * stepY
                guard y > -16, y < height + 10 else { continue }

                let glyphIndex = Int((time * 8) + Double(column * 5 + trail * 11)) % Self.glyphs.count
                let glyph = Self.glyphs[glyphIndex]
                let alphaBase = max(0.12, 1.0 - (Double(trail) * 0.18))
                let alpha = alphaBase * screenOpacity
                let glowAlpha = alpha * (trail == 0 ? 0.34 : 0.16)
                let color: Color = trail == 0
                    ? .white.opacity(min(0.78, alpha + 0.10))
                    : green.opacity(alpha * 0.72)

                var bloom = context.resolve(Text(glyph).font(font))
                bloom.shading = .color(green.opacity(glowAlpha))
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: trail == 0 ? 3.2 : 1.8))
                    layer.draw(bloom, at: CGPoint(x: x, y: y), anchor: .center)
                }

                var resolved = context.resolve(Text(glyph).font(font))
                resolved.shading = .color(color)
                context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)

                if trail == 0 {
                    var specular = context.resolve(Text(glyph).font(font))
                    specular.shading = .color(Color.white.opacity(0.22 * screenOpacity))
                    context.draw(specular, at: CGPoint(x: x - 0.35, y: y - 0.45), anchor: .center)

                    var glow = context.resolve(Text(glyph).font(font))
                    glow.shading = .color(green.opacity(0.28 * screenOpacity))
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: 2.6))
                        layer.draw(glow, at: CGPoint(x: x, y: y), anchor: .center)
                    }
                } else if trail <= 2 {
                    var ghost = context.resolve(Text(glyph).font(font))
                    ghost.shading = .color(green.opacity(0.08 * screenOpacity))
                    context.draw(ghost, at: CGPoint(x: x, y: y + 0.8), anchor: .center)
                }
            }
        }

        let noiseRows = [14.0, 29.0, 52.0, 70.0]
        for (index, row) in noiseRows.enumerated() {
            let widthFactor = CGFloat(0.22 + (Double(index) * 0.12))
            let noiseWidth = width * widthFactor
            let phase = CGFloat((sin(time * (0.9 + Double(index) * 0.35)) + 1) * 0.5)
            let x = 8 + phase * max(8, width - noiseWidth - 16)

            let noiseRect = CGRect(x: x, y: row, width: noiseWidth, height: 1)
            context.fill(Path(noiseRect), with: .color(green.opacity(0.04 * screenOpacity)))
        }
    }
}

// MARK: - Void Pet View — モノリス (Monolith)
// The 2001 monolith: cosmic catalyst for evolution, mathematically perfect.
// Dark space viewport with starfield, the monolith (4:9 face of 1:4:9),
// inner light line, and Star Gate color hints at the edges.
// The monolith doesn't float — it is still, imposing, absolute. Only breathes.

struct VoidPetView: View {
    let mood: CompanionMood
    let accent: Color
    var motionScale: CGFloat = 1.0

    @State private var isBreathing = false
    @State private var starTwinkle = false

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let alpha: Double
    }

    // Pre-computed starfield (deterministic positions)
    private static let stars: [Star] = {
        let positions: [(CGFloat, CGFloat)] = [
            (-40, -36), (-33, -16), (-42, 10), (-36, 30), (-28, -40),
            (40, -33), (36, -10), (42, 16), (33, 36), (28, -46),
            (-18, -44), (20, -42), (-44, -4), (44, 4),
            (-23, 40), (26, 42), (0, -46), (0, 44)
        ]
        return positions.enumerated().map { (i, pos) in
            Star(x: pos.0, y: pos.1,
                 size: i % 3 == 0 ? 2.0 : 1.5,
                 alpha: 0.3 + Double(i % 5) * 0.12)
        }
    }()

    var body: some View {
        ZStack {
            // Space viewport (dark circle — the cosmic void)
            Circle()
                .fill(Color(red: 0.02, green: 0.02, blue: 0.05))
                .frame(width: 94, height: 94)

            // Starfield
            ForEach(0..<Self.stars.count, id: \.self) { i in
                let star = Self.stars[i]
                Circle()
                    .fill(Color.white.opacity(star.alpha * starAlpha))
                    .frame(width: star.size, height: star.size)
                    .offset(x: star.x, y: star.y)
                    .opacity(starTwinkle && i % 3 == 0 ? 0.3 : 1.0)
            }

            // Edge glow — Star Gate color hints (violet/blue emanation)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [edgeColor.opacity(edgeGlowAlpha), .clear],
                        startPoint: .leading, endPoint: .trailing))
                .frame(width: 8, height: 58)
                .offset(x: -16)
                .blur(radius: 4)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, edgeColor.opacity(edgeGlowAlpha)],
                        startPoint: .leading, endPoint: .trailing))
                .frame(width: 8, height: 58)
                .offset(x: 16)
                .blur(radius: 4)

            // Monolith shadow
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 30, height: 65)
                .blur(radius: 8)
                .offset(y: 4)

            // Monolith body (28×63 = 4:9 ratio, the front face of 1:4:9)
            Rectangle()
                .fill(Color(red: 0.04, green: 0.04, blue: 0.04))
                .frame(width: 28, height: 63)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                .scaleEffect(isBreathing ? (1.0 + 0.02 * motionScale) : 1.0)

            // Inner light line (the monolith's intelligence)
            Rectangle()
                .fill(centerLineColor.opacity(centerLineAlpha))
                .frame(width: 1, height: 50)
                .blur(radius: 2)

            // Apex light (the Star Gate threshold — benevolent, not HAL-like)
            Circle()
                .fill(apexColor)
                .frame(width: 5, height: 5)
                .opacity(apexOpacity)
                .offset(y: -18)
                .shadow(color: apexColor.opacity(0.4), radius: 4)
        }
        .frame(width: 108, height: 108)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                starTwinkle = true
            }
        }
    }

    private var starAlpha: Double {
        switch mood {
        case .feasting: return 1.0
        case .alert: return 0.8
        case .expecting: return 0.6
        case .dozing: return 0.3
        case .sleeping: return 0.1
        }
    }

    private var centerLineAlpha: Double {
        switch mood {
        case .feasting: return 0.5
        case .alert: return 0.35
        case .expecting: return 0.2
        case .dozing: return 0.08
        case .sleeping: return 0.0
        }
    }

    private var centerLineColor: Color {
        switch mood {
        case .feasting, .alert: return Color(red: 0.7, green: 0.8, blue: 1.0)
        case .expecting, .dozing, .sleeping: return .white
        }
    }

    private var edgeColor: Color {
        switch mood {
        case .feasting: return Color(red: 0.4, green: 0.3, blue: 0.9)
        case .alert: return Color(red: 0.3, green: 0.4, blue: 0.8)
        case .expecting, .dozing, .sleeping: return Color(red: 0.5, green: 0.5, blue: 0.7)
        }
    }

    private var edgeGlowAlpha: Double {
        switch mood {
        case .feasting: return 0.35
        case .alert: return 0.25
        case .expecting: return 0.15
        case .dozing: return 0.0
        case .sleeping: return 0.0
        }
    }

    private var apexOpacity: Double {
        switch mood {
        case .feasting: return 1.0
        case .alert: return 0.8
        case .expecting: return 0.5
        case .dozing: return 0.15
        case .sleeping: return 0.0
        }
    }

    private var apexColor: Color {
        switch mood {
        case .feasting: return Color(red: 0.85, green: 0.9, blue: 1.0)
        case .alert: return Color(red: 0.7, green: 0.8, blue: 0.95)
        case .expecting: return Color(red: 0.6, green: 0.7, blue: 0.8)
        case .dozing, .sleeping: return .white
        }
    }
}
