import SwiftUI

/// The chosen game, put in a console in one movement: its case comes off the shelf and opens, and the card
/// flies out of it into the slot of a console lid that slides in to meet it, while the empty case goes back on
/// the shelf. The lid is the size of the display, as if the device itself were the closed console.
/// Putting the game back, by tapping outside or pulling the card out, slides the card out of the slot and the console away;
/// pushing the console away instead slides it off the card, which then goes the other way.
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
    /// How far the card has been pulled out of the slot, towards the left.
    @State private var pull: CGFloat = 0
    /// Let go of while being pulled out, so it leaves at speed instead of starting slowly.
    @State private var isFlung = false
    /// How far the console has been pushed away, towards the right, sliding off the card.
    @State private var shove: CGFloat = 0
    /// Only used under Reduce Motion, where the whole scene fades instead of playing out.
    @State private var opacity: Double
    @State private var lifts = 0
    @State private var pops = 0
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
            let layout = StageLayout(size: proxy.size, caseWidth: caseWidth)
            InsertionStage(insertion: insertion, ejection: ejection, pull: pull, shove: shove, isFlung: isFlung,
                           game: game, layout: layout,
                           shelfSlot: slotFrame, canPull: isSeated && !isPuttingBack,
                           onPull: pullCard, onRelease: releaseCard,
                           onShove: shoveConsole, onShoveRelease: { releaseConsole($0, velocity: $1, layout: layout) },
                           onPutBack: putBack)
                .accessibilityAddTraits(.isModal)
        }
        .opacity(reduceMotion ? opacity : 1)
        .sensoryFeedback(.impact(weight: .light), trigger: lifts)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.5), trigger: pops)
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
        // The card snaps out of its clips as it leaves the case.
        Task {
            try? await Task.sleep(for: .seconds(Self.insertionDuration * Beat.card.lowerBound))
            pops += 1
        }
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

    private func pullCard(by translation: CGFloat) {
        // Out, it follows the finger; in, it's already as far in as it goes.
        pull = translation < 0 ? -translation : -min(6, translation * 0.08)
    }

    private func releaseCard(ejecting: Bool) {
        if ejecting {
            isFlung = true
            putBack()
            return
        }
        let wasOut = pull > 4
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
            pull = 0
        } completion: {
            if wasOut { clicks += 1 }
        }
    }

    private func shoveConsole(by translation: CGFloat) {
        // Away, it follows the finger; back, it only gives a little over the card.
        shove = translation > 0 ? translation : -min(6, -translation * 0.08)
    }

    /// Pushed away, the console carries on off screen at the speed it was let go of,
    /// while the card it left behind goes back the way it came.
    private func releaseConsole(_ pushingAway: Bool, velocity: CGFloat, layout: StageLayout) {
        guard pushingAway else {
            let wasOff = shove > layout.cardSlideLength
            withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                shove = 0
            } completion: {
                if wasOff { clicks += 1 }
            }
            return
        }
        let target = layout.lidAwayOffset - layout.lidRestOffset
        let remaining = max(1, target - shove)
        if !reduceMotion {
            withAnimation(.interpolatingSpring(duration: 0.45, bounce: 0, initialVelocity: max(0, velocity) / remaining)) {
                shove = target
            }
        }
        putBack()
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

    /// The lid rests just far enough right of the display to show the half of the card sticking out.
    var lidRestOffset: CGFloat { cardLength / 2 + 20 }
    var lidAwayOffset: CGFloat { size.width + 40 }

    /// Across the card, which lies on its side to go into the slot.
    var cardWidth: CGFloat { size.height * 0.19 }
    var cardLength: CGFloat { cardWidth * GameCard.aspect }
    /// The card disappears to the right of this line, into the slot.
    func slotLine(lidOffset: CGFloat) -> CGFloat { lidOffset + ConsoleLid.slotDepth }
    /// Where the card lines up with the slot, just clear of it, and how far it then slides:
    /// only halfway in, so the game stays in view. Both follow the lid as it slides in.
    var cardApproachFromSlot: CGFloat { -cardLength / 2 - 10 }
    var cardSlideLength: CGFloat { -cardApproachFromSlot }

    /// The case lies open across the middle, its tray on the right of the spine.
    var openCaseWidth: CGFloat { min(size.width * 0.36, size.height * 0.24 / CaseMetrics.aspect) }
    var openCaseCenter: CGPoint { CGPoint(x: size.width / 2 + openCaseWidth / 2, y: size.height * 0.3) }
}

