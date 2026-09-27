import SwiftUI

/// A miniature retail display. Choosing a game takes its case off the shelf and puts its card in a console, ready to play.
struct GameSelectionView: View {
    /// The lifted game, owned by the caller so it stays lifted while the device is open.
    @Binding var selection: String?
    @State private var unavailableGame: DisplayGame?
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
                                  isUnderShelf: row > 0, liftedGame: selection, slotFrames: slotFrames) { game in
                            if game.isBundled {
                                liftsIn = true
                                selection = game.id
                            } else {
                                unavailableGame = game
                            }
                        }
                    }
                    // The last shelf shades the board below it too, which shows in the overscroll.
                    Color.clear
                        .frame(height: 20 * s)
                        .overlay(alignment: .top) {
                            LinearGradient(stops: [
                                .init(color: .black.opacity(0.5), location: 0),
                                .init(color: .black.opacity(0.22), location: 0.3),
                                .init(color: .clear, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                                .frame(height: 70 * s)
                        }
                        .allowsHitTesting(false)
                }
                .padding(.top, 10 * s)
                // The board scrolls with the shelves, and runs on past both ends for the rubber-band overscroll.
                .background { Pegboard().padding(.vertical, -800 * s) }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            .overlay {
                ZStack(alignment: .top) {
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.2), location: 0),
                        .init(color: .clear, location: 0.09),
                        .init(color: .clear, location: 0.88),
                        .init(color: .black.opacity(0.22), location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                    // The lit sign spills onto whatever passes under it.
                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 50 * s)
                }
                .allowsHitTesting(false)
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

/// Glossy red ABS lit from above: a dark seam, a soft reflection along the top of its rounded edge with a
/// crisp highlight on it, and a shadowed lip where it meets the display.
private struct CabinetFrame: View {
    let scale: CGFloat
    private var contour: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(43 * scale)), isUniform: true)
    }

    var body: some View {
        ZStack {
            contour.fill(Color(red: 0.3, green: 0.02, blue: 0.015))
            contour.fill(LinearGradient(stops: [
                .init(color: Color(red: 0.93, green: 0.1, blue: 0.07), location: 0),
                .init(color: Color(red: 0.8, green: 0.04, blue: 0.025), location: 0.45),
                .init(color: Color(red: 0.6, green: 0.02, blue: 0.015), location: 1)
            ], startPoint: .top, endPoint: .bottom))
                .padding(scale)
            contour.stroke(LinearGradient(stops: [
                .init(color: .white.opacity(0.5), location: 0),
                .init(color: .white.opacity(0.12), location: 0.1),
                .init(color: .white.opacity(0), location: 0.3)
            ], startPoint: .top, endPoint: .bottom), lineWidth: 4 * scale)
                .blur(radius: 1.5 * scale)
                .padding(3.5 * scale)
            contour.stroke(LinearGradient(stops: [
                .init(color: .white.opacity(0.9), location: 0),
                .init(color: .white.opacity(0.2), location: 0.08),
                .init(color: .white.opacity(0), location: 0.4),
                .init(color: .black.opacity(0.25), location: 1)
            ], startPoint: .top, endPoint: .bottom), lineWidth: 0.8 * scale)
                .padding(1.6 * scale)
            contour.stroke(.white.opacity(0.2), lineWidth: 0.6 * scale)
                .padding(8 * scale)
            contour.stroke(.black.opacity(0.35), lineWidth: 1.6 * scale)
                .blur(radius: 0.8 * scale)
                .padding(9.8 * scale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct StoreHeader: View {
    let scale: CGFloat
    var body: some View {
        ZStack {
            // A backlit diffuser: brightest in the middle, where the tube behind it is.
            LinearGradient(stops: [
                .init(color: Color(white: 0.97), location: 0),
                .init(color: Color(red: 0.97, green: 0.97, blue: 0.95), location: 0.6),
                .init(color: Color(white: 0.88), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            EllipticalGradient(colors: [.white, .white.opacity(0)], center: .init(x: 0.5, y: 0.45),
                               startRadiusFraction: 0, endRadiusFraction: 0.6)
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
        .shadow(color: .black.opacity(0.2), radius: 2.5 * scale, y: 2.5 * scale)
        .zIndex(1)
    }
}

/// The Nintendo DS wordmark's own shapes, respelled: the top screen doubles as the O of STORE.
private struct DSStoreLogo: View {
    let scale: CGFloat
    var body: some View {
        Image("DSStoreLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 44 * scale)
            .shadow(color: .white.opacity(0.95), radius: 0, y: scale)
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

/// A clear plastic keep case with the cover sheet under it: a rounded, lit edge, the hinge ridge down the
/// spine, and the room's light reflected in the plastic.
struct GameCase: View {
    let game: DisplayGame
    let scale: CGFloat
    var body: some View {
        Image(game.id)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay { Rectangle().strokeBorder(.black.opacity(0.14), lineWidth: 0.5 * scale) }
            .padding(2 * scale)
            .background(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.86)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .leading) {
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.25), location: 0), .init(color: .white.opacity(0.5), location: 0.3),
                    .init(color: .black.opacity(0.08), location: 0.75), .init(color: .clear, location: 1)
                ], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 6 * scale)
            }
            .overlay { CaseGlare() }
            .clipShape(RoundedRectangle(cornerRadius: 3 * scale))
            .overlay {
                RoundedRectangle(cornerRadius: 3 * scale)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.2), .black.opacity(0.28)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.8 * scale)
            }
            // Lit from above and in front: the case throws its shadow down the board behind it.
            .shadow(color: .black.opacity(0.45), radius: scale, y: scale)
            .shadow(color: .black.opacity(0.4), radius: 5 * scale, y: 2.5 * scale)
            .shadow(color: .black.opacity(0.25), radius: 14 * scale, y: 12 * scale)
    }
}

/// The case's thickness, seen from a little above the shelves and from the middle of the display:
/// its lit top edge, and the shaded side facing the middle.
private struct CaseDepth: View {
    let scale: CGFloat
    let recedesRight: Bool

    var body: some View {
        let depth = 6 * scale
        let shift = (recedesRight ? 3 : -3) * scale
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            let sideX = recedesRight ? w : 0
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: sideX, y: 0))
                    path.addLine(to: CGPoint(x: sideX + shift, y: -depth))
                    path.addLine(to: CGPoint(x: sideX + shift, y: h - depth))
                    path.addLine(to: CGPoint(x: sideX, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(white: 0.72), Color(white: 0.5)], startPoint: .top, endPoint: .bottom))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w + shift, y: -depth))
                    path.addLine(to: CGPoint(x: shift, y: -depth))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.97)], startPoint: .top, endPoint: .bottom))
                // The hinge ridge runs over the top at the spine.
                Path { path in
                    path.move(to: CGPoint(x: 1.5 * scale, y: 0))
                    path.addLine(to: CGPoint(x: 1.5 * scale + shift, y: -depth))
                }
                .stroke(.black.opacity(0.18), lineWidth: 1.5 * scale)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The reflection of a window in the plastic. The window is fixed in the room, so the reflection slides
