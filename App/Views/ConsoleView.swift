import SwiftUI

enum Palette {
    static let background = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let shellLight = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let shellDark = Color(red: 0.89, green: 0.89, blue: 0.87)
    static let hinge = Color(red: 0.80, green: 0.80, blue: 0.78)
    static let bezel = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let engraving = Color(red: 0.58, green: 0.58, blue: 0.56)
    static let button = Color(red: 0.93, green: 0.93, blue: 0.92)
    static let buttonPressed = Color(red: 0.84, green: 0.84, blue: 0.83)
    static let buttonLabel = Color(red: 0.62, green: 0.62, blue: 0.60)
    static let dpad = Color(red: 0.90, green: 0.90, blue: 0.89)
    static let shoulder = Color(red: 0.86, green: 0.86, blue: 0.84)
    static let shoulderPressed = Color(red: 0.78, green: 0.78, blue: 0.76)
    static let ledOn = Color(red: 0.35, green: 0.95, blue: 0.45)
    static let ledOff = Color(red: 0.70, green: 0.70, blue: 0.68)
}

/// A Nintendo DS drawn in SwiftUI, sized to fit the window.
struct ConsoleView: View {
    let emulator: DSEmulator

    /// The console is designed at this size and scaled uniformly to fit.
    private static let designSize = CGSize(width: 380, height: 690)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / Self.designSize.width,
                proxy.size.height / Self.designSize.height
            )

            VStack(spacing: 0) {
                TopHalf(emulator: emulator, scale: scale)
                Hinge(emulator: emulator, scale: scale)
                BottomHalf(emulator: emulator, scale: scale)
            }
            .frame(width: Self.designSize.width * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
        .background(Palette.background)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

private let screenSize = CGSize(width: 272, height: 204) // 256×192 scaled by 1.0625

private struct Shell<Content: View>: View {
    let scale: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 26 * scale, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.shellLight, Palette.shellDark], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 12 * scale, y: 6 * scale)
            }
    }
}

// MARK: - Top half

private struct TopHalf: View {
    let emulator: DSEmulator
    let scale: CGFloat

    var body: some View {
        Shell(scale: scale) {
            HStack(spacing: 0) {
                SpeakerGrill(scale: scale).frame(maxWidth: .infinity)
                Screen(scale: scale) {
                    ScreenView(gameView: emulator.topScreen)
                        .overlay { StatusOverlay(status: emulator.status, scale: scale) }
                }
                SpeakerGrill(scale: scale).frame(maxWidth: .infinity)
            }
            .padding(.vertical, 22 * scale)
        }
    }
}

private struct SpeakerGrill: View {
    let scale: CGFloat

    var body: some View {
        Grid(horizontalSpacing: 5 * scale, verticalSpacing: 5 * scale) {
            ForEach(0..<5, id: \.self) { _ in
                GridRow {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Palette.engraving.opacity(0.6))
                            .frame(width: 3.5 * scale, height: 3.5 * scale)
                    }
                }
            }
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
        case .missingROM: "No game found.\nPut a ROM at ROM/game.nds and rebuild."
        case .failed(let reason): reason
        case .stopped, .running, .paused: nil
        }
    }
}

// MARK: - Hinge

private struct Hinge: View {
    let emulator: DSEmulator
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ShoulderButton(button: .l, emulator: emulator, scale: scale)
            Spacer()
            Capsule()
                .fill(LinearGradient(colors: [Palette.shellDark, Palette.hinge, Palette.shellDark], startPoint: .top, endPoint: .bottom))
                .frame(width: 160 * scale, height: 18 * scale)
                .overlay(alignment: .trailing) { PowerLED(isOn: emulator.status == .running, scale: scale).padding(.trailing, 14 * scale) }
            Spacer()
            ShoulderButton(button: .r, emulator: emulator, scale: scale)
        }
        .padding(.horizontal, 10 * scale)
        .padding(.vertical, 2 * scale)
    }
}

private struct PowerLED: View {
    let isOn: Bool
    let scale: CGFloat

    var body: some View {
        Circle()
            .fill(isOn ? Palette.ledOn : Palette.ledOff)
            .shadow(color: isOn ? Palette.ledOn : .clear, radius: 3 * scale)
            .frame(width: 5 * scale, height: 5 * scale)
            .animation(.easeOut(duration: 0.2), value: isOn)
    }
}

// MARK: - Bottom half

private struct BottomHalf: View {
    let emulator: DSEmulator
    let scale: CGFloat

    var body: some View {
        Shell(scale: scale) {
            VStack(spacing: 18 * scale) {
                Screen(scale: scale) {
                    ScreenView(gameView: emulator.bottomScreen)
                        .overlay { TouchSurface(emulator: emulator) }
                }

                HStack(alignment: .top) {
                    DPad(emulator: emulator, size: 108 * scale)
                        .padding(.top, 10 * scale)
                    Spacer()
                    VStack(spacing: 6 * scale) {
                        FaceButtons(emulator: emulator, size: 124 * scale)
                        HStack(spacing: 10 * scale) {
                            PillButton(button: .select, title: "SELECT", emulator: emulator, scale: scale)
                            PillButton(button: .start, title: "START", emulator: emulator, scale: scale)
                        }
                    }
                }
                .padding(.horizontal, 22 * scale)
            }
            .padding(.top, 18 * scale)
            .padding(.bottom, 16 * scale)
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
                                x: value.location.x / proxy.size.width,
                                y: value.location.y / proxy.size.height
                            ))
                        }
                        .onEnded { _ in emulator.releaseTouch() }
                )
        }
    }
}

// MARK: - Screens

private struct Screen<Content: View>: View {
    let scale: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: screenSize.width * scale, height: screenSize.height * scale)
            .padding(6 * scale)
            .background {
                RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                    .fill(Palette.bezel)
            }
    }
}