/// Draws the whole scene for one moment of it. Every frame is a function of the two progresses,
/// so the scene can stop anywhere and be drawn at any point.
private struct InsertionStage: View, Animatable {
    var insertion: Double
    var ejection: Double
    var pull: CGFloat
    var shove: CGFloat
    let isFlung: Bool
    let game: DisplayGame
    let layout: StageLayout
    let shelfSlot: () -> CGRect?
    let canPull: Bool
    let onPull: (CGFloat) -> Void
    let onRelease: (_ ejecting: Bool) -> Void
    let onShove: (CGFloat) -> Void
    let onShoveRelease: (_ pushingAway: Bool, _ velocity: CGFloat) -> Void
    let onPutBack: () -> Void

    private static let space = "stage"

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(insertion, ejection), AnimatablePair(pull, shove)) }
        set {
            (insertion, ejection) = (newValue.first.first, newValue.first.second)
            (pull, shove) = (newValue.second.first, newValue.second.second)
        }
    }

    private var dim: Double {
        0.7 * easeInOut(insertion.through(Beat.dim)) * (1 - easeInOut(ejection.through(EjectBeat.dim)))
    }

    /// Where the lid has got to on its way in.
    private var arrivingLidOffset: CGFloat {
        mix(layout.lidAwayOffset, layout.lidRestOffset, easeOut(insertion.through(Beat.lid)))
    }

    private var lidOffset: CGFloat {
        mix(arrivingLidOffset + shove, layout.lidAwayOffset, easeIn(ejection.through(EjectBeat.lid)))
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
        .coordinateSpace(.named(Self.space))
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

    /// The clips over the card give as it's pressed out past them, then spring back once it's free.
    private var clipFlex: Double {
        let release = Beat.card.lowerBound
        guard insertion >= release else { return easeIn(insertion.through(release - 0.04...release)) }
        let t = (insertion - release) / 0.1
        return t >= 1 ? 0 : cos(t * 3 * .pi) * (1 - t) * (1 - t)
    }

    private var gameCase: some View {
        let pose = casePose(at: insertion)
        let shelved = easeInOut(insertion.through(Beat.shelve))
        let elevation = min(1, 2 * pose.openness)
        return OpeningCase(game: game, openness: pose.openness, holdsCard: insertion < Beat.card.lowerBound, clipFlex: clipFlex)
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
        // Off once it's been pushed clear of the card.
        ConsoleLid(isPoweredOn: insertion >= Beat.card.upperBound && ejection == 0 && shove < layout.cardSlideLength,
                   cardWidth: layout.cardWidth)
            .shadow(color: .black.opacity(0.5), radius: 24, x: -6)
            .offset(x: lidOffset)
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
                    .onChanged { onShove($0.translation.width) }
                    .onEnded { value in
                        // As generous as pulling the card out: a quarter of the way, a flick, or heading off screen.
                        onShoveRelease(value.translation.width > layout.size.width * 0.25
                                       || value.velocity.width > 250
                                       || value.predictedEndTranslation.width > layout.size.width * 0.5,
                                       value.velocity.width)
                    },
                isEnabled: canPull
            )
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
        // The card meets the slot wherever the lid has got to, so it stays on screen
        // while the lid is still sliding in, and the lid finishes by closing round it.
        let slotLine = layout.slotLine(lidOffset: arrivingLidOffset)
        let approach = CGPoint(x: slotLine + layout.cardApproachFromSlot, y: layout.size.height / 2)
        let seated = CGPoint(x: slotLine, y: approach.y)
        // Pulling back before the approach makes the swoop end heading into the slot.
        let control = CGPoint(x: approach.x - 40, y: approach.y)

        // Split the movement so the speed carries straight through the approach.
        let swoopSpeed: CGFloat = 2 * 40
        let split = swoopSpeed / (swoopSpeed + layout.cardSlideLength)
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

        let ejecting = ejection.through(EjectBeat.card)
        let ejected = isFlung ? 1 - (1 - ejecting) * (1 - ejecting) : easeIn(ejecting)
        center.x -= pull + ejected * (seated.x - pull + layout.cardLength / 2 + 20)

        return GameCard(game: game)
            .frame(width: GameCard.width, height: GameCard.width * GameCard.aspect)
            // Only the half sticking out of the slot can be grabbed.
            .contentShape(Rectangle().size(width: GameCard.width, height: GameCard.width * GameCard.aspect / 2))
            .scaleEffect(width / GameCard.width * (1 + 0.12 * raised))
            // Contacts first, so the label faces up and the grip sticks out.
            .rotationEffect(.degrees(-90 * turned))
            .shadow(color: .black.opacity(0.35 + 0.15 * raised), radius: 3 + 10 * raised, y: 2 + 8 * raised)
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
                    .onChanged { onPull($0.translation.width) }
                    .onEnded { value in
                        // Generous, so that any deliberate tug or flick out counts: pulled a fifth of the way,
                        // moving out at all briskly, or heading out of the slot if the finger carried on.
                        onRelease(-value.translation.width > layout.cardLength * 0.2
                                  || value.velocity.width < -250
                                  || -value.predictedEndTranslation.width > layout.cardLength * 0.5)
                    },
                isEnabled: canPull
            )
            .position(center)
            .frame(width: layout.size.width, height: layout.size.height)
            .mask(alignment: .leading) {
                Rectangle().frame(width: max(0, layout.slotLine(lidOffset: lidOffset)))
            }
            .allowsHitTesting(canPull)
            .accessibilityHidden(true)
    }
}

