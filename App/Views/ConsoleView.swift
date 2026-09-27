import SwiftUI

enum Palette {
    static let background = Color(white: 0.17)
    static let shellLight = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let shellDark = Color(red: 0.82, green: 0.83, blue: 0.83)
    static let engraving = Color(white: 0.64)
    static let ledOn = Color(red: 0.48, green: 0.88, blue: 0.25)
    static let ledOff = Color(red: 0.66, green: 0.68, blue: 0.64)
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
                    .init(color: Color(red: 0.86, green: 0.875, blue: 0.86), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    contour.stroke(.white.opacity(0.85), lineWidth: 0.8 * scale)
                }
                .padding(3 * scale)
            // Fine parting line where the polished lip meets the satin faceplate.
            contour.stroke(Color.black.opacity(0.12), lineWidth: 0.6 * scale)
                .padding(6 * scale)
            contour.stroke(.white.opacity(0.65), lineWidth: 0.7 * scale)
                .padding(7 * scale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

/// A soft gray pad the lid closes onto, standing just proud of the shell.
private struct RubberFoot: View {
    let scale: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 2.5 * scale, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(white: 0.91), Color(white: 0.84)], startPoint: .top, endPoint: .bottom))
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white, .black.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                                   lineWidth: 0.8 * scale)
            }
            .frame(width: 13 * scale, height: 11 * scale)
            .shadow(color: .black.opacity(0.18), radius: 0.8 * scale, y: 0.8 * scale)
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

/// The barrel the halves fold around: two knuckles on the lid, the long center barrel on the base.
private struct Hinge: View {
    let isOn: Bool
    let scale: CGFloat

    var body: some View {
        ZStack {
            // The gap between the halves, in the barrel's shadow.
            LinearGradient(colors: [Color(white: 0.3), Color(white: 0.12), Color(white: 0.3)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 24 * scale)
            HStack(spacing: 1.4 * scale) {
                HingeBarrel(scale: scale)
                    .frame(width: 62 * scale)
                HingeBarrel(scale: scale)
                    .overlay { Microphone(scale: scale) }
                HingeBarrel(scale: scale)
                    .frame(width: 62 * scale)
                    .overlay { IndicatorLights(isOn: isOn, scale: scale) }
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 3 * scale, y: 4 * scale)
    }
}

/// A glossy white cylinder seen side-on, lit from above, its rounded ends rolling out of the light.
private struct HingeBarrel: View {
    let scale: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
        shape
            .fill(LinearGradient(stops: [
                .init(color: Color(white: 0.6), location: 0),
                .init(color: Color(white: 0.86), location: 0.1),
                .init(color: Color(white: 0.99), location: 0.26),
                .init(color: Color(white: 0.96), location: 0.4),
                .init(color: Color(white: 0.9), location: 0.62),
                .init(color: Color(white: 0.76), location: 0.84),
                .init(color: Color(white: 0.62), location: 1)
            ], startPoint: .top, endPoint: .bottom))
            .overlay {
                // The sharp reflection of the light running along the top of the barrel.
                Capsule()
                    .fill(.white)
                    .frame(height: 2 * scale)
                    .blur(radius: 0.6 * scale)
                    .padding(.horizontal, 7 * scale)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8.5 * scale)
            }
            .overlay {
                HStack {
                    LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 9 * scale)
                    Spacer()
                    LinearGradient(colors: [.clear, .black.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 9 * scale)
                }
            }
            .clipShape(shape)
            .overlay { shape.stroke(.black.opacity(0.2), lineWidth: 0.6) }
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

/// The power and charge lamps, set into the right knuckle.
private struct IndicatorLights: View {
    let isOn: Bool
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 3 * scale) {
            lamp(color: isOn ? Palette.ledOn : nil)
            lamp(color: nil)
        }
        .accessibilityHidden(true)
    }

    private func lamp(color: Color?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 1.2 * scale, style: .continuous)
        return shape
            .fill((color ?? Palette.ledOff).shadow(.inner(color: .black.opacity(0.25), radius: 0.8 * scale, y: 0.6 * scale)))
            .overlay {
                shape.fill(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center))
            }
            .overlay { shape.strokeBorder(.black.opacity(0.25), lineWidth: 0.5) }
            .frame(width: 2.6 * scale, height: 9 * scale)
            .shadow(color: color?.opacity(0.8) ?? .clear, radius: 3 * scale)
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
