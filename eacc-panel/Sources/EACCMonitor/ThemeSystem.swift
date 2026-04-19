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

// MARK: - Blade Runner Pet View — 折り紙ユニコーン (Origami Unicorn)
// The origami unicorn is the stronger Blade Runner symbol:
// memory, implanted meaning, and the uneasy line between human and artifact.
// Keep it cold and faceted, with only a little amber city light on the folds.

struct OrigamiUnicornPetView: View {
    let mood: CompanionMood
    let accent: Color
    var hasMotion: Bool = true
    var motionScale: CGFloat = 1.0

    @State private var rotationStartDate = Date()

    private let paperHighlight = Color(red: 0.93, green: 0.94, blue: 0.97)
    private let paperMain = Color(red: 0.64, green: 0.68, blue: 0.74)
    private let paperShade = Color(red: 0.35, green: 0.39, blue: 0.46)
    private let paperDeep = Color(red: 0.10, green: 0.11, blue: 0.14)
    private let amber = Color(red: 0.91, green: 0.57, blue: 0.16)

    var body: some View {
        ZStack {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 72, height: 14)
                    .blur(radius: 6)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.17, blue: 0.20),
                                Color(red: 0.05, green: 0.05, blue: 0.07)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 66, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )

                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 38, height: 2)
                    .offset(y: -2)
            }
            .offset(y: 36)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 18)
                .offset(y: 25)

            Ellipse()
                .fill(Color.black.opacity(shadowOpacity))
                .frame(width: 86, height: 22)
                .blur(radius: 14)
                .offset(x: -2, y: 30)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                ZStack {
                    Ellipse()
                        .fill(accent.opacity(ambientGlowOpacity * 0.22))
                        .frame(width: 74, height: 28)
                        .blur(radius: 16)
                        .offset(x: -6, y: 12)

                    Circle()
                        .fill(amber.opacity(hornGlowOpacity))
                        .frame(width: 18, height: 18)
                        .blur(radius: 12)
                        .offset(x: 22, y: -26)

                    Canvas { context, size in
                        drawOrigamiUnicorn(&context, size)
                    }
                    .offset(x: -1, y: 2)
                }
                .rotation3DEffect(
                    .degrees(rotationDegrees(at: timeline.date)),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.7
                )
            }
        }
        .frame(width: 108, height: 108)
        .onAppear {
            rotationStartDate = .now
        }
        .onChange(of: hasMotion) { _, enabled in
            if enabled {
                rotationStartDate = .now
            }
        }
    }

    private var ambientGlowOpacity: Double {
        switch mood {
        case .feasting: return 0.16
        case .alert: return 0.12
        case .expecting: return 0.08
        case .dozing: return 0.05
        case .sleeping: return 0.02
        }
    }

    private var shadowOpacity: Double {
        switch mood {
        case .feasting: return 0.24
        case .alert: return 0.2
        case .expecting: return 0.16
        case .dozing: return 0.09
        case .sleeping: return 0.04
        }
    }

    private var paperAlpha: Double {
        switch mood {
        case .feasting: return 0.95
        case .alert: return 0.85
        case .expecting: return 0.72
        case .dozing: return 0.45
        case .sleeping: return 0.25
        }
    }

    private var hornGlowOpacity: Double {
        switch mood {
        case .feasting: return 0.28
        case .alert: return 0.18
        case .expecting: return 0.10
        case .dozing: return 0.04
        case .sleeping: return 0.0
        }
    }

    private var eyeOpacity: Double {
        switch mood {
        case .feasting: return 0.95
        case .alert: return 0.8
        case .expecting: return 0.55
        case .dozing: return 0.22
        case .sleeping: return 0.08
        }
    }

    private func rotationDegrees(at date: Date) -> Double {
        guard hasMotion else { return 0 }

        let elapsed = max(0, date.timeIntervalSince(rotationStartDate))
        return (elapsed / 20.0) * 360.0
    }

    private func drawOrigamiUnicorn(_ context: inout GraphicsContext, _ size: CGSize) {
        let s = min(size.width, size.height)
        let sc = s / 300.0
        let cx = s / 2
        let cy = s / 2
        let strokeWidth = max(0.75, 1.35 * sc)

        let tail = polygon(
            [(86, 132), (42, 118), (78, 146)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let hindQuarter = polygon(
            [(86, 120), (124, 120), (138, 160), (98, 178), (70, 144)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let torso = polygon(
            [(122, 122), (176, 110), (228, 126), (214, 160), (160, 174), (126, 154)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let belly = polygon(
            [(132, 154), (162, 172), (196, 166), (176, 196), (142, 196), (118, 176)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let chest = polygon(
            [(120, 142), (146, 144), (150, 190), (116, 186), (106, 166)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let mane = polygon(
            [(122, 136), (134, 96), (154, 134), (140, 156)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let neck = polygon(
            [(136, 138), (146, 64), (172, 64), (176, 132), (154, 154), (132, 148)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let head = polygon(
            [(166, 64), (194, 56), (214, 74), (206, 102), (178, 104), (164, 88)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let muzzle = polygon(
            [(194, 60), (230, 68), (212, 96), (188, 92)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let ear = polygon(
            [(170, 62), (176, 34), (188, 60)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let horn = polygon(
            [(182, 42), (192, 4), (200, 46)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let frontRearLeg = polygon(
            [(120, 188), (136, 148), (150, 152), (140, 258), (118, 252)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let frontFrontLeg = polygon(
            [(142, 190), (154, 148), (170, 150), (162, 260), (140, 254)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let hindRearLeg = polygon(
            [(164, 170), (182, 150), (196, 158), (184, 250), (160, 244)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )
        let hindFrontLeg = polygon(
            [(190, 166), (218, 150), (234, 166), (216, 252), (190, 246)],
            scale: sc,
            centerX: cx,
            centerY: cy
        )

        context.drawLayer { uc in
            uc.opacity = paperAlpha
            uc.fill(tail, with: .color(paperDeep.opacity(0.92)))
            uc.fill(hindRearLeg, with: .color(paperDeep.opacity(0.96)))
            uc.fill(hindFrontLeg, with: .color(paperShade.opacity(0.95)))
            uc.fill(hindQuarter, with: .color(paperDeep.opacity(0.94)))
            uc.fill(torso, with: .color(paperMain))
            uc.fill(belly, with: .color(paperShade.opacity(0.86)))
            uc.fill(chest, with: .color(paperShade))
            uc.fill(frontRearLeg, with: .color(paperHighlight.opacity(0.98)))
            uc.fill(frontFrontLeg, with: .color(paperMain))
            uc.fill(mane, with: .color(paperDeep.opacity(0.88)))
            uc.fill(neck, with: .color(paperHighlight.opacity(0.96)))
            uc.fill(head, with: .color(paperMain))
            uc.fill(ear, with: .color(paperHighlight.opacity(0.92)))
            uc.fill(muzzle, with: .color(paperHighlight))
            uc.fill(horn, with: .color(paperHighlight))

            uc.stroke(torso, with: .color(Color.white.opacity(0.12)), lineWidth: strokeWidth)
            uc.stroke(belly, with: .color(Color.white.opacity(0.08)), lineWidth: strokeWidth)
            uc.stroke(chest, with: .color(Color.white.opacity(0.12)), lineWidth: strokeWidth)
            uc.stroke(neck, with: .color(Color.white.opacity(0.18)), lineWidth: strokeWidth)
            uc.stroke(head, with: .color(Color.white.opacity(0.16)), lineWidth: strokeWidth)
            uc.stroke(ear, with: .color(Color.white.opacity(0.18)), lineWidth: strokeWidth)
            uc.stroke(muzzle, with: .color(Color.white.opacity(0.22)), lineWidth: strokeWidth)
            uc.stroke(horn, with: .color(Color.white.opacity(0.28)), lineWidth: strokeWidth)

            var spineFold = Path()
            spineFold.move(to: point(134, 124, scale: sc, centerX: cx, centerY: cy))
            spineFold.addLine(to: point(202, 136, scale: sc, centerX: cx, centerY: cy))
            uc.stroke(spineFold, with: .color(paperDeep.opacity(0.6)), lineWidth: strokeWidth)

            var neckFold = Path()
            neckFold.move(to: point(146, 66, scale: sc, centerX: cx, centerY: cy))
            neckFold.addLine(to: point(154, 150, scale: sc, centerX: cx, centerY: cy))
            uc.stroke(neckFold, with: .color(paperShade.opacity(0.7)), lineWidth: strokeWidth)

            var faceFold = Path()
            faceFold.move(to: point(174, 100, scale: sc, centerX: cx, centerY: cy))
            faceFold.addLine(to: point(198, 62, scale: sc, centerX: cx, centerY: cy))
            uc.stroke(faceFold, with: .color(paperDeep.opacity(0.7)), lineWidth: strokeWidth)

            var hipFold = Path()
            hipFold.move(to: point(92, 122, scale: sc, centerX: cx, centerY: cy))
            hipFold.addLine(to: point(126, 158, scale: sc, centerX: cx, centerY: cy))
            uc.stroke(hipFold, with: .color(Color.white.opacity(0.1)), lineWidth: strokeWidth)

            var eye = Path()
            let eyeCenter = point(203, 79, scale: sc, centerX: cx, centerY: cy)
            eye.addEllipse(
                in: CGRect(
                    x: eyeCenter.x - (3.0 * sc),
                    y: eyeCenter.y - (3.0 * sc),
                    width: 6.0 * sc,
                    height: 6.0 * sc
                )
            )
            uc.fill(eye, with: .color(amber.opacity(eyeOpacity)))

            var hornHighlight = Path()
            hornHighlight.move(to: point(187, 40, scale: sc, centerX: cx, centerY: cy))
            hornHighlight.addLine(to: point(192, 8, scale: sc, centerX: cx, centerY: cy))
            uc.stroke(hornHighlight, with: .color(amber.opacity(0.65)), lineWidth: max(0.55, strokeWidth * 0.7))

            var backHighlight = Path()
            backHighlight.move(to: point(138, 123, scale: sc, centerX: cx, centerY: cy))
            backHighlight.addLine(to: point(192, 116, scale: sc, centerX: cx, centerY: cy))
            uc.stroke(backHighlight, with: .color(Color.white.opacity(0.24)), lineWidth: max(0.55, strokeWidth * 0.7))

            var muzzleHighlight = Path()
            muzzleHighlight.move(to: point(202, 70, scale: sc, centerX: cx, centerY: cy))
            muzzleHighlight.addLine(to: point(223, 74, scale: sc, centerX: cx, centerY: cy))
            uc.stroke(muzzleHighlight, with: .color(Color.white.opacity(0.26)), lineWidth: max(0.55, strokeWidth * 0.7))
        }
    }

    private func point(_ x: CGFloat, _ y: CGFloat, scale: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        CGPoint(
            x: centerX + (x - 150.0) * scale,
            y: centerY + (y - 150.0) * scale
        )
    }

    private func polygon(_ points: [(CGFloat, CGFloat)], scale: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: point(first.0, first.1, scale: scale, centerX: centerX, centerY: centerY))
        for point in points.dropFirst() {
            path.addLine(to: self.point(point.0, point.1, scale: scale, centerX: centerX, centerY: centerY))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Matrix Pet View — 母体代码 (Matrix Code)
// Pure Matrix treatment: terminal glass, falling glyphs, scanline, and machine-green glow.
// No eye metaphor here; the pet reads like a shard of the code itself.

struct MatrixPetView: View {
    let mood: CompanionMood
    let accent: Color
    var hasMotion: Bool = true
    var motionScale: CGFloat = 1.0

    @State private var isFloating = false
    @State private var isGlowing = false

    private let green = Color(red: 0, green: 1.0, blue: 0.25)
    private static let glyphs = ["0", "1", "7", "3", "マ", "ト", "リ", "ク", "ス", "電", "脈", "碼"]
    private static let columnCount = 10
    private static let trailLength = 9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { timeline in
            let time = hasMotion ? timeline.date.timeIntervalSinceReferenceDate : 0

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
        .animation(hasMotion ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .easeInOut(duration: 0.2), value: isFloating)
        .onAppear {
            isFloating = hasMotion
            isGlowing = hasMotion
        }
        .onChange(of: hasMotion) { _, enabled in
            isFloating = enabled
            isGlowing = enabled
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
            let speed = 28.0 + Double(column % 4) * 6.0
            let seed = Double(column) * 0.37
            let travel = time * speed + seed * 40
            let cycleSpan = Double(height + 28)
            let cycle = Int(floor(travel / cycleSpan))
            let headY = CGFloat(travel.truncatingRemainder(dividingBy: cycleSpan) - 20)

            for trail in 0..<Self.trailLength {
                let y = headY - CGFloat(trail) * stepY
                guard y > -16, y < height + 10 else { continue }

                let glyphIndex = stableGlyphIndex(column: column, trail: trail, cycle: cycle)
                let glyph = Self.glyphs[glyphIndex]
                let alphaBase = max(0.12, 1.0 - (Double(trail) * 0.18))
                let flicker = glyphFlicker(time: time, column: column, trail: trail, cycle: cycle)
                let alpha = alphaBase * screenOpacity * flicker.alpha
                let glowAlpha = alpha * (trail == 0 ? (0.34 * flicker.glow) : 0.16)
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
                    specular.shading = .color(Color.white.opacity(0.22 * screenOpacity * flicker.glow))
                    context.draw(specular, at: CGPoint(x: x - 0.35, y: y - 0.45), anchor: .center)

                    var glow = context.resolve(Text(glyph).font(font))
                    glow.shading = .color(green.opacity(0.28 * screenOpacity * flicker.glow))
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: 2.6 + (1.2 * flicker.bloom)))
                        layer.draw(glow, at: CGPoint(x: x, y: y), anchor: .center)
                    }
                } else if trail <= 2 {
                    var ghost = context.resolve(Text(glyph).font(font))
                    ghost.shading = .color(green.opacity(0.08 * screenOpacity * flicker.ghost))
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

    private func stableGlyphIndex(column: Int, trail: Int, cycle: Int) -> Int {
        var value = UInt64(truncatingIfNeeded: column &* 73856093)
        value ^= UInt64(truncatingIfNeeded: trail &* 19349663)
        value ^= UInt64(truncatingIfNeeded: cycle &* 83492791)
        value = value &* 1103515245 &+ 12345
        return Int(value % UInt64(Self.glyphs.count))
    }

    private func glyphFlicker(time: TimeInterval, column: Int, trail: Int, cycle: Int) -> (
        alpha: Double, glow: Double, bloom: Double, ghost: Double
    ) {
        let seed = Double(column) * 0.91 + Double(trail) * 1.73 + Double(cycle) * 0.37
        let primary = (sin(time * 6.4 + seed) + 1) * 0.5
        let secondary = (sin(time * 13.2 + seed * 1.9) + 1) * 0.5
        let tertiary = (sin(time * 3.8 + seed * 0.63) + 1) * 0.5

        if trail == 0 {
            return (
                alpha: 0.90 + primary * 0.38 + tertiary * 0.14,
                glow: 1.08 + secondary * 0.72,
                bloom: 0.70 + primary * 1.15,
                ghost: 1.0
            )
        }

        if trail <= 2 {
            return (
                alpha: 0.78 + primary * 0.30 + tertiary * 0.10,
                glow: 0.92 + secondary * 0.34,
                bloom: 0.28 + primary * 0.44,
                ghost: 0.94 + secondary * 0.30
            )
        }

        return (
            alpha: 0.74 + primary * 0.24 + tertiary * 0.08,
            glow: 0.94 + secondary * 0.22,
            bloom: 0.18 + primary * 0.24,
            ghost: 0.88 + secondary * 0.24
        )
    }
}

// MARK: - Monolith Pet View — 石碑 (Monolith)
// Keep the 2001 symbol literal: no cosmic viewport, no halo, no ring.
// Just the slab itself, a bottom shadow, and a faint inner seam when it wakes.

struct MonolithPetView: View {
    let mood: CompanionMood
    let accent: Color
    var hasMotion: Bool = true
    var motionScale: CGFloat = 1.0

    @State private var isBreathing = false

    // Sun/moon geometry — moon is slightly SMALLER than sun
    // so a bright annular ring is visible during totality.
    private let sunRadius: CGFloat = 10
    private let moonRadius: CGFloat = 9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = hasMotion ? timeline.date.timeIntervalSinceReferenceDate : 0

            // Moon transits across the sun over 8 seconds, pauses at center
            let rawCycle = time.truncatingRemainder(dividingBy: 10.0) / 10.0
            // Ease in/out so the moon dwells at totality
            let easedCycle = smootherstep(rawCycle)
            let moonOffset = CGFloat(-16 + (easedCycle * 32))
            let eclipseIntensity = 1.0 - min(1.0, abs(moonOffset) / 12.0)
            let coronaPulse = (sin(time * 1.3) + 1.0) * 0.5

            // Corona grows dramatically during totality
            let coronaScale = 1.0 + (0.3 * eclipseIntensity)
            let coronaRingOpacity = 0.20 + (0.65 * eclipseIntensity) + (0.10 * coronaPulse)
            let coronaHaloOpacity = 0.08 + (0.28 * eclipseIntensity) + (0.06 * coronaPulse)
            let sunCoreOpacity = 0.85 - (0.75 * eclipseIntensity)

            ZStack {
                // --- Eclipse above the slab ---
                ZStack {
                    // Outer halo — large diffuse warm glow
                    Circle()
                        .fill(coronaColor.opacity(coronaHaloOpacity * 0.5))
                        .frame(width: 44, height: 44)
                        .blur(radius: 14)
                        .scaleEffect(coronaScale)

                    // Corona ring — thick, visible during totality
                    Circle()
                        .stroke(
                            coronaColor.opacity(coronaRingOpacity),
                            lineWidth: 2.5 + (2.0 * eclipseIntensity)
                        )
                        .frame(width: sunRadius * 2 + 6, height: sunRadius * 2 + 6)
                        .blur(radius: 0.6 + (0.8 * eclipseIntensity))
                        .scaleEffect(coronaScale)

                    // Outer corona streamer ring
                    Circle()
                        .stroke(
                            coronaColor.opacity(coronaRingOpacity * 0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: sunRadius * 2 + 14, height: sunRadius * 2 + 14)
                        .blur(radius: 2.5)
                        .scaleEffect(coronaScale)

                    // Sun core — bright warm disc
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(sunCoreOpacity),
                                    Color.white.opacity(sunCoreOpacity * 0.7)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: sunRadius
                            )
                        )
                        .frame(width: sunRadius * 2, height: sunRadius * 2)

                    // Sun limb — bright edge ring
                    Circle()
                        .stroke(Color.white.opacity(0.20 + (0.15 * eclipseIntensity)), lineWidth: 0.8)
                        .frame(width: sunRadius * 2 + 1, height: sunRadius * 2 + 1)

                    // Moon disc — slightly smaller, transiting
                    Circle()
                        .fill(Color(red: 0.03, green: 0.03, blue: 0.04))
                        .frame(width: moonRadius * 2, height: moonRadius * 2)
                        .offset(x: moonOffset)
                }
                .offset(y: -42)

                // --- 45° upward projection above the slab ---
                Path { path in
                    let w = stoneWidth
                    let top = stoneLift - stoneHeight / 2
                    // Trapezoid: slab top edge → narrower edge 28pt above
                    path.move(to: CGPoint(x: 54 - w / 2, y: top))
                    path.addLine(to: CGPoint(x: 54 + w / 2, y: top))
                    path.addLine(to: CGPoint(x: 54 + w / 2 - 6, y: top - 28))
                    path.addLine(to: CGPoint(x: 54 - w / 2 + 6, y: top - 28))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(castShadowOpacity * 0.8),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .blur(radius: 5)

                // --- Ground shadow ---
                Ellipse()
                    .fill(Color.black.opacity(baseShadowOpacity))
                    .frame(width: 60, height: 12)
                    .blur(radius: 12)
                    .offset(y: stoneLift + 32)

                // --- The slab ---
                stoneCore
                    .scaleEffect(x: 1.0, y: isBreathing ? (1.0 + 0.012 * motionScale) : 1.0)
                    .offset(y: stoneLift)

                // --- Reflection ---
                stoneCore
                    .scaleEffect(x: 1.0, y: -0.42)
                    .opacity(reflectionOpacity)
                    .blur(radius: 1.6)
                    .mask(
                        LinearGradient(
                            colors: [.black.opacity(0.85), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: stoneWidth + 6, height: stoneHeight * 0.55)
                    )
                    .offset(y: stoneLift + (stoneHeight * 0.76))
            }
        }
        .frame(width: 108, height: 108)
        .animation(hasMotion ? .easeInOut(duration: 4.0).repeatForever(autoreverses: true) : .easeInOut(duration: 0.2), value: isBreathing)
        .onAppear {
            isBreathing = hasMotion
        }
        .onChange(of: hasMotion) { _, enabled in
            isBreathing = enabled
        }
    }

    /// Smoother ease curve — dwells longer at totality (center)
    private func smootherstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    private var baseShadowOpacity: Double {
        switch mood {
        case .feasting: return 0.24
        case .alert: return 0.2
        case .expecting: return 0.16
        case .dozing: return 0.11
        case .sleeping: return 0.08
        }
    }

    private var castShadowOpacity: Double {
        switch mood {
        case .feasting: return 0.18
        case .alert: return 0.15
        case .expecting: return 0.12
        case .dozing: return 0.09
        case .sleeping: return 0.06
        }
    }

    private var coronaColor: Color {
        switch mood {
        case .feasting: return Color(red: 0.88, green: 0.78, blue: 0.52)
        case .alert: return Color(red: 0.82, green: 0.72, blue: 0.48)
        case .expecting: return Color(red: 0.78, green: 0.72, blue: 0.56)
        case .dozing, .sleeping: return Color(red: 0.72, green: 0.68, blue: 0.58)
        }
    }

    private var seamGlowOpacity: Double {
        switch mood {
        case .feasting: return 0.10
        case .alert: return 0.08
        case .expecting: return 0.05
        case .dozing: return 0.03
        case .sleeping: return 0.0
        }
    }

    private var seamColor: Color {
        switch mood {
        case .feasting: return Color(red: 0.62, green: 0.68, blue: 0.80)
        case .alert: return Color(red: 0.56, green: 0.62, blue: 0.74)
        case .expecting, .dozing, .sleeping: return Color.white
        }
    }

    private var reflectionOpacity: Double {
        switch mood {
        case .feasting: return 0.16
        case .alert: return 0.14
        case .expecting: return 0.12
        case .dozing: return 0.1
        case .sleeping: return 0.08
        }
    }

    private var stoneHeight: CGFloat {
        switch mood {
        case .feasting: return 82
        case .alert: return 80
        case .expecting: return 78
        case .dozing: return 76
        case .sleeping: return 74
        }
    }

    private var stoneWidth: CGFloat {
        38
    }

    private var stoneLift: CGFloat {
        6
    }

    private var stoneCore: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .frame(width: stoneWidth, height: stoneHeight)

            Rectangle()
                .fill(seamColor.opacity(seamGlowOpacity))
                .frame(width: 1.3, height: stoneHeight - 12)
                .blur(radius: 1.4)
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.04), lineWidth: 0.6)
                .frame(width: stoneWidth, height: stoneHeight)
        )
    }
}
