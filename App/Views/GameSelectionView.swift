import SwiftUI

/// A miniature retail display. Choosing a game takes its case off the shelf and puts its card in a console, ready to play.
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
                .padding(.horizontal, 8 * scale)
                .padding(.bottom, 8 * scale)
                .padding(.top, max(16, 80 - geometry.safeAreaInsets.top))
                .frame(width: geometry.size.width, height: geometry.size.height)
                // The overlay shares this space's origin, so slot frames measured in it need no converting.
                .coordinateSpace(.named(StoreSpace.name))
                .overlay {
                    if let game = DisplayGame.all.first(where: { $0.id == selection }) {
                        CartridgeInsertion(game: game, caseWidth: 150 * scale, liftsIn: liftsIn,
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
                  message: Text("Its ROM wasn’t bundled into this build. Put it in ROM/\(game.id).zip and rebuild."),
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
                            if game.isBundled {
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
        .clipShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(32 * s)), isUniform: true))
        .overlay {
            ConcentricRectangle(corners: .concentric(minimum: .fixed(32 * s)), isUniform: true)
                .stroke(.black.opacity(0.28), lineWidth: 1.5 * s)
                .allowsHitTesting(false)
        }
        .padding(11 * s)
        .background { CabinetFrame(scale: s) }

    }
}

