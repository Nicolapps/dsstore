import SwiftUI

/// A miniature retail display with a route into the bundled game.
struct GameSelectionView: View {
    var onPlay: () -> Void = {}
    @State private var unavailableGame: DisplayGame?
    @State private var shelfOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 414
            cabinet(scale: scale)
                // Keep the frame below the Duo camera, including configurations that report no top inset.
                .padding(.top, max(16, 80 - geometry.safeAreaInsets.top))
                .frame(width: geometry.size.width, height: geometry.size.height)
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
                    ForEach(0..<((DisplayGame.all.count + 1) / 2)) { row in
                        GameShelf(games: Array(DisplayGame.all.dropFirst(row * 2).prefix(2)), scale: s) { game in
                            if game.id == "kart" { onPlay() }
                            else { unavailableGame = game }
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

private struct GameShelf: View {
    let games: [DisplayGame]
    let scale: CGFloat
    let onSelect: (DisplayGame) -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 30 * scale) {
                ForEach(games) { game in
                    Button { onSelect(game) } label: {
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
                    .frame(width: 150 * scale)
                    .buttonStyle(.plain)
                    .accessibilityLabel(game.title)
                    .accessibilityHint(game.id == "kart" ? "Play the bundled game" : "Show game availability")
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

#Preview { GameSelectionView() }