/// A case's proportions, in the units of a case 150 points wide.
private enum CaseMetrics {
    static let width: CGFloat = 150
    /// The cover art's own aspect, plus the plastic around it.
    static let height: CGFloat = 146 * 462 / 512 + 4
    static var aspect: CGFloat { height / width }
    /// Open, the spine lies flat between the two halves; it's drawn with the tray.
    static let spineWidth: CGFloat = 11
    /// The wall standing round each half.
    static let rim: CGFloat = 3
    static let cornerRadius: CGFloat = 3
    static let cardWidth: CGFloat = 44
    static let cardCenter = CGPoint(x: 81, y: 80)
}

/// The case, opening like a book around its spine. Past halfway, the cover shows its inside.
private struct OpeningCase: View {
    let game: DisplayGame
    let openness: Double
    let holdsCard: Bool
    var clipFlex: Double = 0

    var body: some View {
        let turn = sin(openness * .pi)
        CaseTray(game: game, holdsCard: holdsCard, clipFlex: clipFlex)
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
                // Shaded in proportion, so the white inside doesn't go grey.
                .colorMultiply(Color(white: 1 - 0.25 * turn))
                .rotation3DEffect(.degrees(-180 * openness), axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.45)
            }
    }
}

/// The back of the printed insert, seen through the plastic: warm white, lit from above.
private let insertPaper = LinearGradient(colors: [Color(red: 0.97, green: 0.965, blue: 0.95),
                                                  Color(red: 0.87, green: 0.865, blue: 0.85)],
                                         startPoint: .top, endPoint: .bottom)

/// Clear plastic only tints what's under it, a little cool.
private let clearPlastic = Color(red: 0.78, green: 0.84, blue: 0.89).opacity(0.4)

/// Where the plastic turns, it catches the light on top and bends it away underneath.
private let moldedEdge = LinearGradient(stops: [
    .init(color: .white.opacity(0.95), location: 0),
    .init(color: .black.opacity(0.12), location: 0.45),
    .init(color: .black.opacity(0.45), location: 1)
], startPoint: .top, endPoint: .bottom)

/// A part molded in the clear plastic, standing up off the paper. It casts no shadow of its own:
/// whatever groups the parts shades them all at once.
private struct Molding: View {
    let path: Path

    var body: some View {
        path.fill(clearPlastic)
            .overlay { path.stroke(moldedEdge, lineWidth: 1.1).clipShape(path) }
    }
}

private func rounded(_ rect: CGRect, _ radius: CGFloat) -> Path {
    Path(roundedRect: rect, cornerRadius: radius)
}

private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
}

/// A loop of plastic: a rounded block with a hole through it.
private func loop(_ outer: CGRect, _ radius: CGFloat, thickness: CGFloat) -> Path {
    rounded(outer, radius).subtracting(rounded(outer.insetBy(dx: thickness, dy: thickness), max(0.5, radius - thickness)))
}

