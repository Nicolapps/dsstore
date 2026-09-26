import SwiftUI

/// The chosen game, played out in front of the dimmed store: its case comes off the shelf and opens,
/// a console slides in, and the card moves from the case into the console's slot. The empty case then
/// goes back on the shelf. Putting the game back plays the same sequence in reverse.
struct CartridgeInsertion: View {
    let game: DisplayGame
    /// The width of a case on the shelf; every pose of the case scales from it.
    let caseWidth: CGFloat
    let slotFrame: () -> CGRect?
    let onPutBack: () -> Void

    @State private var progress: Double
    @State private var isSettled: Bool
    @State private var isPuttingBack = false
    @State private var startedAt = Date.now
    /// Only used under Reduce Motion, where the whole scene fades instead of playing out.
    @State private var opacity: Double
    @State private var lifts = 0
    @State private var clicks = 0
    @State private var ejects = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let duration: TimeInterval = 3.2
    private static let putBackDuration: TimeInterval = 2.3

    init(game: DisplayGame, caseWidth: CGFloat, liftsIn: Bool,
         slotFrame: @escaping () -> CGRect?, onPutBack: @escaping () -> Void) {
        self.game = game
        self.caseWidth = caseWidth
        self.slotFrame = slotFrame
        self.onPutBack = onPutBack
        _progress = State(initialValue: liftsIn ? 0 : 1)
        _isSettled = State(initialValue: !liftsIn)
        _opacity = State(initialValue: liftsIn ? 0 : 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = StageLayout(size: proxy.size, caseWidth: caseWidth)
            ZStack {
                InsertionStage(progress: progress, game: game, layout: layout,
                               shelfSlot: slotFrame,
                               onPutBack: putBack)
                hint.position(layout.hintCenter)
            }
            .accessibilityAddTraits(.isModal)
        }
        .opacity(reduceMotion ? opacity : 1)
        .sensoryFeedback(.impact(weight: .light), trigger: lifts)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.8), trigger: clicks)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.6), trigger: ejects)
        .onAppear {
            guard !isSettled else { return }
            if reduceMotion {
                progress = 1
                withAnimation(.easeOut(duration: 0.25)) { opacity = 1 } completion: { isSettled = true }
            } else {
                insert()
            }
        }
    }

    private var hint: some View {
        let isShown = isSettled && !isPuttingBack
        return VStack(spacing: 6) {
            Text("Open to Play")
                .font(.title2.weight(.semibold))
                .fontDesign(.rounded)
            Text("Or tap outside to put the game back")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .fixedSize()
        .opacity(isShown ? 1 : 0)
        .animation(isShown ? .easeOut(duration: 0.3) : .easeOut(duration: 0.15), value: isShown)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Plays the scene at a constant rate; each beat eases itself. The card's click is its own step,
    /// so the haptic lands on the frame the card seats.
    private func insert() {
        startedAt = .now
        lifts += 1
        let seated = Beat.cardIn.upperBound
        withAnimation(.linear(duration: Self.duration * seated)) {
            progress = seated
        } completion: {
            guard !isPuttingBack else { return }
            clicks += 1
            withAnimation(.linear(duration: Self.duration * (1 - seated))) {
                progress = 1
            } completion: {
                if !isPuttingBack { isSettled = true }
            }
        }
    }

    private func putBack() {
        guard !isPuttingBack else { return }
        isPuttingBack = true

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { opacity = 0 } completion: { onPutBack() }
            return
        }

        // The insertion runs at a constant rate, so its elapsed time says where it is.
        let current = isSettled ? 1 : min(1, Date.now.timeIntervalSince(startedAt) / Self.duration)
        isSettled = false
        let seated = Beat.cardIn.upperBound
        let rewind = { (from: Double) in
            withAnimation(.linear(duration: Self.putBackDuration * from)) {
                progress = 0
            } completion: {
                onPutBack()
            }
        }
        guard current > seated else { return rewind(current) }
        withAnimation(.linear(duration: Self.putBackDuration * (current - seated))) {
            progress = seated
        } completion: {
            ejects += 1
            rewind(seated)
        }
    }
}

