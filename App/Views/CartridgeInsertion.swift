import SwiftUI

/// The chosen game, put in a console in one movement: its case comes off the shelf and opens, and the card
/// flies out of it into the slot of a console lid that slides in to meet it, while the empty case goes back on
/// the shelf. The lid is the size of the display, as if the device itself were the closed console.
/// Putting the game back slides the card out of the slot, and the console away.
struct CartridgeInsertion: View {
    let game: DisplayGame
    /// The width of a case on the shelf; every pose of the case scales from it.
    let caseWidth: CGFloat
    let slotFrame: () -> CGRect?
    let onPutBack: () -> Void

    @State private var insertion: Double
    @State private var ejection = 0.0
    @State private var isSeated: Bool
    /// A tap before the card is in waits for it, so the card never turns around mid-flight.
    @State private var putsBackWhenSeated = false
    @State private var isPuttingBack = false
    /// Only used under Reduce Motion, where the whole scene fades instead of playing out.
    @State private var opacity: Double
    @State private var lifts = 0
    @State private var clicks = 0
    @State private var ejects = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let insertionDuration: TimeInterval = 1.6
    private static let ejectionDuration: TimeInterval = 0.7

    init(game: DisplayGame, caseWidth: CGFloat, liftsIn: Bool,
         slotFrame: @escaping () -> CGRect?, onPutBack: @escaping () -> Void) {
        self.game = game
        self.caseWidth = caseWidth
        self.slotFrame = slotFrame
        self.onPutBack = onPutBack
        _insertion = State(initialValue: liftsIn ? 0 : 1)
        _isSeated = State(initialValue: !liftsIn)
        _opacity = State(initialValue: liftsIn ? 0 : 1)
    }

    var body: some View {
        GeometryReader { proxy in
            InsertionStage(insertion: insertion, ejection: ejection, game: game,
                           layout: StageLayout(size: proxy.size, caseWidth: caseWidth),
                           shelfSlot: slotFrame, onPutBack: putBack)
                .accessibilityAddTraits(.isModal)
        }
        .opacity(reduceMotion ? opacity : 1)
        .sensoryFeedback(.impact(weight: .light), trigger: lifts)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.8), trigger: clicks)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.6), trigger: ejects)
        .onAppear {
            guard !isSeated else { return }
            if reduceMotion {
                insertion = 1
                isSeated = true
                withAnimation(.easeOut(duration: 0.25)) { opacity = 1 }
            } else {
                insert()
            }
        }
    }

    /// Plays at a constant rate; each part eases itself. The card seating is its own step,
    /// so the haptic lands on the frame it clicks in, while the case carries on back to the shelf.
    private func insert() {
        lifts += 1
        let seated = Beat.card.upperBound
        withAnimation(.linear(duration: Self.insertionDuration * seated)) {
            insertion = seated
        } completion: {
            clicks += 1
            isSeated = true
            if putsBackWhenSeated { putBack() }
            withAnimation(.linear(duration: Self.insertionDuration * (1 - seated))) {
                insertion = 1
            }
        }
    }

    private func putBack() {
        guard isSeated else {
            putsBackWhenSeated = true
            return
        }
        guard !isPuttingBack else { return }
        isPuttingBack = true

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { opacity = 0 } completion: { onPutBack() }
            return
        }
        ejects += 1
        withAnimation(.linear(duration: Self.ejectionDuration)) {
            ejection = 1
        } completion: {
            onPutBack()
        }
    }
}

/// When each part moves, as fractions of the insertion. They overlap, so nothing waits for anything.
private enum Beat {
    static let dim = 0.0...0.3
    /// The case lifts and opens in the same motion.
    static let open = 0.0...0.45
    static let card = 0.18...0.85
    static let lid = 0.38...0.85
    /// The case closes on its way back to the shelf.
    static let shelve = 0.55...1.0
}

/// When each part of putting the game back moves, as fractions of it.
private enum EjectBeat {
    static let card = 0.0...0.7
    static let lid = 0.2...1.0
    static let dim = 0.3...1.0
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

private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
private func easeIn(_ t: Double) -> Double { t * t }

private func mix(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * t }
private func mix(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: mix(a.x, b.x, t), y: mix(a.y, b.y, t))
}

/// Where things rest, in the store's coordinates.
private struct StageLayout {
    let size: CGSize
    let caseWidth: CGFloat

    /// The lid rests this far right of the display, leaving room to see the card go in.
    var lidRestOffset: CGFloat { size.width * 0.37 }
    var lidAwayOffset: CGFloat { size.width + 40 }