/// A reflection of the room's window on the inside of the shell. It's laid out across the whole open case,
/// `span` giving where this half sits in it, so it carries on over the spine.
private struct ShellGloss: View {
    let span: ClosedRange<CGFloat>

    var body: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(0), location: 0.28),
            .init(color: .white.opacity(0.12), location: 0.4),
            .init(color: .white.opacity(0.07), location: 0.48),
            .init(color: .white.opacity(0), location: 0.56),
            .init(color: .white.opacity(0), location: 0.59),
            .init(color: .white.opacity(0.18), location: 0.594),
            .init(color: .white.opacity(0), location: 0.6)
        ], startPoint: UnitPoint(x: span.lowerBound, y: -0.2), endPoint: UnitPoint(x: span.upperBound, y: 1.2))
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

/// One half of the shell: the paper under it, and the wall standing all the way round, which shades the paper
/// just inside it, most under the top.
private struct ShellHalf: View {
    let rect: CGRect
    let radii: RectangleCornerRadii

    var body: some View {
        let rim = CaseMetrics.rim
        let outer = UnevenRoundedRectangle(cornerRadii: radii).path(in: rect)
        let inset = RectangleCornerRadii(topLeading: max(0.5, radii.topLeading - rim),
                                         bottomLeading: max(0.5, radii.bottomLeading - rim),
                                         bottomTrailing: max(0.5, radii.bottomTrailing - rim),
                                         topTrailing: max(0.5, radii.topTrailing - rim))
        let inner = UnevenRoundedRectangle(cornerRadii: inset).path(in: rect.insetBy(dx: rim, dy: rim))
        ZStack {
            outer.fill(insertPaper)
            inner.fill(insertPaper.shadow(.inner(color: .black.opacity(0.4), radius: 2.6, y: 2)))
            Rectangle().fill(ShaderLibrary.paperFibers()).clipShape(outer)
            // The wall's top, clear and a little thick, so it greys the paper's edge under it.
            outer.subtracting(inner).fill(clearPlastic)
            outer.stroke(moldedEdge, lineWidth: 1).clipShape(outer)
            UnevenRoundedRectangle(cornerRadii: radii).path(in: rect.insetBy(dx: 1.3, dy: 1.3))
                .stroke(.white.opacity(0.6), lineWidth: 0.35)
            // The wall's inside face: in shade at the top, catching the light at the bottom.
            inner.stroke(LinearGradient(colors: [.black.opacity(0.4), .black.opacity(0.1), .white.opacity(0.9)],
                                        startPoint: .top, endPoint: .bottom), lineWidth: 0.7)
        }
    }
}

/// The tray: the spine, and beside it the cradle the card clips into, the pair of clips for a Game Boy Advance
/// cartridge above it, and the latch the cover closes on.
private struct CaseTray: View {
    let game: DisplayGame
    let holdsCard: Bool
    /// How far the clips holding the card are pushed outwards, springing back once it's out.
    let clipFlex: Double

    private static let w = CaseMetrics.width
    private static let h = CaseMetrics.height
    private static let spine = CaseMetrics.spineWidth
    private static let card = CGRect(x: CaseMetrics.cardCenter.x - CaseMetrics.cardWidth / 2,
                                     y: CaseMetrics.cardCenter.y - CaseMetrics.cardWidth * GameCard.aspect / 2,
                                     width: CaseMetrics.cardWidth, height: CaseMetrics.cardWidth * GameCard.aspect)
    /// The pocket the card sits in, just loose round it.
    private static let pocket = card.insetBy(dx: -0.7, dy: -0.7)
    private static let rib: CGFloat = 2.2
    /// A scoop out of the cradle's side, for a thumb to push the card out by.
    private static let scoop = CGPoint(x: pocket.maxX + rib / 2, y: pocket.midY)
    private static let scoopRadius: CGFloat = 8