/// Molded red ABS: a dark seam, a polished bevel, and a quieter satin face.
private struct CabinetFrame: View {
    let scale: CGFloat
    private var contour: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(43 * scale)), isUniform: true)
    }

    var body: some View {
        ZStack {
            contour.fill(Color(red: 0.34, green: 0.025, blue: 0.018))
            contour.fill(LinearGradient(stops: [
                .init(color: Color(red: 1, green: 0.27, blue: 0.20), location: 0),
                .init(color: Color(red: 0.87, green: 0.045, blue: 0.025), location: 0.25),
                .init(color: Color(red: 0.72, green: 0.025, blue: 0.016), location: 0.8),
                .init(color: Color(red: 0.48, green: 0.02, blue: 0.015), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(scale)
            contour.stroke(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.08), .black.opacity(0.3)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: scale)
                .padding(1.8 * scale)
            contour.stroke(.black.opacity(0.16), lineWidth: 0.7 * scale)
                .padding(7.5 * scale)
            contour.stroke(.white.opacity(0.18), lineWidth: 0.7 * scale)
                .padding(8.5 * scale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct StoreHeader: View {
    let scale: CGFloat
    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Color(white: 0.99), location: 0),
                .init(color: Color(red: 0.95, green: 0.95, blue: 0.92), location: 0.5),
                .init(color: Color(white: 0.82), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            Grain().opacity(0.035)
            DSStoreLogo(scale: scale)
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(.white.opacity(0.95)).frame(height: 2 * scale)
                Rectangle().fill(Color(white: 0.63)).frame(height: scale)
                Rectangle().fill(LinearGradient(colors: [Color(white: 0.91), Color(white: 0.75)],
                                                startPoint: .top, endPoint: .bottom))
                    .frame(height: 5 * scale)
            }
        }
        .frame(height: 132 * scale)
        .shadow(color: .black.opacity(0.24), radius: 5 * scale, y: 5 * scale)
        .zIndex(1)
    }
}

/// Familiar dual-screen geometry, with an original store wordmark.
private struct DSStoreLogo: View {
    let scale: CGFloat
    var body: some View {
        HStack(alignment: .center, spacing: 9 * scale) {
            // Tighten only the pair: tracking the whole word also trims the S's trailing edge off its frame.
            Text("\(Text("D").tracking(-4 * scale))S")
                .font(.system(size: 54 * scale, weight: .medium, design: .rounded))
                .padding(.trailing, -4 * scale)
            VStack(spacing: 3 * scale) {
                ForEach(0..<2) { _ in
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .fill(LinearGradient(colors: [Color(white: 0.87), Color(white: 0.96)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            RoundedRectangle(cornerRadius: 2 * scale)
                                .strokeBorder(Color(white: 0.44), lineWidth: 1.7 * scale)
                        }
                }
            }
            .frame(width: 17 * scale, height: 35 * scale)
            Text("STORE")
                .font(.system(size: 33 * scale, weight: .light))
                .tracking(-1.5 * scale)
        }
        .foregroundStyle(Color(white: 0.12))
        .shadow(color: .white.opacity(0.95), radius: 0, y: scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("DS Store")
    }
}

struct DisplayGame: Identifiable {
    let id: String
    let title: String

    var romURL: URL? { Bundle.main.url(forResource: id, withExtension: "nds", subdirectory: "Games") }
    var isBundled: Bool { romURL != nil }

    /// Every game in `ROM/`, each bundled as `Games/<id>.nds`. The id also names its box art.
    static let all = [
        DisplayGame(id: "kart", title: "Mario Kart DS"),
        DisplayGame(id: "mario", title: "New Super Mario Bros."),
        DisplayGame(id: "zelda", title: "Phantom Hourglass"),
        DisplayGame(id: "gta", title: "GTA: Chinatown Wars"),
        DisplayGame(id: "party", title: "Mario Party DS"),
        DisplayGame(id: "gamewatch", title: "Game & Watch Collection"),
        DisplayGame(id: "gamewatch2", title: "Game & Watch Collection 2"),
        DisplayGame(id: "elements", title: "Elements of Destruction"),
        DisplayGame(id: "doodlejump", title: "Doodle Jump Journey"),
        DisplayGame(id: "elfbowling", title: "Elf Bowling 1 & 2"),
        DisplayGame(id: "bakushow", title: "Bakushow"),
        DisplayGame(id: "touchparty", title: "New Touch Party Game"),
        DisplayGame(id: "dora", title: "Dora & Friends: Fantastic Flight"),
        DisplayGame(id: "mathblaster", title: "Math Blaster"),
        DisplayGame(id: "mathplay", title: "Math Play"),
        DisplayGame(id: "matchstick", title: "Matchstick"),
        DisplayGame(id: "sudokumania", title: "Sudoku Mania"),
        DisplayGame(id: "sudokumaster", title: "Sudoku Master"),
        DisplayGame(id: "sudokumaniacs", title: "Sudokumaniacs"),
        DisplayGame(id: "sudokuro", title: "Sudokuro"),
        DisplayGame(id: "kreuzwort", title: "SZ Mehr Kreuzworträtsel"),
        DisplayGame(id: "matchingmaker", title: "Matching Maker DS"),
        DisplayGame(id: "unoukids", title: "New Unou Kids DS"),
        DisplayGame(id: "dekotora", title: "Bakusou Dekotora Densetsu Black")
    ]
}

private enum StoreSpace {
    static let name = "store"
}

/// Where each case sits on the shelf, in the store's space. Only the insertion scene reads it, so only it
/// updates when the shelf lays out, including a store that appears with a game already in the console.
@Observable private final class SlotFrames {
    var frames: [String: CGRect] = [:]
}

struct GameCase: View {
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
            .overlay {
                RoundedRectangle(cornerRadius: 2 * scale)
                    .fill(LinearGradient(stops: [
                        .init(color: .white.opacity(0.16), location: 0),
                        .init(color: .white.opacity(0.025), location: 0.4),
                        .init(color: .clear, location: 0.41),
                        .init(color: .black.opacity(0.035), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.3), radius: 0.8 * scale, x: scale, y: scale)
            .shadow(color: .black.opacity(0.3), radius: 4 * scale, x: 4 * scale, y: 3 * scale)
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
            HStack(alignment: .bottom, spacing: 24 * scale) {
                ForEach(games) { game in
                    Button { onSelect(game) } label: {
                        GameCase(game: game, scale: scale)
                    }
                    .frame(width: 150 * scale)
                    .buttonStyle(.plain)
                    // The lifted case is drawn above the store; leave its spot empty.
                    .opacity(liftedGame == game.id ? 0 : 1)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(StoreSpace.name)) } action: {
                        slotFrames.frames[game.id] = $0
                    }
                    .accessibilityLabel(game.title)
                    .accessibilityHint(game.isBundled ? "Takes the game off the shelf, ready to play" : "Shows game availability")
                }
                if games.count == 1 {
                    Color.clear.frame(width: 150 * scale, height: 1)
                }
            }
            .padding(.horizontal, 18 * scale)
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
        .overlay { Grain(verticalOffset: verticalOffset).opacity(0.055) }
        .overlay {
            LinearGradient(stops: [
                .init(color: .black.opacity(0.16), location: 0),
                .init(color: .clear, location: 0.09),
                .init(color: .clear, location: 0.88),
                .init(color: .black.opacity(0.18), location: 1)
            ], startPoint: .leading, endPoint: .trailing)
        }
        .allowsHitTesting(false)
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
