import SwiftUI

enum Palette {
    static let background = Color(white: 0.17)
    static let engraving = Color(white: 0.64)
    static let ledOn = Color(red: 0.48, green: 0.88, blue: 0.25)
    static let ledOff = Color(red: 0.8, green: 0.81, blue: 0.78)
    static let screenOff = Color(red: 0.13, green: 0.14, blue: 0.13)
}

/// The lettering molded into the shell and printed on the buttons.
enum HardwareFont {
    static func label(size: CGFloat) -> Font { .custom("AvenirNext-Medium", fixedSize: size) }
    /// The thinner, fainter letters printed on the face buttons.
    static func faceLetter(size: CGFloat) -> Font { .custom("AvenirNext-Regular", fixedSize: size) }
}

struct ConsoleView: View {
    let emulator: DSEmulator

    var body: some View {
        // Hold the device upside down relative to its fixed portrait orientation, so
        // the top screen sits on the physical half that is at the bottom in portrait.
        ConsoleBody(emulator: emulator)
            .keyboardControls(for: emulator)
            .attachedToPhysicalDisplay(upsideDown: true)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .preferredColorScheme(.light)
    }
}

/// In hardware coordinates the two equal panels meet at the physical fold.
private struct ConsoleBody: View {
    let emulator: DSEmulator