    var body: some View {
        let w = Self.w, h = Self.h, spine = Self.spine
        let corner = CaseMetrics.cornerRadius
        ZStack {
            spineStrip
            ShellHalf(rect: CGRect(x: spine, y: 0, width: w - spine, height: h),
                      radii: RectangleCornerRadii(topLeading: 0.8, bottomLeading: 0.8, bottomTrailing: corner, topTrailing: corner))
            ShellGloss(span: -1...1)
            scoopFloor
            ZStack {
                cradleFloor.opacity(holdsCard ? 0 : 1)
                Molding(path: cradle)
                Molding(path: cartridgeClips)
                Molding(path: latch)
                Molding(path: spineMarks)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 0.7, y: 0.9)
            if holdsCard {
                GameCard(game: game)
                    .frame(width: GameCard.width, height: GameCard.width * GameCard.aspect)
                    .scaleEffect(CaseMetrics.cardWidth / GameCard.width)
                    .shadow(color: .black.opacity(0.45), radius: 0.5, y: 0.5)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1.5)
                    .position(CaseMetrics.cardCenter)
            }
            Molding(path: cardClips)
                .compositingGroup()
                .shadow(color: .black.opacity(0.35), radius: 0.6, y: 0.8)
        }
        .frame(width: w, height: h)
        .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(bottomTrailing: corner, topTrailing: corner)))
    }

    /// The spine, flat between the walls of the two halves, with the hinge along its outer edge.
    private var spineStrip: some View {
        let strip = CGRect(x: 0, y: 0, width: Self.spine, height: Self.h)
        return ZStack {
            Path(strip).fill(insertPaper.shadow(.inner(color: .black.opacity(0.28), radius: 2)))
            Path(strip).fill(ShaderLibrary.paperFibers())
            Path(strip).fill(LinearGradient(colors: [.black.opacity(0.22), .clear, .black.opacity(0.08)],
                                            startPoint: .leading, endPoint: .trailing))
            // The hinge: a thin groove, lit along its far lip.
            Path(CGRect(x: 0, y: 0, width: 0.8, height: Self.h)).fill(.black.opacity(0.3))
            Path(CGRect(x: 0.8, y: 0, width: 0.4, height: Self.h)).fill(.white.opacity(0.7))
        }
    }

    private var spineMarks: Path {
        let x = Self.spine / 2 + 0.3, mid = Self.h / 2
        var path = loop(CGRect(x: x - 2.4, y: mid - 5.5, width: 4.8, height: 11), 1.2, thickness: 1.2)
        path.addPath(circle(CGPoint(x: x, y: mid - 26), 1.4))
        path.addPath(circle(CGPoint(x: x, y: mid + 26), 1.4))
        return path
    }

    /// The rib round the pocket, bowed out round the thumb scoop.
    private var cradle: Path {
        let outer = Self.pocket.insetBy(dx: -Self.rib, dy: -Self.rib)
        return rounded(outer, 2.4).union(circle(Self.scoop, Self.scoopRadius))
            .subtracting(rounded(Self.pocket, 1).union(circle(Self.scoop, Self.scoopRadius - Self.rib)))
    }

    /// Low ribs across the pocket's floor, under the card.
    private var cradleFloor: some View {
        let pocket = Self.pocket, t: CGFloat = 1.3
        var ribs = Path()
        for third in [1.0, 2.0] as [CGFloat] {
            ribs = ribs
                .union(Path(CGRect(x: pocket.minX + pocket.width * third / 3 - t / 2, y: pocket.minY, width: t, height: pocket.height)))
                .union(Path(CGRect(x: pocket.minX, y: pocket.minY + pocket.height * third / 3 - t / 2, width: pocket.width, height: t)))
        }
        return ZStack {
            // In the rib's shade, deep in the pocket.
            rounded(pocket, 1).fill(Color.clear.shadow(.inner(color: .black.opacity(0.25), radius: 1.5, y: 1)))
            Molding(path: ribs)
        }
    }

    /// The scoop dips below the paper: in the shade of its upper edge, and lit along its lower one.
    private var scoopFloor: some View {
        let radius = Self.scoopRadius - Self.rib
        return Circle()
            .fill(LinearGradient(colors: [.black.opacity(0.4), .black.opacity(0.14), .white.opacity(0.4)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 2 * radius, height: 2 * radius)
            .position(Self.scoop)
            .clipShape(circle(Self.scoop, radius).subtracting(rounded(Self.pocket, 1)))
    }

    /// Two small tabs over each end of the card, which it's pressed past to go in and come out.
    private var cardClips: Path {
        let pocket = Self.pocket, flex = 1.3 * clipFlex
        let size = CGSize(width: 8, height: 3.8)
        var path = Path()
        for x in [pocket.minX + 8, pocket.maxX - 12] {
            path.addPath(rounded(CGRect(x: x - size.width / 2, y: pocket.minY - 1.8 - flex, width: size.width, height: size.height), 0.9))
            path.addPath(rounded(CGRect(x: x - size.width / 2, y: pocket.maxY - 1.6 + flex, width: size.width, height: size.height), 0.9))
        }
        return path
    }

    /// Hooks that would hold a cartridge on its side, above the card.
    private var cartridgeClips: Path {
        let center = CaseMetrics.cardCenter.x, top: CGFloat = 12
        var path = Path()
        for side in [-1.0, 1.0] as [CGFloat] {
            let x = center + side * 24
            let bar = CGRect(x: x - 1.2, y: top, width: 2.4, height: 13)
            let foot = CGRect(x: side < 0 ? x - 1.2 : x + 1.2 - 5.5, y: top, width: 5.5, height: 2.4)
            path.addPath(rounded(bar, 0.6).union(rounded(foot, 0.6)))
        }
        return path
    }

    /// The loop on the tray's open edge that the cover's catch snaps into.
    private var latch: Path {
        let inner = Self.w - CaseMetrics.rim
        return loop(CGRect(x: inner - 4.6, y: Self.h / 2 - 7.5, width: 5.4, height: 15), 1, thickness: 1.5)
    }
}

/// The inside of the cover, with the instruction booklet held along its outer edge by two clips.
/// Its spine is on the right, since that's where it meets the tray once open.
private struct CoverInside: View {
    let game: DisplayGame

    private static let w = CaseMetrics.width
    private static let h = CaseMetrics.height

    var body: some View {
        let w = Self.w, h = Self.h
        let corner = CaseMetrics.cornerRadius
        ZStack {
            ShellHalf(rect: CGRect(x: 0, y: 0, width: w, height: h),
                      radii: RectangleCornerRadii(topLeading: corner, bottomLeading: corner, bottomTrailing: 0.8, topTrailing: 0.8))
            ShellGloss(span: 0...2)
            ZStack {
                Molding(path: foldRib)
                slot
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 0.7, y: 0.9)
            Booklet(game: game)
                .position(x: 9 + Booklet.size.width / 2, y: h / 2)
            Molding(path: bookletClips)
                .compositingGroup()
                .shadow(color: .black.opacity(0.35), radius: 0.7, y: 0.9)
        }
        .frame(width: w, height: h)
        .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: corner, bottomLeading: corner)))
    }

    /// A pair of C-shaped clips on the outer wall, gripping the booklet's edge, and a catch between them.
    private var bookletClips: Path {
        let rim = CaseMetrics.rim
        var path = Path()
        for y in [Self.h * 0.24, Self.h * 0.76] {
            let clip = CGRect(x: rim - 1, y: y - 9, width: 13.5, height: 18)
            path.addPath(rounded(clip, 2).subtracting(rounded(CGRect(x: rim + 3.5, y: y - 5.5, width: 5.5, height: 11), 1)))
        }
        path.addPath(rounded(CGRect(x: rim - 1, y: Self.h / 2 - 4, width: 5, height: 8), 1))
        return path
    }

    /// A rib standing beside the spine.
    private var foldRib: Path {
        rounded(CGRect(x: Self.w - 14, y: Self.h / 2 - 17, width: 1.6, height: 34), 0.8)
    }

    /// A slot through the shell along the top, where the insert shows darker.
    private var slot: some View {
        let rect = CGRect(x: 44, y: 5, width: 62, height: 1.8)
        return ZStack {
            rounded(rect, 0.9).fill(.black.opacity(0.28))
            rounded(rect.offsetBy(dx: 0, dy: 0.9), 0.9).stroke(.white.opacity(0.8), lineWidth: 0.35).clipShape(Rectangle().path(in: rect.insetBy(dx: -1, dy: -1).offsetBy(dx: 0, dy: 1.2)))
        }
    }
}

