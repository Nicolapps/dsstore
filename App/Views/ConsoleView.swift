import SwiftUI

enum Palette {
    static let background = Color(white: 0.17)
    static let shellLight = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let shellDark = Color(red: 0.82, green: 0.83, blue: 0.83)
    static let engraving = Color(red: 0.57, green: 0.58, blue: 0.56)
    static let button = Color(white: 0.96)
    static let buttonPressed = Color(white: 0.84)
    static let buttonLabel = Color(red: 0.61, green: 0.62, blue: 0.58)
    static let ledOn = Color(red: 0.48, green: 0.88, blue: 0.25)
    static let ledOff = Color(white: 0.42)
    static let screenOff = Color(red: 0.13, green: 0.14, blue: 0.13)
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
                    .frame(height: 24 * scale)
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
            VStack(spacing: 0) {
                HStack {
                    RubberFoot(scale: scale)
                    Spacer()
                    RubberFoot(scale: scale)
                }
                Spacer(minLength: 10 * scale)
                HStack(spacing: 0) {
                    SpeakerGrill(scale: scale).frame(maxWidth: .infinity)
                    Screen(width: screenWidth, scale: scale) {
                        if emulator.status == .stopped {
                            OffGlass()
                        } else {
                            ScreenView(renderer: emulator.screenRenderer, screenIndex: 0)
                                .overlay { StatusOverlay(status: emulator.status, scale: scale) }
                        }
                    }
                    SpeakerGrill(scale: scale).frame(maxWidth: .infinity)
                }
                Spacer(minLength: 10 * scale)
                HStack {
                    RubberFoot(scale: scale)
                    Spacer()
                    Capsule().fill(Color(white: 0.3)).frame(width: 3 * scale, height: 7 * scale)
                        .shadow(color: .white, radius: 0, x: 1, y: 1)
                    Spacer()
                    RubberFoot(scale: scale)
                }
            }
            .padding(.horizontal, 25 * scale)
            .padding(.top, max(topInset, 24 * scale))
            .padding(.bottom, 29 * scale)
        }
    }
}

private struct RubberFoot: View {
    let scale: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: 3 * scale)
            .fill(Color(white: 0.94))
            .frame(width: 15 * scale, height: 9 * scale)
            .overlay { RoundedRectangle(cornerRadius: 3 * scale).stroke(.black.opacity(0.06), lineWidth: 0.7) }
            .shadow(color: .white, radius: 0.5, y: 1)
    }
}

private struct SpeakerGrill: View {
    let scale: CGFloat
    var body: some View {
        Grid(horizontalSpacing: 6 * scale, verticalSpacing: 7 * scale) {
            ForEach(0..<2, id: \.self) { _ in
                GridRow {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(white: 0.23))
                            .frame(width: 3 * scale, height: 3 * scale)
                            .overlay { Circle().stroke(.black.opacity(0.5), lineWidth: 0.5) }
                            .shadow(color: .white, radius: 0, x: 0.6, y: 1)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Hinge: View {
    let isOn: Bool
    let scale: CGFloat
    var body: some View {
        ZStack {
            Rectangle().fill(Color(white: 0.38)).frame(height: 7 * scale)
            HStack(spacing: 2 * scale) {
                barrel.frame(width: 31 * scale)
                barrel.overlay {
                    HStack {
                        Text("MIC.").font(.system(size: 6 * scale, weight: .medium))
                            .foregroundStyle(Palette.engraving)
                        Capsule().fill(Color(white: 0.32)).frame(width: 8 * scale, height: 2 * scale)
                        Spacer()
                        RoundedRectangle(cornerRadius: scale)
                            .fill(isOn ? Palette.ledOn : Palette.ledOff)
                            .frame(width: 4 * scale, height: 9 * scale)
                            .shadow(color: isOn ? Palette.ledOn.opacity(0.5) : .clear, radius: 3 * scale)
                        RoundedRectangle(cornerRadius: scale)
                            .fill(Color(red: 0.61, green: 0.64, blue: 0.52))
                            .frame(width: 4 * scale, height: 9 * scale)
                    }.padding(.horizontal, 18 * scale)
                }
                barrel.frame(width: 31 * scale)
            }
            .padding(.horizontal, 13 * scale)
        }
    }

    private var barrel: some View {
        RoundedRectangle(cornerRadius: 7 * scale)
            .fill(LinearGradient(stops: [
                .init(color: Color(white: 0.67), location: 0),
                .init(color: Color(white: 0.93), location: 0.18),
                .init(color: .white, location: 0.35),
                .init(color: Color(white: 0.9), location: 0.6),
                .init(color: Color(white: 0.65), location: 0.92),
                .init(color: Color(white: 0.81), location: 1)
            ], startPoint: .top, endPoint: .bottom))
            .overlay { RoundedRectangle(cornerRadius: 7 * scale).stroke(.black.opacity(0.15), lineWidth: 0.6) }
            .shadow(color: .black.opacity(0.25), radius: 2 * scale, y: 3 * scale)
    }
}

private struct BottomHalf: View {
    let emulator: DSEmulator
    let screenWidth: CGFloat
    let scale: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        ZStack {
            Shell(scale: scale, isTop: false)
            VStack(spacing: 12 * scale) {
                // The D-pad and face buttons flank the touch screen, each centered in its side gutter.
                HStack(spacing: 0) {
                    DPad(emulator: emulator, size: 104 * scale)
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
                    FaceButtons(emulator: emulator, size: 114 * scale)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8 * scale)
                VStack(spacing: 12 * scale) {
                    Text("Nintendo")
                        .font(.system(size: 10 * scale, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 7 * scale).padding(.vertical, 1 * scale)
                        .overlay { Capsule().stroke(Palette.engraving.opacity(0.6), lineWidth: 1) }
                        .accessibilityHidden(true)
                    HStack(spacing: 8 * scale) {
                        PillButton(button: .select, title: "SELECT", emulator: emulator, scale: scale)
                        PillButton(button: .start, title: "START", emulator: emulator, scale: scale)
                    }
                }
                .foregroundStyle(Palette.engraving)
            }
            .padding(.top, 28 * scale)
            .padding(.bottom, bottomInset)
            .frame(maxHeight: .infinity, alignment: .top)

            HStack {
                ShoulderButton(button: .l, emulator: emulator, scale: scale)
                Spacer()
                ShoulderButton(button: .r, emulator: emulator, scale: scale)
            }
            .padding(.horizontal, 19 * scale)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 23 * scale)
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
