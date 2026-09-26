import SwiftUI

/// A miniature retail display. Choosing a game lifts its case off the shelf, ready to play.
struct GameSelectionView: View {
    /// The lifted game, owned by the caller so it stays lifted while the device is open.
    @Binding var selection: String?
    @State private var unavailableGame: DisplayGame?
    @State private var shelfOffset: CGFloat = 0
    @State private var slotFrames = SlotFrames()
    /// Only a case picked here flies in; one already lifted when the store appears is just there.
    @State private var liftsIn = false

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 414
            cabinet(scale: scale)
                // Keep the frame below the Duo camera, including configurations that report no top inset.
                .padding(.top, max(16, 80 - geometry.safeAreaInsets.top))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay {
                    if let game = DisplayGame.all.first(where: { $0.id == selection }) {
                        LiftedCase(game: game, caseWidth: 150 * scale, liftsIn: liftsIn,
                                   slotFrame: { slotFrames.frames[game.id] },
                                   onPutBack: { selection = nil })
                    }
                }
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .preferredColorScheme(.light)
        .alert(item: $unavailableGame) { game in
            Alert(title: Text("\(game.title) isn’t available yet"),
                  message: Text("Only Mario Kart DS is currently included. Choose its case to play."),
                  dismissButton: .default(Text("OK")))
        }
    }

    private func cabinet(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            StoreHeader(scale: s)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(0..<((DisplayGame.all.count + 1) / 2), id: \.self) { row in
                        GameShelf(games: Array(DisplayGame.all.dropFirst(row * 2).prefix(2)), scale: s,
                                  liftedGame: selection, slotFrames: slotFrames) { game in
                            if game.id == "kart" {
                                liftsIn = true
                                selection = game.id
                            } else {
                                unavailableGame = game
                            }
                        }
                    }
                }
                .padding(.top, 18 * s)
                .padding(.bottom, 12 * s)
                .background {
                    GeometryReader { content in
                        Color.clear.preference(key: ShelfOffsetKey.self,
                                               value: content.frame(in: .named("shelves")).minY)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            .coordinateSpace(name: "shelves")
            .onPreferenceChange(ShelfOffsetKey.self) { shelfOffset = $0 }
            // Draw only the viewport, wrapping the pattern phase with the content offset.
            // This keeps the metal continuous through either end's rubber-band overscroll.
            .background {
                Pegboard(verticalOffset: shelfOffset)
                    .overlay(alignment: .leading) { Color.black.opacity(0.07).frame(width: 5 * s) }
            }

        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 45 * s, bottomLeadingRadius: 3 * s, bottomTrailingRadius: 3 * s, topTrailingRadius: 45 * s))
        .padding(12 * s)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 58 * s, bottomLeadingRadius: 8 * s, bottomTrailingRadius: 8 * s, topTrailingRadius: 58 * s)
                .fill(LinearGradient(stops: [
                    .init(color: Color(red: 1, green: 0.22, blue: 0.13), location: 0),
                    .init(color: Color(red: 0.79, green: 0.035, blue: 0.015), location: 0.3),
                    .init(color: Color(red: 0.95, green: 0.075, blue: 0.025), location: 0.65),
                    .init(color: Color(red: 0.57, green: 0.025, blue: 0.015), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: 57 * s, bottomLeadingRadius: 8 * s, bottomTrailingRadius: 8 * s, topTrailingRadius: 57 * s)
                        .strokeBorder(.white.opacity(0.35), lineWidth: s)
                        .padding(s)
                }
                .shadow(color: .black.opacity(0.65), radius: 12 * s, x: 6 * s, y: 14 * s)
        }
    }
}

private struct StoreHeader: View {
    let scale: CGFloat
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.98), Color(red: 0.94, green: 0.93, blue: 0.87), Color(white: 0.82)], startPoint: .top, endPoint: .bottom)
            Grain().opacity(0.06)
            DSLogo(scale: scale)
                .padding(.top, 5 * scale)
            VStack {
                Spacer()
                Rectangle().fill(.white.opacity(0.9)).frame(height: 3 * scale)
                Rectangle().fill(Color(white: 0.62)).frame(height: 2 * scale)
            }
        }
        .frame(height: 147 * scale)
        .shadow(color: .black.opacity(0.22), radius: 4 * scale, y: 5 * scale)
        .zIndex(1)
    }
}