/// When each part of the scene moves, as fractions of the whole.
private enum Beat {
    static let dim = 0.0...0.14
    static let lift = 0.0...0.16
    static let open = 0.13...0.34
    static let console = 0.24...0.46
    static let cardOut = 0.46...0.6
    static let cardIn = 0.6...0.72
    static let close = 0.74...0.86
    static let shelve = 0.84...1.0
}

private extension Double {
    /// How far `self` is through `range`, from 0 to 1.
    func through(_ range: ClosedRange<Double>) -> Double {
        min(max((self - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }
}

private func easeInOut(_ t: Double) -> Double {
    t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}

/// Overshoots a little before settling, like something pushed across a counter.
private func easeOutBack(_ t: Double) -> Double {
    let overshoot = 0.9
    return 1 + (overshoot + 1) * pow(t - 1, 3) + overshoot * pow(t - 1, 2)
}

private func mix(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * t }
private func mix(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: mix(a.x, b.x, t), y: mix(a.y, b.y, t))
}

/// Where things rest, in the store's coordinates.
private struct StageLayout {
    let size: CGSize
    let caseWidth: CGFloat

    var consoleWidth: CGFloat { min(size.width * 0.6, size.height * 0.26 / ClosedConsole.aspect) }
    var consoleCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.66) }
    var consoleScale: CGFloat { consoleWidth / ClosedConsole.width }
    /// The card disappears below this line, into the slot.
    var slotLine: CGFloat {
        consoleCenter.y - consoleWidth * ClosedConsole.aspect / 2 + ClosedConsole.slotLine * consoleScale
    }
    var hintCenter: CGPoint {
        CGPoint(x: size.width / 2, y: consoleCenter.y + consoleWidth * ClosedConsole.aspect / 2 + 52)
    }

    /// The case lies open across the middle, its tray on the right of the spine.
    var openCaseWidth: CGFloat { min(size.width * 0.37, size.height * 0.23 / CaseMetrics.aspect) }
    var openCaseCenter: CGPoint { CGPoint(x: size.width / 2 + openCaseWidth / 2, y: size.height * 0.3) }
    var liftedCaseWidth: CGFloat { openCaseWidth * 1.12 }
    var liftedCaseCenter: CGPoint { CGPoint(x: size.width / 2, y: openCaseCenter.y) }

    var cardWidth: CGFloat { GameCard.width * consoleScale }
    var cardHeight: CGFloat { cardWidth * GameCard.aspect }
    /// Where the card goes when it's in the console: all but its grip is inside.
    var seatedCardCenter: CGPoint {
        CGPoint(x: size.width / 2, y: slotLine + cardHeight / 2 - 1.3 * consoleScale)
    }
    var cardAboveSlot: CGPoint {
        CGPoint(x: size.width / 2, y: slotLine - cardHeight / 2 - 8)
    }
    /// Where the card sits in the open case.
    var cardInCase: CGPoint {
        let scale = openCaseWidth / CaseMetrics.width
        return CGPoint(x: openCaseCenter.x + (CaseMetrics.cardCenter.x - CaseMetrics.width / 2) * scale,
                       y: openCaseCenter.y + (CaseMetrics.cardCenter.y - CaseMetrics.height / 2) * scale)
    }
    var cardWidthInCase: CGFloat { CaseMetrics.cardWidth * openCaseWidth / CaseMetrics.width }
}