    var body: some View {
        GeometryReader { proxy in
            let halfHeight = proxy.size.height / 2
            let scale = min(proxy.size.width / 500, halfHeight / 430)
            let bottomInset = max(proxy.safeAreaInsets.bottom, 18 * scale)
            // Reserve the hinge, bezel, controls and safe area BEFORE fitting the LCD.
            let screenWidth = max(1, min(
                proxy.size.width - 156 * scale,
                (halfHeight - bottomInset - 174 * scale) * 4 / 3
            ))

            ZStack {
                VStack(spacing: 0) {
                    TopHalf(emulator: emulator, screenWidth: screenWidth, scale: scale,
                            topInset: proxy.safeAreaInsets.top)
                        .frame(height: halfHeight)
                    BottomHalf(emulator: emulator, screenWidth: screenWidth, scale: scale,
                               bottomInset: bottomInset)
                        .frame(height: halfHeight)
                }
                Hinge(isOn: emulator.status == .running, scale: scale)
                    .frame(height: 42 * scale)
                    .position(x: proxy.size.width / 2, y: halfHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .background(Palette.background)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.light)
    }
}

/// Only the outside corners follow the display; the two hinge edges stay straight.
private struct Shell: View {
    let scale: CGFloat
    let isTop: Bool

    private var contour: ConcentricRectangle {
        ConcentricRectangle(
            uniformTopCorners: isTop ? .concentric : .fixed(3 * scale),
            uniformBottomCorners: isTop ? .fixed(3 * scale) : .concentric
        )
    }

    var body: some View {
        ZStack {
            contour.fill(Color(white: 0.57))
            contour
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.99), location: 0),
                    .init(color: Color(white: 0.90), location: 0.28),
                    .init(color: Color(white: 0.77), location: 0.76),
                    .init(color: Color(white: 0.96), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(0.7 * scale)
            contour
                .fill(LinearGradient(stops: [
                    .init(color: Color(red: 0.98, green: 0.98, blue: 0.965), location: 0),
                    .init(color: Color(red: 0.94, green: 0.945, blue: 0.93), location: 0.48),
                    .init(color: Color(red: 0.89, green: 0.9, blue: 0.89), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    contour.stroke(.white.opacity(0.85), lineWidth: 0.8 * scale)
                }
                .padding(3 * scale)
            // The open halves lie in one plane, so they share one reflection: each half draws its part of it.
            ZStack {
                GeometryReader { proxy in
                    Gloss()
                        .frame(width: proxy.size.width, height: proxy.size.height * 2)
                        .offset(y: isTop ? 0 : -proxy.size.height)
                }
                // The faceplate rolls over into the lip: bright where the curve faces the light, dimmer where it turns away.
                contour
                    .stroke(LinearGradient(colors: [.white, .white.opacity(0.3), .black.opacity(0.08)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 5 * scale)
                    .blur(radius: 1.2 * scale)
            }
            .clipShape(contour)
            .padding(3 * scale)
            // Fine parting line where the polished lip meets the faceplate.
            contour.stroke(Color.black.opacity(0.12), lineWidth: 0.6 * scale)
                .padding(6 * scale)
            contour.stroke(.white.opacity(0.65), lineWidth: 0.7 * scale)
                .padding(7 * scale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A soft window reflection across the polished white plastic: a broad glow in the upper corner
/// and a narrower diagonal band, fading toward the far corner.
struct Gloss: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.6), location: 0),
            .init(color: .white.opacity(0.15), location: 0.16),
            .init(color: .black.opacity(0.035), location: 0.33),
            .init(color: .white.opacity(0.5), location: 0.42),
            .init(color: .white.opacity(0.55), location: 0.45),
            .init(color: .black.opacity(0.02), location: 0.56),
            .init(color: .black.opacity(0.05), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct TopHalf: View {
    let emulator: DSEmulator
    let screenWidth: CGFloat
    let scale: CGFloat
    let topInset: CGFloat

    var body: some View {
        ZStack {
            Shell(scale: scale, isTop: true)
            HStack(spacing: 0) {
                SpeakerColumn(scale: scale, height: Screen<EmptyView>.height(for: screenWidth, scale: scale))
                    .frame(maxWidth: .infinity)
                Screen(width: screenWidth, scale: scale) {
                    if emulator.status == .stopped {
                        OffGlass()
                    } else {
                        ScreenView(renderer: emulator.screenRenderer, screenIndex: 0)
                            .overlay { StatusOverlay(status: emulator.status, scale: scale) }
                    }
                }
                SpeakerColumn(scale: scale, height: Screen<EmptyView>.height(for: screenWidth, scale: scale))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8 * scale)
            .padding(.top, max(topInset, 24 * scale))
            // Clear the hinge barrel, which overlaps the bottom of this half.
            .padding(.bottom, 40 * scale)
        }
    }
}

/// Beside the top screen: a rubber bumper level with each corner of the screen, the speaker between them.
private struct SpeakerColumn: View {
    let scale: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            RubberFoot(scale: scale)
            Spacer()
            SpeakerGrill(scale: scale)
            Spacer()
            RubberFoot(scale: scale)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A small clear bumper the lid closes onto: nearly flush with the shell, it shows mostly as a fine square outline.
private struct RubberFoot: View {
    let scale: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 1.5 * scale, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(white: 0.965), Color(white: 0.99)], startPoint: .top, endPoint: .bottom))
            .overlay { shape.strokeBorder(Color(white: 0.72), lineWidth: 0.7 * scale) }
            // Its lower edge catches the light, its upper one sits in a hairline of shadow.
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.black.opacity(0.08), .white.opacity(0.9)],
                                                  startPoint: .top, endPoint: .bottom),
                                   lineWidth: 1.4 * scale)
                    .padding(0.7 * scale)
            }
            .frame(width: 12 * scale, height: 12 * scale)
    }
}

/// Two rows of three holes punched through the shell, dark inside, their lower rims catching the light.
private struct SpeakerGrill: View {
    let scale: CGFloat
    var body: some View {
        Grid(horizontalSpacing: 13 * scale, verticalSpacing: 13 * scale) {
            ForEach(0..<2, id: \.self) { _ in
                GridRow {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(white: 0.12).shadow(.inner(color: .black, radius: 1.2 * scale, y: 1.2 * scale)))
                            .overlay {
                                Circle().strokeBorder(LinearGradient(colors: [.black.opacity(0.35), .white],
                                                                     startPoint: .top, endPoint: .bottom),
                                                      lineWidth: 0.9 * scale)
                            }
                            .frame(width: 6.5 * scale, height: 6.5 * scale)
                    }
                }
            }
        }
    }
}