private struct DSLogo: View {
    let scale: CGFloat
    var body: some View {
        HStack(alignment: .center, spacing: 2 * scale) {
            Text("NINTENDO")
                .font(.system(size: 28 * scale, weight: .light, design: .rounded))
                .tracking(-1.5 * scale)
            VStack(spacing: 3 * scale) {
                RoundedRectangle(cornerRadius: 1.5 * scale).stroke(Color(white: 0.48), lineWidth: 2 * scale)
                RoundedRectangle(cornerRadius: 1.5 * scale).stroke(Color(white: 0.48), lineWidth: 2 * scale)
            }
            .frame(width: 15 * scale, height: 32 * scale)
            Text("DS")
                .font(.system(size: 53 * scale, weight: .medium, design: .rounded))
                .tracking(-5 * scale)
            Text("™").font(.system(size: 6 * scale)).offset(x: 4 * scale, y: 17 * scale)
        }
        .foregroundStyle(Color(white: 0.08))
        .shadow(color: .white, radius: 0, y: scale)
        .accessibilityLabel("Nintendo DS")
    }
}

private struct DisplayGame: Identifiable {
    let id: String
    let title: String
    static let all = [
        DisplayGame(id: "mario", title: "New Super Mario Bros."),
        DisplayGame(id: "kart", title: "Mario Kart DS"),
        DisplayGame(id: "animal", title: "Animal Crossing"),
        DisplayGame(id: "pokemon", title: "Pokémon Platinum"),
        DisplayGame(id: "zelda", title: "Phantom Hourglass"),
        DisplayGame(id: "kirby", title: "Kirby Super Star Ultra"),
        DisplayGame(id: "layton", title: "Professor Layton"),
        DisplayGame(id: "dogs", title: "Nintendogs"),
        DisplayGame(id: "heartgold", title: "Pokémon HeartGold")
    ]
}

/// Where each case sits on the shelf. Not observed: it's only read when a case flies back.
private final class SlotFrames {
    var frames: [String: CGRect] = [:]
}

private struct GameCase: View {
    let game: DisplayGame
    let scale: CGFloat
    var body: some View {
        Image(game.id)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(2 * scale)
            .background(Color(white: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 2 * scale))
            .overlay {
                RoundedRectangle(cornerRadius: 2 * scale)
                    .strokeBorder(Color.white.opacity(0.65), lineWidth: scale)
            }
            .overlay(alignment: .leading) {
                LinearGradient(colors: [.black.opacity(0.22), .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 5 * scale)
            }
            .shadow(color: .black.opacity(0.4), radius: 3 * scale, x: 4 * scale, y: 4 * scale)
    }
}

/// The chosen game, lifted off its shelf into the middle of the dimmed store until the device opens.
/// It follows the finger; letting go far enough away, or flicking it, puts it back on the shelf.
private struct LiftedCase: View {
    let game: DisplayGame
    let caseWidth: CGFloat
    let slotFrame: () -> CGRect?
    let onPutBack: () -> Void

    @State private var isLifted: Bool
    @State private var drag = CGSize.zero
    @State private var isPuttingBack = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let putBackDistance: CGFloat = 110
    private static let flickSpeed: CGFloat = 700

    init(game: DisplayGame, caseWidth: CGFloat, liftsIn: Bool,
         slotFrame: @escaping () -> CGRect?, onPutBack: @escaping () -> Void) {
        self.game = game
        self.caseWidth = caseWidth
        self.slotFrame = slotFrame
        self.onPutBack = onPutBack
        _isLifted = State(initialValue: !liftsIn)
    }

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let slot = slotCenter(in: origin) ?? center
            let caseHeight = caseWidth * 0.95
            let liftedScale = min(proxy.size.width * 0.6 / caseWidth, proxy.size.height * 0.45 / caseHeight)
            // Dragging away loosens the store's hold on the case: it shrinks a little and the dim lifts.
            let pull = min(1, hypot(drag.width, drag.height) / 300)
            // Under Reduce Motion the case only fades in and out, in the middle.
            let isCentered = isLifted || reduceMotion

