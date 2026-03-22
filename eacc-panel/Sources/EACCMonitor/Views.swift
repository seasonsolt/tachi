import SwiftUI

// MARK: - EACC Color System (Dark / Matrix)

let ritualBg = Color(red: 0.04, green: 0.04, blue: 0.06)
let cardBg = Color(red: 0.08, green: 0.09, blue: 0.11)
let cardBorder = Color.white.opacity(0.08)
let textPrimary = Color.white.opacity(0.88)
let textSecondary = Color.white.opacity(0.58)
let textTertiary = Color.white.opacity(0.38)

// Neon accents
let cyanAccent = Color(red: 0, green: 0.95, blue: 0.65)
let redAccent = Color(red: 1.0, green: 0.28, blue: 0.28)
let purpleAccent = Color(red: 0.58, green: 0.38, blue: 1.0)
let goldAccent = Color(red: 1.0, green: 0.78, blue: 0.2)
let matrixGreen = Color(red: 0, green: 0.9, blue: 0.4)
let ghostAccent = Color(red: 0.0, green: 0.84, blue: 1.0)

// MARK: - Content View

struct ContentView: View {
    var vm: ViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.isLoading && vm.items.isEmpty && vm.sessions.isEmpty {
                loadingView
            } else {
                scrollContent
            }
            Divider()
            footer
        }
        .frame(width: 400)
        .background {
            ZStack {
                vm.themeColors.bg
                if vm.selectedTheme == .matrix {
                    MatrixRainView()
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("e/acc")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(vm.themeColors.accent)
            Spacer()
            if let date = vm.lastUpdated {
                HStack(spacing: 4) {
                    Text("CYCLE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(textTertiary)
                    Text(date, style: .time)
                        .font(.system(size: 11, design: .monospaced).monospacedDigit())
                        .foregroundStyle(textSecondary)
                }
            }
            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(textSecondary)
            .help("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Initializing ritual link...")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(textSecondary)
        }
        .frame(height: 120)
    }

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                companionSection
                if !vm.sessions.isEmpty {
                    sessionsSection
                }
                providersSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxHeight: 620)
    }

    private var companionSection: some View {
        CompanionCard(vm: vm)
            .padding(.bottom, 4)
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(cyanAccent)
                Text("PET-SENSED THREADS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textSecondary)
                Spacer()
                if vm.workingSessionCount > 0 {
                    Text("\(vm.workingSessionCount) FEEDING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(cyanAccent.opacity(0.12)))
                        .foregroundStyle(cyanAccent)
                } else if vm.waitingSessionCount > 0 {
                    Text("\(vm.waitingSessionCount) WATCHING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(goldAccent.opacity(0.12)))
                        .foregroundStyle(goldAccent)
                }
            }
            .padding(.horizontal, 4)

            ForEach(vm.sessions) { session in
                SessionRow(session: session)
            }
        }
        .padding(.bottom, 4)
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(redAccent.opacity(0.7))
                Text("OFFERINGS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textSecondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(vm.providers) { provider in
                ProviderCard(
                    provider: provider,
                    testState: provider.capacityData.map { vm.testStates[$0.id] ?? .idle } ?? .idle
                ) {
                    if let cap = provider.capacityData {
                        Task { await vm.runTest(accountId: cap.id) }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Menu {
                    ForEach([15.0, 30.0, 60.0, 120.0], id: \.self) { interval in
                        Button {
                            vm.refreshInterval = interval
                        } label: {
                            HStack {
                                Text("\(Int(interval))s")
                                if vm.refreshInterval == interval {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text("\(Int(vm.refreshInterval))s")
                            .font(.system(size: 11, design: .monospaced).monospacedDigit())
                    }
                    .foregroundStyle(textSecondary)
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)

                ThemePickerMenu(vm: vm)

                Spacer()
                Button("OPEN ALTAR") {
                    if let url = URL(string: "https://e-acc.ai") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(vm.themeColors.accent.opacity(0.7))
                Button("DISCONNECT") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(redAccent.opacity(0.6))
            }
            Text("Session pulse: \(Int(vm.sessionRefreshInterval))s")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(textTertiary)
            Text("ACCELERATE OR DIE")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Companion Card

struct CompanionCard: View {
    let vm: ViewModel

    var body: some View {
        HStack(spacing: 14) {
            CompanionPetView(
                persona: vm.companionPersona,
                mood: vm.companionMood,
                accent: vm.companionPetAccent
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(vm.companionMood.badge)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(vm.companionAccent.opacity(0.14)))
                        .foregroundStyle(vm.companionAccent)
                    Spacer()
                    CompanionPersonaMenu(vm: vm)
                    Text("\(vm.weightedUtil)% util")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(textSecondary)
                }

                Text(vm.companionHeadline)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(vm.companionSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    companionChip(icon: "flame", text: "\(vm.workingSessionCount) live", tint: cyanAccent)
                    companionChip(icon: "sparkle.magnifyingglass", text: "\(vm.waitingSessionCount) waiting", tint: goldAccent)
                    companionChip(icon: "waveform.path.ecg", text: "\(vm.warmSessionCount) warm", tint: purpleAccent)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardBg.opacity(0.96), vm.companionAccent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(vm.companionAccent.opacity(0.18), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            Task { await vm.refreshSessionPulse() }
        }
        .contextMenu {
            CompanionPersonaActions(vm: vm)
        }
        .help("Tap to sniff for fresh session activity")
    }

    private func companionChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.1)))
        .foregroundStyle(tint)
    }
}

struct CompanionPersonaMenu: View {
    let vm: ViewModel

    var body: some View {
        Menu {
            CompanionPersonaActions(vm: vm)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 9, weight: .semibold))
                Text(vm.companionPersonaMode.badge)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(vm.companionPetAccent.opacity(0.12)))
            .foregroundStyle(vm.companionPetAccent)
        }
        .menuStyle(.borderlessButton)
        .help("Switch floating pet icon")
    }
}

struct CompanionPersonaActions: View {
    let vm: ViewModel

    var body: some View {
        ForEach(CompanionPersonaMode.allCases, id: \.self) { mode in
            Button {
                vm.setCompanionPersonaMode(mode)
            } label: {
                HStack {
                    Text(mode.label)
                    if vm.companionPersonaMode == mode {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

// MARK: - Theme Picker Menu

struct ThemePickerMenu: View {
    let vm: ViewModel

    var body: some View {
        Menu {
            ForEach(EACCThemeName.allCases, id: \.self) { theme in
                Button {
                    vm.setTheme(theme)
                } label: {
                    HStack {
                        Text("\(theme.label) — \(theme.subtitle)")
                        if vm.selectedTheme == theme {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(vm.themeColors.accent)
                    .frame(width: 6, height: 6)
                Text(vm.selectedTheme.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(vm.themeColors.accent.opacity(0.12)))
            .foregroundStyle(vm.themeColors.accent)
        }
        .menuStyle(.borderlessButton)
        .help("Switch theme")
    }
}

struct CompanionPetView: View {
    let persona: CompanionPersona
    let mood: CompanionMood
    let accent: Color

    var body: some View {
        switch persona {
        case .defaultOrb:
            DefaultCompanionPetView(mood: mood, accent: accent)
        case .laughingMan:
            LaughingManPetView(mood: mood, accent: accent)
        case .bladeRunnerEye:
            BladeRunnerPetView(mood: mood, accent: accent)
        case .matrixAgent:
            MatrixPetView(mood: mood, accent: accent)
        case .nervHex:
            NervHexPetView(mood: mood, accent: accent)
        case .singularityVoid:
            SingularityPetView(mood: mood, accent: accent)
        }
    }
}

private struct DefaultCompanionPetView: View {
    let mood: CompanionMood
    let accent: Color

    @State private var isFloating = false
    @State private var isOrbiting = false

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 94, height: 94)
                .blur(radius: 10)

            if mood == .feasting || mood == .alert {
                Circle()
                    .stroke(accent.opacity(0.34), lineWidth: 1)
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(isOrbiting ? 360 : 0))
                    .overlay(alignment: .top) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                            .offset(y: -4)
                    }
            }

            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 18, height: 18)
                .offset(x: -22, y: -28)
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 18, height: 18)
                .offset(x: 22, y: -28)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.65), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 8) {
                HStack(spacing: 14) {
                    eye
                    eye
                }
                mouth
            }
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 : 3)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isFloating)
        .animation(.linear(duration: 4.8).repeatForever(autoreverses: false), value: isOrbiting)
        .onAppear {
            isFloating = true
            isOrbiting = true
        }
    }

    @ViewBuilder
    private var eye: some View {
        switch mood {
        case .sleeping:
            Capsule()
                .fill(textPrimary)
                .frame(width: 12, height: 2)
        case .dozing:
            Capsule()
                .fill(textPrimary)
                .frame(width: 10, height: 3)
        case .expecting:
            Circle()
                .fill(textPrimary)
                .frame(width: 7, height: 7)
        case .alert:
            Circle()
                .fill(textPrimary)
                .frame(width: 8, height: 8)
                .overlay(Circle().fill(accent).frame(width: 3, height: 3))
        case .feasting:
            Circle()
                .fill(textPrimary)
                .frame(width: 9, height: 9)
                .overlay(Circle().fill(accent).frame(width: 4, height: 4))
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .feasting:
            Capsule()
                .fill(textPrimary)
                .frame(width: 18, height: 6)
        case .alert:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(textPrimary)
                .frame(width: 14, height: 5)
        case .expecting:
            Circle()
                .fill(textPrimary)
                .frame(width: 7, height: 7)
        case .dozing:
            Capsule()
                .fill(textPrimary.opacity(0.8))
                .frame(width: 14, height: 3)
        case .sleeping:
            Capsule()
                .fill(textPrimary.opacity(0.75))
                .frame(width: 12, height: 2)
        }
    }
}

// MARK: - Laughing Man Pet View (SVG ring + Canvas face)
// Ring: NSImage from inline SVG — native <textPath> for pixel-perfect text.
// Face: Canvas paths with mood-based opacity.
// Both layers share the same coordinate space centered on SVG origin (0,0).
// Ring rotates via GPU-accelerated SwiftUI animation (no per-frame redraw).

private struct LaughingManPetView: View {
    let mood: CompanionMood
    let accent: Color

    @State private var isFloating = false
    @State private var isRotating = false

    private let teal = Color(red: 0, green: 85.0 / 255.0, blue: 119.0 / 255.0)

    // Outer ring rendered once from inline SVG.
    // Uses native <textPath> — identical text distribution to laughing-man.svg.
    // viewBox is square and centered on origin so SwiftUI rotation works correctly.
    private static let ringImage: NSImage? = {
        let svg = """
        <svg viewBox="-200 -200 400 400" width="400" height="400" \
        xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">\
        <defs><path id="f" d="m123,0a123,123 0,0 1-246,0a123,123 0,0 1 246,0"/></defs>\
        <g fill="#057">\
        <circle r="160"/>\
        <circle r="150" fill="#fff"/>\
        <text font-size="28" font-stretch="condensed" font-family="Impact">\
        <textPath xlink:href="#f">I thought what I&apos;d do was, I&apos;d pretend I was one of those deaf-mutes</textPath>\
        </text>\
        </g>\
        </svg>
        """
        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }()

    private var faceOpacity: Double {
        switch mood {
        case .feasting: return 0.95
        case .alert: return 0.85
        case .expecting: return 0.75
        case .dozing: return 0.6
        case .sleeping: return 0.42
        }
    }

    var body: some View {
        ZStack {
            // Layer 1: Outer circles (NSImage from SVG)
            if let ring = Self.ringImage {
                Image(nsImage: ring)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Layer 2: Rotating text ring (Canvas, drawn once, GPU-rotated)
            Canvas { context, size in
                drawRingText(&context, size)
            }
            .rotationEffect(.degrees(isRotating ? -360 : 0))

            // Layer 3: Static face (Canvas, redraws only on mood change)
            Canvas { context, size in
                drawFace(&context, size)
            }
        }
        .frame(width: 108, height: 108)
        .offset(y: isFloating ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }

    // Text ring at r=123 — characters spaced proportionally by advance width.
    private func drawRingText(_ context: inout GraphicsContext, _ size: CGSize) {
        let s = min(size.width, size.height)
        let sc = s / 400.0
        let cx = s / 2
        let cy = s / 2
        let radius = 123 * sc
        let fontSize = 22 * sc
        let font = Font.custom("Impact", size: fontSize)
        let text: [Character] = Array(
            "I thought what I'd do was, I'd pretend I was one of those deaf-mutes "
        )

        // Measure each character's advance width for proportional spacing
        let nsFont = NSFont(name: "Impact", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: .heavy)
        var widths: [CGFloat] = []
        for ch in text {
            let w = NSAttributedString(
                string: String(ch), attributes: [.font: nsFont]
            ).size().width
            widths.append(w)
        }
        let totalWidth = widths.reduce(0, +)

        var cumulative: CGFloat = 0
        for (i, ch) in text.enumerated() {
            let charCenter = cumulative + widths[i] / 2
            let angle = Double(charCenter / totalWidth) * 360.0
            let rad = angle * .pi / 180.0
            let gx = cx + radius * cos(rad)
            let gy = cy + radius * sin(rad)

            var resolved = context.resolve(Text(String(ch)).font(font))
            resolved.shading = .color(teal)
            context.drawLayer { c in
                c.translateBy(x: gx, y: gy)
                c.rotate(by: .degrees(angle + 90))
                c.draw(resolved, at: .zero, anchor: .bottom)
            }
            cumulative += widths[i]
        }
    }

    // All coordinates use the same 400×400 space as the ring SVG viewBox.
    // SVG origin (0,0) = center of both layers.
    private func drawFace(_ context: inout GraphicsContext, _ size: CGSize) {
        let s = min(size.width, size.height)
        let sc = s / 400.0
        let cx = s / 2
        let cy = s / 2

        func px(_ v: CGFloat) -> CGFloat { cx + v * sc }
        func py(_ v: CGFloat) -> CGFloat { cy + v * sc }
        func pd(_ v: CGFloat) -> CGFloat { v * sc }

        // Inner teal circle r=115 — masks the ring text underneath
        context.fill(
            Path(ellipseIn: CGRect(x: px(0) - pd(115), y: py(0) - pd(115),
                                   width: pd(230), height: pd(230))),
            with: .color(teal))

        // Inner white circle r=95
        context.fill(
            Path(ellipseIn: CGRect(x: px(0) - pd(95), y: py(0) - pd(95),
                                   width: pd(190), height: pd(190))),
            with: .color(.white))

        // Face features (mood opacity)
        context.drawLayer { fc in
            fc.opacity = faceOpacity

            // Top tick (m-8-119h16 l2,5h-20z)
            var tick = Path()
            tick.move(to: CGPoint(x: px(-8), y: py(-119)))
            tick.addLine(to: CGPoint(x: px(8), y: py(-119)))
            tick.addLine(to: CGPoint(x: px(10), y: py(-114)))
            tick.addLine(to: CGPoint(x: px(-10), y: py(-114)))
            tick.closeSubpath()
            fc.fill(tick, with: .color(teal))

            // Right ear (circle cx=160 r=40)
            fc.fill(
                Path(ellipseIn: CGRect(x: px(160) - pd(40), y: py(0) - pd(40),
                                       width: pd(80), height: pd(80))),
                with: .color(teal))

            // Visor (m-95-20v-20h255a40,40 0,0 1 0,80h-55v-20z)
            var visor = Path()
            visor.move(to: CGPoint(x: px(-95), y: py(-20)))
            visor.addLine(to: CGPoint(x: px(-95), y: py(-40)))
            visor.addLine(to: CGPoint(x: px(160), y: py(-40)))
            visor.addArc(center: CGPoint(x: px(160), y: py(0)), radius: pd(40),
                         startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            visor.addLine(to: CGPoint(x: px(105), y: py(40)))
            visor.addLine(to: CGPoint(x: px(105), y: py(20)))
            visor.closeSubpath()
            fc.fill(visor, with: .color(teal))

            // Smile (outer r=85, inner r=65)
            var smile = Path()
            smile.move(to: CGPoint(x: px(-85), y: py(0)))
            smile.addArc(center: CGPoint(x: px(0), y: py(0)), radius: pd(85),
                         startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
            smile.addLine(to: CGPoint(x: px(65), y: py(0)))
            smile.addArc(center: CGPoint(x: px(0), y: py(0)), radius: pd(65),
                         startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            smile.closeSubpath()
            fc.fill(smile, with: .color(teal))

            // Chin bar (m-65 20v20h140v-20z)
            var chin = Path()
            chin.move(to: CGPoint(x: px(-65), y: py(20)))
            chin.addLine(to: CGPoint(x: px(-65), y: py(40)))
            chin.addLine(to: CGPoint(x: px(75), y: py(40)))
            chin.addLine(to: CGPoint(x: px(75), y: py(20)))
            chin.closeSubpath()
            fc.fill(chin, with: .color(teal))
        }

        // White highlight (m-115-20v10h25v30h250a20,20 0,0 0 0,-40z)
        var hl = Path()
        hl.move(to: CGPoint(x: px(-115), y: py(-20)))
        hl.addLine(to: CGPoint(x: px(-115), y: py(-10)))
        hl.addLine(to: CGPoint(x: px(-90), y: py(-10)))
        hl.addLine(to: CGPoint(x: px(-90), y: py(20)))
        hl.addLine(to: CGPoint(x: px(160), y: py(20)))
        hl.addArc(center: CGPoint(x: px(160), y: py(0)), radius: pd(20),
                   startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        hl.closeSubpath()
        context.fill(hl, with: .color(.white))

        // Eyes (mood opacity)
        context.drawLayer { ec in
            ec.opacity = faceOpacity

            var le = Path()
            le.move(to: CGPoint(x: px(-20), y: py(10)))
            le.addCurve(to: CGPoint(x: px(-64), y: py(10)),
                        control1: CGPoint(x: px(-37), y: py(-4)),
                        control2: CGPoint(x: px(-47), y: py(-4)))
            le.addCurve(to: CGPoint(x: px(-20), y: py(10)),
                        control1: CGPoint(x: px(-58), y: py(-15)),
                        control2: CGPoint(x: px(-27), y: py(-15)))
            le.closeSubpath()
            ec.fill(le, with: .color(teal))

            var re = Path()
            re.move(to: CGPoint(x: px(60), y: py(10)))
            re.addCurve(to: CGPoint(x: px(16), y: py(10)),
                        control1: CGPoint(x: px(43), y: py(-4)),
                        control2: CGPoint(x: px(33), y: py(-4)))
            re.addCurve(to: CGPoint(x: px(60), y: py(10)),
                        control1: CGPoint(x: px(22), y: py(-15)),
                        control2: CGPoint(x: px(53), y: py(-15)))
            re.closeSubpath()
            ec.fill(re, with: .color(teal))
        }
    }
}

// MARK: - Provider Card (Unified)

struct ProviderCard: View {
    let provider: ProviderSummary
    let testState: TestState
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader
            if let stats = provider.personalStats {
                tributeSection(stats)
            }
            if let cap = provider.capacityData {
                if provider.personalStats != nil {
                    sectionDivider
                }
                capacitySection(cap)
            }
            if provider.capacityData == nil && provider.personalStats == nil {
                unavailableBadge
            }
            if provider.capacityData != nil {
                testSection
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardBg)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: provider.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(platformGradient)
                .frame(width: 20)
            HStack(spacing: 4) {
                Text(provider.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                if provider.platform == "anthropic" {
                    Text("// SYMBIONT")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(textTertiary)
                }
            }
            Spacer()
            primaryMetric
        }
    }

    @ViewBuilder
    private var primaryMetric: some View {
        if let stats = provider.personalStats {
            Text(stats.formattedTotalCost)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(purpleAccent)
        } else if let cap = provider.capacityData {
            let util = cap.maxUtilization
            Text("\(util)%")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ritualColorForUtil(util))
        }
    }

    private var platformGradient: some ShapeStyle {
        switch provider.platform {
        case "openai":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [goldAccent, goldAccent.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        case "anthropic":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [purpleAccent, purpleAccent.opacity(0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        case "antigravity":
            return AnyShapeStyle(
                .linearGradient(
                    colors: [cyanAccent, cyanAccent.opacity(0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(.secondary)
        }
    }

    // MARK: - TRIBUTE Section

    private func tributeSection(_ stats: ClaudeStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRIBUTE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(textTertiary)

            if stats.dailyCostLimit > 0 {
                costBar(label: "Today", current: stats.dailyCost, limit: stats.dailyCostLimit)
            } else {
                tributeRow(label: "Today", cost: stats.dailyCost)
            }

            if stats.weeklyOpusCostLimit > 0 {
                costBar(label: "Opus/wk", current: stats.weeklyOpusCost, limit: stats.weeklyOpusCostLimit)
            } else if stats.weeklyOpusCost > 0 {
                tributeRow(label: "Opus/wk", cost: stats.weeklyOpusCost)
            }

            tributeRow(label: "Total", cost: stats.totalCost)

            HStack(spacing: 4) {
                Label("\(stats.totalRequests) reqs", systemImage: "arrow.up.arrow.down")
                Text("\u{00B7}")
                Label(formatTokens(stats.totalTokens), systemImage: "text.word.spacing")
                Spacer()
            }
            .font(.system(size: 10))
            .foregroundStyle(textTertiary)
        }
    }

    private func tributeRow(label: String, cost: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(textTertiary)
                .frame(width: 50, alignment: .trailing)
            Text(String(format: "$%.2f", cost))
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(textSecondary)
            Spacer()
        }
    }

    private func costBar(label: String, current: Double, limit: Double) -> some View {
        let pct = limit > 0 ? min(current / limit, 1.0) : 0
        let utilInt = Int((pct * 100).rounded())
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(textTertiary)
                .frame(width: 50, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary.opacity(0.5))
                    if pct > 0 {
                        Capsule()
                            .fill(ritualBarGradient(utilInt))
                            .frame(width: max(4, geo.size.width * CGFloat(pct)))
                    }
                }
            }
            .frame(height: 5)
            Text(String(format: "$%.2f", current))
                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(ritualColorForUtil(utilInt))
                .frame(width: 50, alignment: .trailing)
            Text("/ $\(String(format: "%.0f", limit))")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(textTertiary)
                .frame(width: 40, alignment: .leading)
        }
    }

    private func ritualBarGradient(_ util: Int) -> some ShapeStyle {
        let c = ritualColorForUtil(util)
        return AnyShapeStyle(
            .linearGradient(
                colors: [c.opacity(0.5), c],
                startPoint: .leading, endPoint: .trailing))
    }

    // MARK: - CAPACITY Section

    @ViewBuilder
    private func capacitySection(_ cap: AccountWithUsage) -> some View {
        if let usage = cap.usage {
            VStack(alignment: .leading, spacing: 6) {
                if provider.personalStats != nil {
                    Text("CAPACITY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(textTertiary)
                }
                capacityContent(usage)
            }
        } else {
            unavailableBadge
        }
    }

    @ViewBuilder
    private func capacityContent(_ usage: UsageData) -> some View {
        switch usage {
        case .openai(let fh, let sd):
            VStack(spacing: 6) {
                UtilRow(label: "5h", util: fh.utilization, remaining: fh.remainingSeconds)
                UtilRow(label: "7d", util: sd.utilization, remaining: sd.remainingSeconds)
                if fh.requests > 0 || sd.requests > 0 {
                    HStack(spacing: 4) {
                        Label("\(fh.requests) reqs", systemImage: "arrow.up.arrow.down")
                        Text("\u{00B7}")
                        Label(formatTokens(fh.tokens), systemImage: "text.word.spacing")
                        Spacer()
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
                }
            }
        case .antigravity(let fh, let models, let tier, let credits):
            VStack(alignment: .leading, spacing: 6) {
                if !tier.isEmpty {
                    HStack(spacing: 6) {
                        Text(tier)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(cyanAccent.opacity(0.1)))
                            .foregroundStyle(cyanAccent)
                        Text("Credits: \(credits)")
                            .font(.system(size: 10))
                            .foregroundStyle(textTertiary)
                    }
                }
                UtilRow(label: "5h", util: fh.utilization, remaining: fh.remainingSeconds)

                let active = models.filter { $0.utilization > 0 }
                let idle = models.filter { $0.utilization == 0 }

                ForEach(active) { m in
                    ModelRow(model: m)
                }

                if !idle.isEmpty {
                    Text("\(idle.count) models at 0%")
                        .font(.system(size: 10))
                        .foregroundStyle(textTertiary)
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Shared

    private var sectionDivider: some View {
        Rectangle()
            .fill(cardBorder)
            .frame(height: 0.5)
            .padding(.vertical, 2)
    }

    private var unavailableBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Offering data unavailable")
                .font(.system(size: 11))
                .foregroundStyle(textSecondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var testSection: some View {
        switch testState {
        case .idle:
            HStack {
                Spacer()
                Button {
                    onTest()
                } label: {
                    Label("Test", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.quaternary))
            }
        case .testing:
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text("Probing...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(textSecondary)
            }
        case .success(let model, let text):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(cyanAccent)
                        .font(.system(size: 11))
                    Text(model)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(textSecondary)
                }
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(cyanAccent.opacity(0.06)))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .failure(let error):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(redAccent)
                    .font(.system(size: 11))
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(redAccent.opacity(0.06)))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

// MARK: - Utilization Row

struct UtilRow: View {
    let label: String
    let util: Int
    let remaining: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(textTertiary)
                .frame(width: 22, alignment: .trailing)
            UtilBar(value: util)
            Text("\(util)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(ritualColorForUtil(util))
                .frame(width: 36, alignment: .trailing)
            Text(formatRemaining(remaining))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(textTertiary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: ModelQuota

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(model.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
                Spacer()
                let reset = formatResetTime(model.resetTime)
                if !reset.isEmpty {
                    Text(reset)
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(textTertiary)
                }
            }
            HStack(spacing: 8) {
                UtilBar(value: model.utilization)
                Text("\(model.utilization)%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ritualColorForUtil(model.utilization))
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }
}

// MARK: - Utilization Bar

struct UtilBar: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary.opacity(0.5))
                if value > 0 {
                    Capsule()
                        .fill(barGradient)
                        .frame(width: max(4, geo.size.width * CGFloat(value) / 100))
                }
            }
        }
        .frame(height: 5)
    }

    private var barGradient: some ShapeStyle {
        let c = ritualColorForUtil(value)
        return AnyShapeStyle(
            .linearGradient(
                colors: [c.opacity(0.5), c],
                startPoint: .leading, endPoint: .trailing))
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: CodingSession
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 10) {
            statusIndicator
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: session.tool.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)
                    Text(session.projectName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                }
                Text(detailLine)
                    .font(.system(size: 9))
                    .foregroundStyle(signalColor)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(ritualStatusLabel(session.status))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor)
                Text(timeAgo(session.lastActivity))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(textTertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cardBg)
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(statusBorderColor, lineWidth: 1)
        )
    }

    private func ritualStatusLabel(_ status: SessionStatus) -> String {
        switch status {
        case .working: return "FEEDING"
        case .waitingForInput: return "WATCHING"
        case .idle: return "DOZING"
        case .completed: return "CURLED UP"
        }
    }

    private var detailLine: String {
        let base = session.signal.label
        if !session.slug.isEmpty && session.slug != session.projectName {
            return "\(session.slug) · \(base)"
        }
        return base
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(statusColor, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.6 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .opacity(session.pulse == .hot || session.pulse == .warm ? 1 : 0)
            )
            .onAppear {
                if session.pulse == .hot || session.pulse == .warm {
                    withAnimation(
                        .easeOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                    ) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: session.pulse) { _, newValue in
                if newValue == .hot || newValue == .warm {
                    isPulsing = false
                    withAnimation(
                        .easeOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                    ) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }

    private var statusColor: Color {
        switch session.pulse {
        case .hot: return cyanAccent
        case .warm: return goldAccent
        case .listening: return goldAccent.opacity(0.9)
        case .drowsy: return purpleAccent.opacity(0.7)
        case .sleeping: return .gray
        }
    }

    private var signalColor: Color {
        switch session.pulse {
        case .hot, .warm: return textSecondary
        case .listening: return goldAccent.opacity(0.9)
        case .drowsy: return textTertiary
        case .sleeping: return textTertiary
        }
    }

    private var statusBorderColor: Color {
        switch session.status {
        case .working: return cyanAccent.opacity(0.25)
        case .waitingForInput: return goldAccent.opacity(0.25)
        default: return .clear
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Matrix Static Wallpaper

struct MatrixRainView: View {
    private static let glyphs: [String] = "アウエカキケコシスセタチツテトナニネノハヒフヘホマミムメモヤユヨラリルレロワン0123456789ABCDEF".map { String($0) }
    private static let colSpacing: Double = 18
    private static let fontSize: CGFloat = 11

    private struct FrozenColumn {
        let x: Double
        let chars: [(glyph: String, y: Double, alpha: Double, isHead: Bool)]
    }

    @State private var frozen: [FrozenColumn] = []

    var body: some View {
        GeometryReader { geo in
            Canvas(rendersAsynchronously: true) { ctx, size in
                draw(ctx: ctx, size: size)
            }
            .onAppear { generate(width: geo.size.width, height: geo.size.height) }
            .onChange(of: geo.size) { _, s in generate(width: s.width, height: s.height) }
        }
        .overlay {
            // Top-down vignette glow
            LinearGradient(
                stops: [
                    .init(color: matrixGreen.opacity(0.06), location: 0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .clear, location: 0.7),
                    .init(color: matrixGreen.opacity(0.04), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .overlay {
            // Radial center highlight
            RadialGradient(
                colors: [matrixGreen.opacity(0.05), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }

    private func generate(width: Double, height: Double) {
        let colCount = Int(width / Self.colSpacing)
        var rng = SystemRandomNumberGenerator()
        frozen = (0..<colCount).map { i in
            let x = Double(i) * Self.colSpacing + 4
            let length = Int.random(in: 5...18, using: &rng)
            let headY = Double.random(in: 0...height, using: &rng)

            let chars: [(String, Double, Double, Bool)] = (0..<length).compactMap { j in
                let y = headY - Double(j) * Double(Self.fontSize)
                guard y > -Double(Self.fontSize), y < height + Double(Self.fontSize) else { return nil }
                let alpha: Double
                let isHead: Bool
                if j == 0 {
                    alpha = Double.random(in: 0.55...0.85, using: &rng)
                    isHead = true
                } else {
                    let fade = 1.0 - Double(j) / Double(length)
                    alpha = fade * Double.random(in: 0.12...0.30, using: &rng)
                    isHead = false
                }
                let glyph = Self.glyphs.randomElement(using: &rng)!
                return (glyph, y, alpha, isHead)
            }
            return FrozenColumn(x: x, chars: chars)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let font = Font.system(size: Self.fontSize, design: .monospaced)
        for col in frozen {
            for ch in col.chars {
                let color: Color = ch.isHead
                    ? .white.opacity(ch.alpha)
                    : matrixGreen.opacity(ch.alpha)
                var text = ctx.resolve(Text(ch.glyph).font(font))
                text.shading = .color(color)

                // Subtle glow for head chars
                if ch.isHead {
                    var glow = ctx.resolve(Text(ch.glyph).font(font))
                    glow.shading = .color(matrixGreen.opacity(ch.alpha * 0.4))
                    ctx.drawLayer { inner in
                        inner.addFilter(.blur(radius: 4))
                        inner.draw(glow, at: CGPoint(x: col.x, y: ch.y), anchor: .topLeading)
                    }
                }

                ctx.draw(text, at: CGPoint(x: col.x, y: ch.y), anchor: .topLeading)
            }
        }
    }
}

// MARK: - EACC Helpers

func ritualColorForUtil(_ v: Int) -> Color {
    if v < 50 { return cyanAccent }
    if v < 80 { return goldAccent }
    return redAccent
}

func colorForUtil(_ v: Int) -> Color {
    ritualColorForUtil(v)
}