/// The barrel the halves fold around. The long middle barrel is the lid's bottom edge; the two knuckles,
/// a little thicker, rise from the base's corners. They butt against each other at straight seams.
private struct Hinge: View {
    let isOn: Bool
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HingeBarrel(outerEnd: .leading, scale: scale)
                .frame(width: 50 * scale)
            HingeBarrel(outerEnd: nil, scale: scale)
                .padding(.vertical, 2.5 * scale)
                .shadow(color: .black.opacity(0.28), radius: 2.5 * scale, y: 3 * scale)
                .overlay { Microphone(scale: scale) }
                .zIndex(-1)
            HingeBarrel(outerEnd: .trailing, scale: scale)
                .frame(width: 50 * scale)
                .overlay(alignment: .leading) {
                    IndicatorLights(isOn: isOn, scale: scale)
                        .padding(.leading, 9 * scale)
                }
        }
        .shadow(color: .black.opacity(0.12), radius: 1.5 * scale, y: 1.5 * scale)
    }
}

/// A glossy white cylinder seen side-on, lit from above (or from the left, when it stands upright).
/// Only a free end is rounded; where it meets another part it's cut square, with a fine shadowed seam.
struct HingeBarrel: View {
    var axis: Axis = .horizontal
    /// The end that is free, rather than butting against another part of the hinge.
    let outerEnd: Edge?
    let scale: CGFloat

    var body: some View {
        let radius = 11 * scale
        let rounds = { (edges: Set<Edge>) in outerEnd.map(edges.contains) == true ? radius : 0 }
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: rounds([.leading, .top]),
            bottomLeadingRadius: rounds([.leading, .bottom]),
            bottomTrailingRadius: rounds([.trailing, .bottom]),
            topTrailingRadius: rounds([.trailing, .top]),
            style: .continuous
        )
        let isHorizontal = axis == .horizontal
        shape
            .fill(LinearGradient(stops: [
                .init(color: Color(white: 0.78), location: 0),
                .init(color: Color(white: 0.93), location: 0.12),
                .init(color: Color(white: 1), location: 0.3),
                .init(color: Color(white: 0.96), location: 0.45),
                .init(color: Color(white: 0.9), location: 0.66),
                .init(color: Color(white: 0.8), location: 0.86),
                .init(color: Color(white: 0.68), location: 1)
            ], startPoint: isHorizontal ? .top : .leading, endPoint: isHorizontal ? .bottom : .trailing))
            .overlay {
                // The sharp reflection of the light running along the barrel.
                GeometryReader { proxy in
                    let thickness = isHorizontal ? proxy.size.height : proxy.size.width
                    Rectangle()
                        .fill(.white)
                        .frame(width: isHorizontal ? nil : 1.8 * scale, height: isHorizontal ? 1.8 * scale : nil)
                        .blur(radius: 0.6 * scale)
                        .offset(x: isHorizontal ? 0 : thickness * 0.24, y: isHorizontal ? thickness * 0.24 : 0)
                }
            }
            .overlay {
                // A free end rolls out of the light; a cut end shows as a crisp seam.
                let layout = isHorizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    end(atFarEnd: false)
                    Spacer(minLength: 0)
                    end(atFarEnd: true)
                }
            }
            .clipShape(shape)
            .overlay { shape.stroke(.black.opacity(0.14), lineWidth: 0.6) }
    }

    @ViewBuilder private func end(atFarEnd: Bool) -> some View {
        let isHorizontal = axis == .horizontal
        let edge: Edge = isHorizontal ? (atFarEnd ? .trailing : .leading) : (atFarEnd ? .bottom : .top)
        let outside: UnitPoint = isHorizontal ? (atFarEnd ? .trailing : .leading) : (atFarEnd ? .bottom : .top)
        let inside: UnitPoint = isHorizontal ? (atFarEnd ? .leading : .trailing) : (atFarEnd ? .top : .bottom)
        if outerEnd == edge {
            LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: outside, endPoint: inside)
                .frame(width: isHorizontal ? 10 * scale : nil, height: isHorizontal ? nil : 10 * scale)
        } else {
            let layout = isHorizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            layout {
                if atFarEnd { seamLine(.white.opacity(0.8), 0.6) }
                seamLine(.black.opacity(0.22), 0.8)
                if !atFarEnd { seamLine(.white.opacity(0.8), 0.6) }
            }
        }
    }

    private func seamLine(_ color: Color, _ thickness: CGFloat) -> some View {
        Rectangle().fill(color)
            .frame(width: axis == .horizontal ? thickness * scale : nil,
                   height: axis == .horizontal ? nil : thickness * scale)
    }
}