/// across a case as the case moves; only an offset changes, so it costs nothing to scroll.
private struct CaseGlare: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(0), location: 0.38),
            .init(color: .white.opacity(0.16), location: 0.45),
            .init(color: .white.opacity(0.12), location: 0.5),
            .init(color: .white.opacity(0), location: 0.56),
            .init(color: .white.opacity(0), location: 0.585),
            .init(color: .white.opacity(0.22), location: 0.59),
            .init(color: .white.opacity(0), location: 0.597)
        ], startPoint: .init(x: 0.3, y: 0), endPoint: .init(x: 0.7, y: 1))
            .scaleEffect(y: 4)
            .visualEffect { content, proxy in
                content.offset(y: (380 - proxy.frame(in: .global).minY) * 0.6)
            }
            .allowsHitTesting(false)
    }
}

private struct GameShelf: View {
    let games: [DisplayGame]
    let scale: CGFloat
    /// Every row but the first has a shelf above it, shading the top of its board.
    let isUnderShelf: Bool
    let liftedGame: String?
    let slotFrames: SlotFrames
    let onSelect: (DisplayGame) -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 24 * scale) {
                ForEach(games.indices, id: \.self) { index in
                    let game = games[index]
                    Button { onSelect(game) } label: {
                        GameCase(game: game, scale: scale)
                            .background { CaseDepth(scale: scale, recedesRight: index == 0) }
                    }
                    .frame(width: 150 * scale)
                    .buttonStyle(.plain)
                    // Where it stands, the case keeps the light off the shelf just in front of it.
                    .background(alignment: .bottom) {
                        EllipticalGradient(colors: [.black.opacity(0.5), .black.opacity(0)])
                            .frame(height: 10 * scale)
                            .padding(.horizontal, -6 * scale)
                            .offset(y: 4 * scale)
                    }
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
            // The gap under the shelf above is part of this bay, so its lighting starts right under that shelf.
            .frame(maxWidth: .infinity)
            .frame(height: 166 * scale, alignment: .bottom)
            // Light from above: the shelf overhead shades the board, which brightens further down
            // and darkens again into the corner behind the shelf.
            .background {
                LinearGradient(stops: [
                    .init(color: .black.opacity(isUnderShelf ? 0.5 : 0), location: 0),
                    .init(color: .black.opacity(isUnderShelf ? 0.22 : 0.01), location: 0.12),
                    .init(color: .black.opacity(0.03), location: 0.4),
                    .init(color: .black.opacity(0.08), location: 0.7),
                    .init(color: .black.opacity(0.3), location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            // The cases stand on the shelf, a little way back from its front edge.
            .padding(.bottom, -6 * scale)
            .zIndex(2)
            VStack(spacing: 0) {
                // The top, seen from above: in the cases' shade at the back, catching the light at the front.
                Rectangle()
                    .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.78), Color(white: 0.96)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 12 * scale)
                Rectangle().fill(.white).frame(height: scale)
                Rectangle()
                    .fill(LinearGradient(stops: [
                        .init(color: Color(white: 0.9), location: 0), .init(color: Color(white: 0.82), location: 0.25),
                        .init(color: Color(white: 0.74), location: 0.8), .init(color: Color(white: 0.45), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay { Rectangle().fill(ShaderLibrary.brushedMetal(.float(scale))) }
                    .frame(height: 17 * scale)
            }
            .shadow(color: .black.opacity(0.4), radius: 1.5 * scale, y: 2 * scale)
            .shadow(color: .black.opacity(0.35), radius: 8 * scale, y: 12 * scale)
            .zIndex(1)
        }
    }
}

/// Painted hardboard, shaded per pixel by a fill shader, so scrolling it costs nothing. It's drawn in tiles,
/// since a shader fill much taller than the screen doesn't draw at all.
private struct Pegboard: View {
    private let tileHeight: CGFloat = 1000
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(0..<Int((geometry.size.height / tileHeight).rounded(.up)), id: \.self) { tile in
                    Rectangle()
                        .fill(ShaderLibrary.pegboard(.float(geometry.size.width), .float(CGFloat(tile) * tileHeight)))
                        .frame(height: tileHeight)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct Grain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<9000 {
                let x = CGFloat((index * 67 + 13) % 997) / 997 * size.width
                let y = CGFloat((index * 137 + 29) % 991) / 991 * size.height
                context.fill(Path(CGRect(x: x, y: y, width: 0.6, height: 0.6)), with: .color(index.isMultiple(of: 2) ? .white : .black))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview { GameSelectionView(selection: .constant(nil)) }