            ZStack {
                Color.black
                    .opacity(isLifted ? 0.7 * (1 - 0.5 * pull) : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { putBack(center: center, origin: origin) }
                    .accessibilityHidden(true)

                hint
                    .position(x: center.x, y: center.y + caseHeight * liftedScale / 2 + 48)

                GameCase(game: game, scale: caseWidth / 150)
                    .frame(width: caseWidth)
                    .scaleEffect(isCentered ? liftedScale * (1 - 0.15 * pull) : 1)
                    .shadow(color: .black.opacity(isLifted ? 0.45 : 0), radius: isLifted ? 24 : 0, y: isLifted ? 16 : 0)
                    .opacity(isLifted || !reduceMotion ? 1 : 0)
                    .position(isCentered ? center : slot)
                    .offset(drag)
                    .gesture(
                        DragGesture()
                            .onChanged { drag = $0.translation }
                            .onEnded { release($0, center: center, origin: origin) }
                    )
                    .allowsHitTesting(!isPuttingBack)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(game.title)
                    .accessibilityValue("Ready to play")
                    .accessibilityHint("Open iPhone to play.")
                    .accessibilityAction(named: "Put Back on Shelf") { putBack(center: center, origin: origin) }
                    .accessibilityAction(.escape) { putBack(center: center, origin: origin) }
            }
            .accessibilityAddTraits(.isModal)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isLifted)
        .onAppear {
            guard !isLifted else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(duration: 0.5, bounce: 0)) {
                isLifted = true
            }
        }
    }

    private var hint: some View {
        let isShown = isLifted && drag == .zero && !isPuttingBack
        return VStack(spacing: 6) {
            Text("Open to Play")
                .font(.title2.weight(.semibold))
                .fontDesign(.rounded)
            Text("Or drag the case back to the shelf")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .fixedSize()
        // Arrives once the case has landed; gets out of the way as soon as it's grabbed.
        .opacity(isShown ? 1 : 0)
        .animation(isShown ? .easeOut(duration: 0.3).delay(0.25) : .easeOut(duration: 0.15), value: isShown)
        .accessibilityHidden(true)
    }

    /// Read fresh each time: the shelf may have laid out since this view last updated.
    private func slotCenter(in origin: CGPoint) -> CGPoint? {
        slotFrame().map { CGPoint(x: $0.midX - origin.x, y: $0.midY - origin.y) }
    }

    private func release(_ value: DragGesture.Value, center: CGPoint, origin: CGPoint) {
        let travel = value.translation
        let velocity = value.velocity
        let isFlickedAway = hypot(velocity.width, velocity.height) > Self.flickSpeed
            && velocity.width * travel.width + velocity.height * travel.height > 0
        if hypot(travel.width, travel.height) > Self.putBackDistance || isFlickedAway {
            putBack(center: center, origin: origin, velocity: velocity)
            return
        }

        // Spring back to the middle, carrying the finger's speed (as a fraction of the way back per second).
        let distanceSquared = travel.width * travel.width + travel.height * travel.height
        let speed = distanceSquared > 1 ? -(velocity.width * travel.width + velocity.height * travel.height) / distanceSquared : 0
        withAnimation(reduceMotion ? .easeOut(duration: 0.2)
                      : .interpolatingSpring(duration: 0.35, bounce: 0.25, initialVelocity: min(max(speed, -10), 10))) {
            drag = .zero
        }
    }

    private func putBack(center: CGPoint, origin: CGPoint, velocity: CGSize = .zero) {
        guard !isPuttingBack else { return }
        isPuttingBack = true

        let animation: Animation
        if reduceMotion {
            animation = .easeOut(duration: 0.2)
        } else {
            // Leave the finger at its speed, projected onto the flight back to the slot.
            let slot = slotCenter(in: origin) ?? center
            let path = CGSize(width: slot.x - center.x - drag.width, height: slot.y - center.y - drag.height)
            let distanceSquared = path.width * path.width + path.height * path.height
            let speed = distanceSquared > 1 ? (velocity.width * path.width + velocity.height * path.height) / distanceSquared : 0
            animation = .interpolatingSpring(duration: 0.45, bounce: 0, initialVelocity: min(max(speed, 0), 10))
        }

        withAnimation(animation, completionCriteria: .logicallyComplete) {
            isLifted = false
            if !reduceMotion { drag = .zero }
        } completion: {
            onPutBack()
        }
    }
}