/// The microphone slit sits dead center, its label molded beside it.
private struct Microphone: View {
    let scale: CGFloat

    var body: some View {
        Capsule()
            .fill(Color(white: 0.1).shadow(.inner(color: .black, radius: 0.8 * scale, y: 0.8 * scale)))
            .overlay {
                Capsule().strokeBorder(LinearGradient(colors: [.clear, .white.opacity(0.9)], startPoint: .top, endPoint: .bottom),
                                       lineWidth: 0.6 * scale)
            }
            .frame(width: 3.6 * scale, height: 15 * scale)
            .overlay(alignment: .leading) {
                Text("MIC.")
                    .font(HardwareFont.label(size: 9.5 * scale))
                    .kerning(0.4 * scale)
                    .engraved()
                    .fixedSize()
                    .offset(x: 9 * scale)
            }
            .accessibilityHidden(true)
    }
}

/// A knuckle's ribbing: fine grooves ringing the barrel, with the power and charge lamps as
/// translucent bands among them. `axis` is the barrel's.
struct IndicatorLights: View {
    var axis: Axis = .horizontal
    let isOn: Bool
    let scale: CGFloat

    private var isHorizontal: Bool { axis == .horizontal }

    var body: some View {
        let layout = isHorizontal ? AnyLayout(HStackLayout(spacing: 3 * scale)) : AnyLayout(VStackLayout(spacing: 3 * scale))
        layout {
            groove
            groove
            lamp(color: isOn ? Palette.ledOn : nil)
            lamp(color: nil)
        }
        .padding(isHorizontal ? .vertical : .horizontal, 2 * scale)
        // The rings wrap around the cylinder, so they fade out as it curves away from view.
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.3),
                .init(color: .black, location: 0.72),
                .init(color: .clear, location: 1)
            ], startPoint: isHorizontal ? .top : .leading, endPoint: isHorizontal ? .bottom : .trailing)
        }
        .accessibilityHidden(true)
    }

    /// A cut into the barrel: one wall in shadow, the far edge catching the light.
    private var groove: some View {
        let layout = isHorizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        return layout {
            band(.black.opacity(0.3), 0.8)
            band(.white, 0.7)
        }
    }

    private func band(_ style: some ShapeStyle, _ thickness: CGFloat) -> some View {
        Rectangle().fill(style)
            .frame(width: isHorizontal ? thickness * scale : nil, height: isHorizontal ? nil : thickness * scale)
    }

    private func lamp(color: Color?) -> some View {
        let tint = color ?? Palette.ledOff
        return band(LinearGradient(colors: [tint.opacity(0.75), tint, tint.opacity(0.8)],
                                   startPoint: isHorizontal ? .top : .leading,
                                   endPoint: isHorizontal ? .bottom : .trailing), 2.4)
            .shadow(color: color?.opacity(0.9) ?? .clear, radius: 2.5 * scale)
    }
}

private struct BottomHalf: View {
    let emulator: DSEmulator
    let screenWidth: CGFloat
    let scale: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        let screenHeight = Screen<EmptyView>.height(for: screenWidth, scale: scale)
        let faceSize = 114 * scale
        let padSize = 100 * scale
        // The D-pad and face buttons sit level with each other, a little above the screen's middle.
        let controlsCenter = screenHeight * 0.38