/// Draws the whole scene for one moment of it. Every frame is a function of `progress`,
/// so the scene can run either way and stop anywhere.
private struct InsertionStage: View, Animatable {
    var progress: Double
    let game: DisplayGame
    let layout: StageLayout
    let shelfSlot: () -> CGRect?
    let onPutBack: () -> Void

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = progress
        ZStack {
            Color.black
                .opacity(0.7 * easeInOut(p.through(Beat.dim)))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onPutBack)
                .accessibilityHidden(true)
            gameCase
            console
            if p >= Beat.cardOut.lowerBound { card }
        }
    }

    private var gameCase: some View {
        let p = progress
        let slot = shelfSlot()
        let slotCenter = slot.map { CGPoint(x: $0.midX, y: $0.midY) } ?? layout.liftedCaseCenter
        let lifted = easeInOut(p.through(Beat.lift))
        let openness = easeInOut(p.through(Beat.open)) - easeInOut(p.through(Beat.close))
        let shelved = easeInOut(p.through(Beat.shelve))

        var center = mix(slotCenter, layout.liftedCaseCenter, lifted)
        var width = mix(layout.caseWidth, layout.liftedCaseWidth, lifted)
        center = mix(center, layout.openCaseCenter, openness)
        width = mix(width, layout.openCaseWidth, openness)
        center = mix(center, slotCenter, shelved)
        width = mix(width, layout.caseWidth, shelved)
        let elevation = lifted * (1 - shelved)

        return OpeningCase(game: game, openness: openness, holdsCard: p < Beat.cardOut.lowerBound)
            .frame(width: CaseMetrics.width, height: CaseMetrics.height)
            .scaleEffect(width / CaseMetrics.width)
            .shadow(color: .black.opacity(0.45 * elevation), radius: 18 * elevation, y: 12 * elevation)
            // Back on the shelf, it sits in the store's shade like everything else there.
            .colorMultiply(Color(white: 1 - 0.7 * shelved))
            .position(center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var console: some View {
        let p = progress
        let arrived = easeOutBack(p.through(Beat.console))
        let offscreen = layout.size.width + layout.consoleWidth / 2 + 30
        return ClosedConsole(isPoweredOn: p >= Beat.cardIn.upperBound)
            .frame(width: ClosedConsole.width, height: ClosedConsole.height)
            .scaleEffect(layout.consoleScale)
            .rotationEffect(.degrees(8 * (1 - arrived)))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
            .position(x: mix(offscreen, layout.consoleCenter.x, arrived), y: layout.consoleCenter.y)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(game.title)
            .accessibilityValue("In the console")
            .accessibilityHint("Open iPhone to play.")
            .accessibilityAction(named: "Put Back on Shelf", onPutBack)
            .accessibilityAction(.escape, onPutBack)
    }

    private var card: some View {
        let p = progress
        let out = easeInOut(p.through(Beat.cardOut))
        let seated = easeInOut(p.through(Beat.cardIn))
        // Lifting out of the case, it comes up towards the viewer and back down over the slot.
        let raised = sin(out * .pi)
        let width = mix(layout.cardWidthInCase, layout.cardWidth, out)
        var center = mix(layout.cardInCase, layout.cardAboveSlot, out)
        center.y = mix(center.y, layout.seatedCardCenter.y, seated)

        return GameCard(game: game)
            .frame(width: GameCard.width, height: GameCard.width * GameCard.aspect)
            .scaleEffect(width / GameCard.width * (1 + 0.14 * raised))
            .shadow(color: .black.opacity(0.35 + 0.15 * raised), radius: 2 + 10 * raised, y: 2 + 10 * raised)
            .position(center)
            .frame(width: layout.size.width, height: layout.size.height)
            .mask(alignment: .top) { Rectangle().frame(height: max(0, layout.slotLine)) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A case's proportions, in the units of a case 150 points wide.
private enum CaseMetrics {
    static let width: CGFloat = 150
    /// The cover art's own aspect, plus the plastic around it.
    static let height: CGFloat = 146 * 462 / 512 + 4
    static var aspect: CGFloat { height / width }
    static let cardWidth: CGFloat = 48
    static let cardCenter = CGPoint(x: 77.5, y: 56)
}

/// The case, opening like a book around its spine. Past halfway, the cover shows its inside.
private struct OpeningCase: View {
    let game: DisplayGame
    let openness: Double
    let holdsCard: Bool

    var body: some View {
        let turn = sin(openness * .pi)
        CaseTray(game: game, holdsCard: holdsCard)
            // The raised cover shades the tray next to the spine.
            .overlay(alignment: .leading) {
                LinearGradient(colors: [.black.opacity(0.5 * turn), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 1 + CaseMetrics.width * 0.7 * turn)
            }
            .overlay {
                ZStack {
                    GameCase(game: game, scale: 1)
                        .opacity(openness < 0.5 ? 1 : 0)
                    CoverInside(game: game)
                        .scaleEffect(x: -1)
                        .opacity(openness < 0.5 ? 0 : 1)
                }
                .brightness(-0.3 * turn)
                .rotation3DEffect(.degrees(-180 * openness), axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.45)
            }
    }
}

private let casePlastic = LinearGradient(colors: [Color(white: 0.25), Color(white: 0.13)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)

/// The inside of the case: a molded well holding the card.
private struct CaseTray: View {
    let game: DisplayGame
    let holdsCard: Bool

    var body: some View {
        let card = CaseMetrics.cardCenter
        let cardHeight = CaseMetrics.cardWidth * GameCard.aspect
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(casePlastic)
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.2), .black.opacity(0.35)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            HStack {
                Rectangle().fill(.black.opacity(0.35)).frame(width: 5)
                Spacer()
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(.black.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(LinearGradient(colors: [.black.opacity(0.6), .white.opacity(0.14)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
                .frame(width: CaseMetrics.cardWidth + 6, height: cardHeight + 5)
                .position(card)
            if holdsCard {
                GameCard(game: game)
                    .frame(width: GameCard.width, height: GameCard.width * GameCard.aspect)
                    .scaleEffect(CaseMetrics.cardWidth / GameCard.width)
                    .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                    .position(card)
            }
            // The tab that releases the card.
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.36), Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: 3.5)
                .position(x: card.x, y: card.y + cardHeight / 2 + 8)
            VStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule().fill(.black.opacity(0.28)).frame(height: 1.2)
                }
            }
            .frame(width: 70)
            .position(x: card.x, y: CaseMetrics.height - 20)
        }
        .frame(width: CaseMetrics.width, height: CaseMetrics.height)
    }
}

/// The inside of the cover: the manual, held in by clips. Its spine is on the right,
/// since that's where it meets the tray once open.
private struct CoverInside: View {
    let game: DisplayGame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(casePlastic)
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.2), .black.opacity(0.35)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            HStack {
                Spacer()
                Rectangle().fill(.black.opacity(0.35)).frame(width: 5)
            }
            Image(game.id)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(2)
                .background(Color(white: 0.95))
                .frame(width: 118)
                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                .overlay(alignment: .leading) {
                    VStack {
                        clip
                        Spacer()
                        clip
                    }
                    .padding(.vertical, 14)
                    .offset(x: -3)
                }
                .offset(x: -2)
        }
        .frame(width: CaseMetrics.width, height: CaseMetrics.height)
    }

    private var clip: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(LinearGradient(colors: [Color(white: 0.34), Color(white: 0.18)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 7, height: 14)
            .shadow(color: .black.opacity(0.4), radius: 1, x: 1)
    }
}

/// A game card, drawn in millimetres: 33 wide, 35 tall, with a grip along the top and the game's art as its label.
private struct GameCard: View {
    static let width: CGFloat = 33
    static let aspect: CGFloat = 35 / 33
    let game: DisplayGame

    var body: some View {
        let shape = CardShape()
        ZStack(alignment: .top) {
            shape.fill(LinearGradient(colors: [Color(white: 0.4), Color(white: 0.24)], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 0.9) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(.black.opacity(0.3)).frame(height: 0.35)
                }
            }
            .padding(.horizontal, 7)
            .padding(.top, 1.8)
            // Cropped past the case's spine strip, so the label is all art.
            Image(game.id)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 25)
                .frame(width: 27, alignment: .trailing)
                .clipShape(RoundedRectangle(cornerRadius: 0.8))
                .overlay {
                    RoundedRectangle(cornerRadius: 0.8).strokeBorder(.black.opacity(0.25), lineWidth: 0.3)
                }
                .padding(.top, 7.5)
            shape.fill(LinearGradient(stops: [
                .init(color: .white.opacity(0.22), location: 0),
                .init(color: .white.opacity(0.04), location: 0.45),
                .init(color: .clear, location: 0.46)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.stroke(.black.opacity(0.45), lineWidth: 0.35)
        }
        .clipShape(shape)
    }
}

/// A rounded card with one chamfered top corner.
nonisolated private struct CardShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 1.2
        let chamfer: CGFloat = 3.5
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - chamfer, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + chamfer))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.closeSubpath()
        return path
    }
}

