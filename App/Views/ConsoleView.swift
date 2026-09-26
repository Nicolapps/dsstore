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
}

/// Keep the console attached to the physical display, independent of interface rotation.
struct ConsoleView: View {
    let emulator: DSEmulator
    let onReturnToShelf: () -> Void

    var body: some View {
        PhysicalConsole(emulator: emulator, onReturnToShelf: onReturnToShelf)
            .ignoresSafeArea()
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .preferredColorScheme(.light)
    }
}

private struct PhysicalConsole: UIViewControllerRepresentable {
    let emulator: DSEmulator
    let onReturnToShelf: () -> Void

    func makeUIViewController(context: Context) -> PhysicalConsoleController {
        PhysicalConsoleController(emulator: emulator, onReturnToShelf: onReturnToShelf)
    }

    func updateUIViewController(_ controller: PhysicalConsoleController, context: Context) {}
}

private final class PhysicalConsoleController: UIViewController {
    private let console: UIHostingController<ConsoleBody>

    init(emulator: DSEmulator, onReturnToShelf: @escaping () -> Void) {
        console = UIHostingController(rootView: ConsoleBody(emulator: emulator, onReturnToShelf: onReturnToShelf))
        super.init(nibName: nil, bundle: nil)
        console.safeAreaRegions = []
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(console)
        view.addSubview(console.view)
        console.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutConsole()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutConsole()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Cancel the window's rotation in the same transaction; the console remains
        // attached to the same physical halves, including during the transition.
        coordinator.animate(alongsideTransition: { _ in
            self.layoutConsole()
        }, completion: { _ in
            self.layoutConsole()
        })
    }

    private func layoutConsole() {
        guard let screen = view.window?.windowScene?.screen else { return }
        // Unlike the scene's rotating coordinate space, this is attached to the
        // hardware. In the inner display's fixed portrait space the fold is y / 2.
        let physicalSpace = screen.fixedCoordinateSpace
        let physicalBounds = view.convert(view.bounds, to: physicalSpace)
        let origin = view.convert(CGPoint.zero, from: physicalSpace)
        let right = view.convert(CGPoint(x: 1, y: 0), from: physicalSpace)
        let angle = atan2(right.y - origin.y, right.x - origin.x)

        console.view.bounds = CGRect(origin: .zero, size: physicalBounds.size)
        console.view.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        // Hold the device upside down relative to its fixed portrait orientation, so
        // the top screen sits on the physical half that is at the bottom in portrait.
        console.view.transform = CGAffineTransform(rotationAngle: angle + .pi)
    }
}

/// In hardware coordinates the two equal panels meet at the physical fold.
private struct ConsoleBody: View {
    let emulator: DSEmulator
    let onReturnToShelf: () -> Void

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
                            topInset: proxy.safeAreaInsets.top, onReturnToShelf: onReturnToShelf)
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

private struct Shell: View {
    let scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 25 * scale)
            .fill(LinearGradient(stops: [
                .init(color: .white, location: 0),
                .init(color: Palette.shellLight, location: 0.12),
                .init(color: Color(white: 0.92), location: 0.8),
                .init(color: Palette.shellDark, location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                RoundedRectangle(cornerRadius: 23 * scale)
                    .strokeBorder(.white.opacity(0.95), lineWidth: 2 * scale)
                    .padding(2 * scale)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 19 * scale)
                    .strokeBorder(Color(white: 0.64).opacity(0.4), lineWidth: 0.7 * scale)
                    .padding(7 * scale)
                    .shadow(color: .white, radius: 0, y: 1 * scale)
            }
            .shadow(color: .black.opacity(0.35), radius: 3 * scale, y: 2 * scale)
    }
}

private struct TopHalf: View {
    let emulator: DSEmulator
    let screenWidth: CGFloat
    let scale: CGFloat
    let topInset: CGFloat
    let onReturnToShelf: () -> Void

    var body: some View {
        ZStack {
            Shell(scale: scale)
            VStack(spacing: 0) {
                HStack {
                    RubberFoot(scale: scale)
                    Spacer()
                    Button(action: onReturnToShelf) {
                        Label("Shelf", systemImage: "chevron.left")
                            .font(.system(size: 12 * scale, weight: .medium))
                            .foregroundStyle(Palette.engraving)
                            .padding(.horizontal, 12 * scale)
                            .frame(minWidth: 60, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Return to shelf")
                    .accessibilityHint("Pauses the game")
                    Spacer()
                    RubberFoot(scale: scale)
                }
                Spacer(minLength: 10 * scale)
                HStack(spacing: 0) {
                    SpeakerGrill(scale: scale).frame(maxWidth: .infinity)
                    Screen(width: screenWidth, scale: scale) {
                        ScreenView(renderer: emulator.screenRenderer, screenIndex: 0)
                            .overlay { StatusOverlay(status: emulator.status, scale: scale) }
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
            Shell(scale: scale)
            VStack(spacing: 12 * scale) {
                Screen(width: screenWidth, scale: scale) {
                    ScreenView(renderer: emulator.screenRenderer, screenIndex: 1)
                        .overlay { TouchSurface(emulator: emulator) }
                }
                HStack(alignment: .center, spacing: 0) {
                    DPad(emulator: emulator, size: 104 * scale)
                    Spacer(minLength: 8 * scale)
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
                    Spacer(minLength: 8 * scale)
                    FaceButtons(emulator: emulator, size: 114 * scale)
                }
                .frame(height: 114 * scale)
                .padding(.horizontal, 37 * scale)
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

private struct Screen<Content: View>: View {
    let width: CGFloat
    let scale: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: width, height: width * 3 / 4)
            .clipped()
            .padding(3 * scale)
            .background(Color(white: 0.16))
            .overlay { Rectangle().stroke(.black.opacity(0.5), lineWidth: scale).allowsHitTesting(false) }
            .padding(7 * scale)
            .background {
                RoundedRectangle(cornerRadius: 3 * scale)
                    .fill(LinearGradient(colors: [Color(white: 0.77), .white, Color(white: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing))
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
        case .missingROM: "No game found.\nPut a ROM at ROM/game.nds\n(or game.zip) and rebuild."
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