/// The instruction booklet: the cover art on its front, a few pages' thickness showing at its loose edges.
private struct Booklet: View {
    let game: DisplayGame
    static let artHeight: CGFloat = 116 * 462 / 512
    static let size = CGSize(width: 116, height: artHeight + 9)

    var body: some View {
        let size = Self.size
        VStack(spacing: 0) {
            Image(game.id)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: Self.artHeight)
                .clipped()
            Text("INSTRUCTION BOOKLET")
                .font(.system(size: 4.4, weight: .heavy))
                .tracking(0.9)
                .foregroundStyle(Color(white: 0.25))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.96))
        }
        .frame(width: size.width, height: size.height)
        // Folded at the edge the clips hold, so the loose edge lifts a little towards the light.
        .overlay {
            LinearGradient(stops: [
                .init(color: .black.opacity(0.14), location: 0), .init(color: .black.opacity(0), location: 0.12),
                .init(color: .white.opacity(0), location: 0.8), .init(color: .white.opacity(0.1), location: 1)
            ], startPoint: .leading, endPoint: .trailing)
        }
        .overlay { Rectangle().strokeBorder(.black.opacity(0.22), lineWidth: 0.3) }
        .background(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                ForEach((1...3).reversed(), id: \.self) { page in
                    Rectangle()
                        .fill(Color(white: 0.95 - 0.03 * CGFloat(page)))
                        .overlay { Rectangle().strokeBorder(.black.opacity(0.18), lineWidth: 0.25) }
                        .offset(x: 0.35 * CGFloat(page), y: 0.45 * CGFloat(page))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .shadow(color: .black.opacity(0.3), radius: 0.8, y: 1)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
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
                    .init(color: Color(red: 0.98, green: 0.98, blue: 0.965), location: 0),
                    .init(color: Color(red: 0.94, green: 0.945, blue: 0.93), location: 0.48),
                    .init(color: Color(red: 0.89, green: 0.9, blue: 0.89), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                // The same polished plastic as the open console: a window reflection, and an edge
                // that rolls over, bright where it faces the light.
                ZStack {
                    Gloss()
                    shell
                        .stroke(LinearGradient(colors: [.white, .white.opacity(0.3), .black.opacity(0.1)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 8)
                        .blur(radius: 2)
                }
                .clipShape(shell)
                // Fine parting line where the lid's top meets its polished lip.
                shell
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.6)
                    .padding(14)
                shell
                    .stroke(.white.opacity(0.7), lineWidth: 0.7)
                    .padding(15)
                shell
                    .stroke(LinearGradient(colors: [.white, .black.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                    .padding(0.6)
                hinge(scale: size.height / Self.hingeLength)
            }
        }
    }

    /// The open console's hinge runs 605 of its units across; the lid's fold edge is the same hinge,
    /// so measuring it in those units keeps every part the size it is on the open console.
    private static let hingeLength: CGFloat = 605

    /// The knuckles on the base cap both ends; between them runs the lid's own barrel, flush with it,
    /// with the card slot's mouth below its edge.
    private func hinge(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            knuckle(outerEnd: .top, scale: scale)
                .overlay(alignment: .bottom) {
                    IndicatorLights(axis: .vertical, isOn: isPoweredOn, scale: scale)
                        .padding(.bottom, 9 * scale)
                }
                .zIndex(1)
            HingeBarrel(axis: .vertical, outerEnd: nil, scale: scale)
                .padding(.horizontal, 2.5 * scale)
                .overlay(alignment: .leading) { slot(scale: scale) }
            knuckle(outerEnd: .bottom, scale: scale)
                .zIndex(1)
        }
        .frame(width: 42 * scale)
        .padding(.vertical, 3 * scale)
    }

    private func knuckle(outerEnd: Edge, scale: CGFloat) -> some View {
        HingeBarrel(axis: .vertical, outerEnd: outerEnd, scale: scale)
            .frame(height: 50 * scale)
            .shadow(color: .black.opacity(0.2), radius: 1.5 * scale, x: 1.5 * scale)
    }

    /// The mouth of the card slot, in the base just below the barrel's edge.
    private func slot(scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color(white: 0.1))
            .frame(width: 4 * scale, height: cardWidth * 1.08)
            .overlay(alignment: .trailing) {
                Rectangle().fill(.black.opacity(0.25)).frame(width: 2 * scale).blur(radius: scale).offset(x: 2 * scale)
            }
    }
}