/// The console, closed, seen from above and a little in front: the lid, with the hinge at the back
/// and the front edge showing both halves. Drawn in millimetres. The card slot sits on the back edge,
/// between the hinge's two knuckles.
private struct ClosedConsole: View {
    static let width: CGFloat = 133
    static let depth: CGFloat = 74
    /// The front edge, foreshortened.
    static let front: CGFloat = 10
    static var height: CGFloat { depth + front }
    static var aspect: CGFloat { height / width }
    /// How far down from the back edge the card enters the slot.
    static let slotLine: CGFloat = 1.8

    let isPoweredOn: Bool

    var body: some View {
        let shell = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack(alignment: .top) {
            // The front edge: the lower half, the seam, then the lid's edge above it.
            shell
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.9), location: 0.6),
                    .init(color: Color(white: 0.8), location: 0.8),
                    .init(color: Color(white: 0.66), location: 1)
                ], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Rectangle().fill(.black.opacity(0.28)).frame(height: 0.6)
                        Rectangle().fill(.white.opacity(0.7)).frame(height: 0.4)
                    }
                    .padding(.horizontal, 5)
                    .padding(.bottom, Self.front * 0.48)
                }
                .overlay(alignment: .bottom) {
                    // The accessory slot, on the front of the lower half.
                    Capsule()
                        .fill(Color(white: 0.3))
                        .frame(width: 26, height: 1.1)
                        .padding(.bottom, Self.front * 0.2)
                }
            shell
                .fill(LinearGradient(stops: [
                    .init(color: Palette.shellLight, location: 0),
                    .init(color: Color(white: 0.96), location: 0.6),
                    .init(color: Palette.shellDark, location: 1)
                ], startPoint: .top, endPoint: .bottom))
                .overlay {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.22),
                        .init(color: .white.opacity(0.85), location: 0.32),
                        .init(color: .clear, location: 0.44)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(shell)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.black.opacity(0.07), lineWidth: 0.5)
                        .padding(3.5)
                }
                .overlay {
                    shell.strokeBorder(LinearGradient(colors: [.white, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom),
                                       lineWidth: 0.6)
                }
                .frame(height: Self.depth)
            HStack(spacing: 0) {
                knuckle
                Spacer()
                knuckle.overlay(alignment: .leading) { lights.padding(.leading, 6) }
            }
            .padding(.horizontal, 16)
            RoundedRectangle(cornerRadius: 0.8)
                .fill(Color(white: 0.1))
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.5)).frame(height: 0.3).offset(y: 0.3) }
                .frame(width: GameCard.width + 3, height: 2.4)
                .offset(y: Self.slotLine - 1.2)
        }
        .frame(width: Self.width, height: Self.height)
    }
    private var knuckle: some View {
        Capsule()
            .fill(LinearGradient(stops: [
                .init(color: Color(white: 0.8), location: 0),
                .init(color: .white, location: 0.35),
                .init(color: Color(white: 0.7), location: 1)
            ], startPoint: .top, endPoint: .bottom))
            .overlay { Capsule().stroke(.black.opacity(0.12), lineWidth: 0.4) }
            .frame(width: 32, height: 6.5)
    }

    private var lights: some View {
        HStack(spacing: 2.5) {
            Circle()
                .fill(isPoweredOn ? Palette.ledOn : Palette.ledOff)
                .shadow(color: isPoweredOn ? Palette.ledOn : .clear, radius: 2)
            Circle().fill(Palette.ledOff)
        }
        .frame(height: 1.8)
    }
}