        ZStack(alignment: .top) {
            Shell(scale: scale, isTop: false)
            HStack(alignment: .top, spacing: 0) {
                DPad(emulator: emulator, size: padSize)
                    .padding(.top, controlsCenter - padSize / 2)
                    .frame(maxWidth: .infinity)
                Screen(width: screenWidth, scale: scale) {
                    // Without a game inserted, the console stays off.
                    if emulator.status == .stopped {
                        OffGlass()
                    } else {
                        ScreenView(renderer: emulator.screenRenderer, screenIndex: 1)
                            .overlay { TouchSurface(emulator: emulator) }
                    }
                }
                FaceButtons(emulator: emulator, size: faceSize)
                    .padding(.top, controlsCenter - faceSize / 2)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8 * scale)
            .padding(.top, 50 * scale)

            HStack {
                ShoulderButton(button: .l, emulator: emulator, scale: scale)
                Spacer()
                ShoulderButton(button: .r, emulator: emulator, scale: scale)
            }
            .padding(.horizontal, 18 * scale)
            .padding(.top, 30 * scale)

            // START and SELECT sit down in the corner, below the face buttons' column.
            HStack(spacing: 0) {
                Color.clear.frame(maxWidth: .infinity)
                Color.clear.frame(width: screenWidth + 20 * scale)
                SystemButtons(emulator: emulator, scale: scale)
                    .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8 * scale)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 26 * scale)
        }
    }
}

private struct OffGlass: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Color(red: 0.17, green: 0.19, blue: 0.17), location: 0),
            .init(color: Palette.screenOff, location: 0.45),
            .init(color: Color(red: 0.105, green: 0.12, blue: 0.11), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay {
            Rectangle().fill(LinearGradient(colors: [.white.opacity(0.045), .clear],
                                            startPoint: .top, endPoint: .center))
        }
        .overlay { Rectangle().strokeBorder(.black.opacity(0.35), lineWidth: 1) }
    }
}

private struct Screen<Content: View>: View {
    let width: CGFloat
    let scale: CGFloat
    @ViewBuilder let content: Content

    /// The height of the whole bezel around an LCD `width` wide.
    static func height(for width: CGFloat, scale: CGFloat) -> CGFloat { width * 3 / 4 + 20 * scale }

    var body: some View {
        content
            .frame(width: width, height: width * 3 / 4)
            .clipped()
            .padding(3 * scale)
            .background(Color(red: 0.20, green: 0.21, blue: 0.19))
            .overlay { Rectangle().stroke(.black.opacity(0.5), lineWidth: scale).allowsHitTesting(false) }
            .padding(7 * scale)
            .background {
                RoundedRectangle(cornerRadius: 3 * scale)
                    .fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.87), Color(white: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.25), radius: 1 * scale, x: -0.7 * scale, y: -0.8 * scale)
                    .shadow(color: .white, radius: 0.5 * scale, x: 1 * scale, y: 1.5 * scale)
            }
    }
}

private struct StatusOverlay: View {
    let status: DSEmulator.Status
    let scale: CGFloat
    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 13 * scale, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(16 * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
        }
    }
    private var message: String? {
        switch status {
        case .missingROM: "This game’s ROM isn’t bundled.\nPut it in ROM/<id>.zip\nand rebuild."
        case .failed(let reason): reason
        case .stopped, .running, .paused: nil
        }
    }
}

private struct TouchSurface: View {
    let emulator: DSEmulator
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            emulator.touch(at: CGPoint(
                                x: min(1, max(0, value.location.x / proxy.size.width)),
                                y: min(1, max(0, value.location.y / proxy.size.height))
                            ))
                        }
                        .onEnded { _ in emulator.releaseTouch() }
                )
                .onDisappear { emulator.releaseTouch() }
        }
    }
}