    /// Across the card, which lies on its side to go into the slot.
    var cardWidth: CGFloat { size.height * 0.19 }
    var cardLength: CGFloat { cardWidth * GameCard.aspect }
    /// The card disappears to the right of this line, into the slot.
    func slotLine(lidOffset: CGFloat) -> CGFloat { lidOffset + ConsoleLid.slotDepth }
    /// Only halfway in, so the game stays in view.
    var seatedCardCenter: CGPoint {
        CGPoint(x: slotLine(lidOffset: lidRestOffset), y: size.height / 2)
    }
    /// Lined up with the slot, just clear of it.
    var cardApproach: CGPoint {
        CGPoint(x: slotLine(lidOffset: lidRestOffset) - cardLength / 2 - 12, y: size.height / 2)
    }

    /// The case lies open across the middle, its tray on the right of the spine.
    var openCaseWidth: CGFloat { min(size.width * 0.36, size.height * 0.24 / CaseMetrics.aspect) }
    var openCaseCenter: CGPoint { CGPoint(x: size.width / 2 + openCaseWidth / 2, y: size.height * 0.3) }
}

/// Draws the whole scene for one moment of it. Every frame is a function of the two progresses,
/// so the scene can stop anywhere and be drawn at any point.
private struct InsertionStage: View, Animatable {
    var insertion: Double
    var ejection: Double
    let game: DisplayGame
    let layout: StageLayout
    let shelfSlot: () -> CGRect?
    let onPutBack: () -> Void

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(insertion, ejection) }
        set { (insertion, ejection) = (newValue.first, newValue.second) }
    }

    private var dim: Double {
        0.7 * easeInOut(insertion.through(Beat.dim)) * (1 - easeInOut(ejection.through(EjectBeat.dim)))
    }

    private var lidOffset: CGFloat {
        let arrived = mix(layout.lidAwayOffset, layout.lidRestOffset, easeOut(insertion.through(Beat.lid)))
        return mix(arrived, layout.lidAwayOffset, easeIn(ejection.through(EjectBeat.lid)))
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(dim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onPutBack)
                .accessibilityHidden(true)
            gameCase
            lid
            if insertion >= Beat.card.lowerBound { card }
        }
    }

    private var slotCenter: CGPoint {
        shelfSlot().map { CGPoint(x: $0.midX, y: $0.midY) } ?? layout.openCaseCenter
    }

    /// The case's center and width at a point of the insertion.
    private func casePose(at p: Double) -> (center: CGPoint, width: CGFloat, openness: Double) {
        let opened = easeInOut(p.through(Beat.open))
        let shelved = easeInOut(p.through(Beat.shelve))
        let center = mix(mix(slotCenter, layout.openCaseCenter, opened), slotCenter, shelved)
        let width = mix(mix(layout.caseWidth, layout.openCaseWidth, opened), layout.caseWidth, shelved)
        return (center, width, opened - shelved)
    }

    private var gameCase: some View {
        let pose = casePose(at: insertion)
        let shelved = easeInOut(insertion.through(Beat.shelve))
        let elevation = min(1, 2 * pose.openness)
        return OpeningCase(game: game, openness: pose.openness, holdsCard: insertion < Beat.card.lowerBound)
            .frame(width: CaseMetrics.width, height: CaseMetrics.height)
            .scaleEffect(pose.width / CaseMetrics.width)
            .shadow(color: .black.opacity(0.45 * elevation), radius: 18 * elevation, y: 12 * elevation)
            // Back on the shelf, it sits in the store's shade like everything else there.
            .colorMultiply(Color(white: 1 - dim * shelved))
            .position(pose.center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var lid: some View {
        ConsoleLid(isPoweredOn: insertion >= Beat.card.upperBound && ejection == 0,
                   cardWidth: layout.cardWidth)
            .shadow(color: .black.opacity(0.5), radius: 24, x: -6)
            .offset(x: lidOffset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(game.title)
            .accessibilityValue("In the console")
            .accessibilityHint("Open iPhone to play.")
            .accessibilityAction(named: "Put Back on Shelf", onPutBack)
            .accessibilityAction(.escape, onPutBack)
    }

    /// The card comes out of the tray and swoops round to line up with the slot, turning onto its side,
    /// then slides straight in: one eased movement over both legs.
    private var card: some View {
        let handoff = casePose(at: Beat.card.lowerBound)
        let caseScale = handoff.width / CaseMetrics.width
        let start = CGPoint(x: handoff.center.x + (CaseMetrics.cardCenter.x - CaseMetrics.width / 2) * caseScale,
                            y: handoff.center.y + (CaseMetrics.cardCenter.y - CaseMetrics.height / 2) * caseScale)
        let startWidth = CaseMetrics.cardWidth * caseScale
        let approach = layout.cardApproach
        let seated = layout.seatedCardCenter
        // Pulling back before the approach makes the swoop end heading into the slot.
        let control = CGPoint(x: approach.x - 40, y: approach.y)

        // Split the movement so the speed carries straight through the approach.
        let swoopSpeed = 2 * hypot(approach.x - control.x, approach.y - control.y)
        let slideLength = seated.x - approach.x
        let split = swoopSpeed / (swoopSpeed + slideLength)
        let u = easeInOut(insertion.through(Beat.card))

        var center: CGPoint
        let turned: Double
        if u < split {
            let t = u / split
            let a = mix(start, control, t), b = mix(control, approach, t)
            center = mix(a, b, t)
            turned = easeInOut(t)
        } else {
            center = mix(approach, seated, (u - split) / (1 - split))
            turned = 1
        }
        let width = mix(startWidth, layout.cardWidth, turned)
        let raised = sin(min(1, u / split) * .pi)

        let ejected = easeIn(ejection.through(EjectBeat.card))
        center.x -= ejected * (seated.x + layout.cardLength / 2 + 20)

        return GameCard(game: game)
            .frame(width: GameCard.width, height: GameCard.width * GameCard.aspect)
            .scaleEffect(width / GameCard.width * (1 + 0.12 * raised))
            // Contacts first, so the label faces up and the grip sticks out.
            .rotationEffect(.degrees(-90 * turned))
            .shadow(color: .black.opacity(0.35 + 0.15 * raised), radius: 3 + 10 * raised, y: 2 + 8 * raised)
            .position(center)
            .frame(width: layout.size.width, height: layout.size.height)
            .mask(alignment: .leading) {
                Rectangle().frame(width: max(0, layout.slotLine(lidOffset: lidOffset)))
            }
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
                    CoverInside()
                        .scaleEffect(x: -1)
                        .opacity(openness < 0.5 ? 0 : 1)
                }
                // Shaded in proportion, so the dark plastic inside doesn't go black.
                .colorMultiply(Color(white: 1 - 0.25 * turn))
                .rotation3DEffect(.degrees(-180 * openness), axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.45)
            }
    }
}

