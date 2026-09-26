import CoreImage
import Observation
@preconcurrency import DeltaCore
@preconcurrency import MelonDSDeltaCore

/// The hardware buttons of a Nintendo DS.
enum DSButton: CaseIterable {
    case a, b, x, y, l, r, start, select, up, down, left, right

    fileprivate var input: MelonDSGameInput {
        switch self {
        case .a: .a
        case .b: .b
        case .x: .x
        case .y: .y
        case .l: .l
        case .r: .r
        case .start: .start
        case .select: .select
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
    }
}

/// Owns the emulator and exposes the small surface the SwiftUI layer needs:
/// lifecycle, button presses, touches, and one view per screen.
@Observable
final class DSEmulator {
    enum Status: Equatable {
        case stopped
        case running
        case paused
        case missingROM
        case failed(String)
    }

    private(set) var status: Status = .stopped

    /// Views displaying the top and bottom screens. Both render the same video feed, cropped to their half.
    let topScreen = GameView()
    let bottomScreen = GameView()

    @ObservationIgnored private var core: EmulatorCore?
    @ObservationIgnored private let bridge = MelonDS.core.emulatorBridge

    init() {
        Delta.register(MelonDS.core)

        // melonDS outputs both screens stacked in a single 256×384 frame.
        topScreen.filter = FilterChain(filters: [Self.cropFilter(screenIndex: 0)])
        bottomScreen.filter = FilterChain(filters: [Self.cropFilter(screenIndex: 1)])
    }

    func start() {
        guard core == nil else { return }

        guard let game = BundledGame() else {
            status = .missingROM
            return
        }

        guard let core = EmulatorCore(game: game) else {
            status = .failed("The DS core is not registered.")
            return
        }

        core.add(topScreen)
        core.add(bottomScreen)
        core.start()

        self.core = core
        status = .running
    }

    func pause() {
        guard let core, core.pause() else { return }
        bridge.resetInputs()
        status = .paused
    }

    func resume() {
        guard let core, core.resume() else { return }
        status = .running
    }

    // MARK: - Input

    func press(_ button: DSButton) {
        bridge.activateInput(button.input.rawValue, value: 1, playerIndex: 0)
    }

    func release(_ button: DSButton) {
        bridge.deactivateInput(button.input.rawValue, playerIndex: 0)
    }

    /// Touches the bottom screen at a point normalized to 0...1 on both axes.
    func touch(at point: CGPoint) {
        bridge.activateInput(MelonDSGameInput.touchScreenX.rawValue, value: min(max(point.x, 0), 1), playerIndex: 0)
        bridge.activateInput(MelonDSGameInput.touchScreenY.rawValue, value: min(max(point.y, 0), 1), playerIndex: 0)
    }

    func releaseTouch() {
        bridge.deactivateInput(MelonDSGameInput.touchScreenX.rawValue, playerIndex: 0)
        bridge.deactivateInput(MelonDSGameInput.touchScreenY.rawValue, playerIndex: 0)
    }

    private static func cropFilter(screenIndex: Int) -> CIFilter {
        // FilterChain works in top-left-origin coordinates.
        let rect = CGRect(x: 0, y: 192 * screenIndex, width: 256, height: 192)
        return CIFilter(name: "CICrop", parameters: ["inputRectangle": CIVector(cgRect: rect)])!
    }
}

/// The single game the app plays: `game.nds`, copied into the bundle at build time.
private struct BundledGame: GameProtocol {
    let fileURL: URL
    let type = GameType.ds

    /// Saves can't live next to the ROM because the app bundle is read-only.
    var gameSaveURL: URL {
        URL.applicationSupportDirectory.appending(path: "game.dsv")
    }

    init?() {
        guard let url = Bundle.main.url(forResource: "game", withExtension: "nds") else { return nil }
        fileURL = url
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
    }
}