private struct GameShelf: View {
    let games: [DisplayGame]
    let scale: CGFloat
    let liftedGame: String?
    let slotFrames: SlotFrames
    let onSelect: (DisplayGame) -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 30 * scale) {
                ForEach(games) { game in
                    Button { onSelect(game) } label: {
                        GameCase(game: game, scale: scale)
                    }
                    .frame(width: 150 * scale)
                    .buttonStyle(.plain)
                    // The lifted case is drawn above the store; leave its spot empty.
                    .opacity(liftedGame == game.id ? 0 : 1)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                        slotFrames.frames[game.id] = $0
                    }
                    .accessibilityLabel(game.title)
                    .accessibilityHint(game.id == "kart" ? "Takes the game off the shelf, ready to play" : "Shows game availability")
                }
                if games.count == 1 {
                    Color.clear.frame(width: 150 * scale, height: 1)
                }
            }
            .padding(.horizontal, 30 * scale)
            .padding(.top, 8 * scale)
            .padding(.bottom, 0)
            .frame(height: 158 * scale, alignment: .bottom)
            Rectangle()
                .fill(LinearGradient(colors: [Color(white: 0.68), Color(white: 0.92), .white], startPoint: .top, endPoint: .bottom))
                .frame(height: 9 * scale)
            Rectangle()
                .fill(LinearGradient(stops: [
                    .init(color: .white, location: 0), .init(color: Color(white: 0.89), location: 0.15),
                    .init(color: Color(white: 0.84), location: 0.8), .init(color: Color(white: 0.59), location: 1)
                ], startPoint: .top, endPoint: .bottom))
                .frame(height: 20 * scale)
            .shadow(color: .black.opacity(0.3), radius: 4 * scale, y: 6 * scale)
            .zIndex(1)
        }
        .padding(.bottom, 8 * scale)
    }
}

private struct ShelfOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct Pegboard: View {
    var verticalOffset: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 390
            Canvas { context, size in
                let pitch = 13 * s
                let phase = verticalOffset.truncatingRemainder(dividingBy: pitch)
                let rowCount = Int(ceil(size.height / pitch)) + 2
                for column in 0..<18 {
                    for row in -2..<rowCount {
                        let rect = CGRect(x: CGFloat(column) * 23 * s + 9 * s, y: CGFloat(row) * pitch + 5 * s + phase, width: 2.4 * s, height: 6 * s)
                        context.fill(Path(roundedRect: rect.offsetBy(dx: 0.6 * s, dy: s), cornerRadius: s), with: .color(.white.opacity(0.9)))
                        context.fill(Path(roundedRect: rect, cornerRadius: 0.7 * s), with: .color(Color(white: 0.34)))
                        context.fill(Path(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1.5 * s), cornerRadius: 0.4 * s), with: .color(.black.opacity(0.55)))
                    }
                }
                for column in [4, 9, 14] {
                    let x = CGFloat(column) * 23 * s
                    context.fill(Path(CGRect(x: x, y: 0, width: s, height: size.height)), with: .color(.black.opacity(0.09)))
                    context.fill(Path(CGRect(x: x + s, y: 0, width: s, height: size.height)), with: .color(.white.opacity(0.65)))
                }
            }
        }
        .background(LinearGradient(colors: [Color(white: 0.78), Color(white: 0.91), Color(white: 0.76)], startPoint: .leading, endPoint: .trailing))
        .overlay { Grain(verticalOffset: verticalOffset).opacity(0.1) }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct Grain: View {
    var verticalOffset: CGFloat = 0
    var body: some View {
        Canvas { context, size in
            for index in 0..<9000 {
                let x = CGFloat((index * 67 + 13) % 997) / 997 * size.width
                let baseY = CGFloat((index * 137 + 29) % 991) / 991 * size.height
                let height = max(size.height, 1)
                let shiftedY = (baseY + verticalOffset).truncatingRemainder(dividingBy: height)
                let y = shiftedY < 0 ? shiftedY + height : shiftedY
                context.fill(Path(CGRect(x: x, y: y, width: 0.6, height: 0.6)), with: .color(index.isMultiple(of: 2) ? .white : .black))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview { GameSelectionView(selection: .constant(nil)) }