/// Lit from above, so the two halves of an open case carry on into each other across the spine.
private let casePlastic = LinearGradient(colors: [Color(white: 0.25), Color(white: 0.15)],
                                         startPoint: .top, endPoint: .bottom)

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

/// The inside of the cover: bare plastic. Its spine is on the right, since that's where it meets the tray once open.
private struct CoverInside: View {
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
        }
        .frame(width: CaseMetrics.width, height: CaseMetrics.height)
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

/// The console's lid, closed, seen from above: shaped like the display, with the hinge down the left edge
/// and the card slot in it, between the hinge's two knuckles.
private struct ConsoleLid: View {
    /// How far into the edge the card disappears.
    static let slotDepth: CGFloat = 3

    let isPoweredOn: Bool
    let cardWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shell = ConcentricRectangle(corners: .concentric(minimum: .fixed(10)))
            ZStack(alignment: .leading) {
                shell.fill(LinearGradient(stops: [
                    .init(color: Palette.shellLight, location: 0),
                    .init(color: Color(white: 0.95), location: 0.55),
                    .init(color: Palette.shellDark, location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.2),
                    .init(color: .white.opacity(0.85), location: 0.3),
                    .init(color: .clear, location: 0.42)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(shell)
                shell
                    .stroke(.black.opacity(0.07), lineWidth: 1)
                    .padding(14)
                shell
                    .stroke(LinearGradient(colors: [.white, .black.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                    .padding(0.6)
                VStack(spacing: 0) {
                    knuckle.overlay(alignment: .bottom) { lights.padding(.bottom, 16) }
                    slot.frame(height: cardWidth * 1.08)
                    knuckle
                }
                .padding(.vertical, size.height * 0.07)
            }
        }
    }

    private var knuckle: some View {
        Capsule()
            .fill(LinearGradient(stops: [
                .init(color: Color(white: 0.72), location: 0),
                .init(color: .white, location: 0.4),
                .init(color: Color(white: 0.78), location: 1)
            ], startPoint: .leading, endPoint: .trailing))
            .overlay { Capsule().stroke(.black.opacity(0.12), lineWidth: 0.7) }
            .frame(width: 20)
            .padding(.vertical, 6)
    }

    private var slot: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(white: 0.1))
                .frame(width: 6)
                .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.5)).frame(width: 0.6).offset(x: 0.6) }
            Spacer(minLength: 0)
        }
        .frame(width: 20)
    }

    private var lights: some View {
        VStack(spacing: 5) {
            Circle()
                .fill(isPoweredOn ? Palette.ledOn : Palette.ledOff)
                .shadow(color: isPoweredOn ? Palette.ledOn : .clear, radius: 3)
            Circle().fill(Palette.ledOff)
        }
        .frame(width: 4)
    }
}
