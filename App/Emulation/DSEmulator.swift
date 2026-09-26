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

    /// Draws both screens from the emulator's frames.
    let screenRenderer = ScreenRenderer()

    @ObservationIgnored private var core: EmulatorCore?
    @ObservationIgnored private var currentGameID: String?
    @ObservationIgnored private let bridge = MelonDS.core.emulatorBridge

    /// Launch with `DSSTORE_MUTE=1` to silence the game, e.g. while testing in the simulator.
    @ObservationIgnored private let isMuted = ProcessInfo.processInfo.environment["DSSTORE_MUTE"] == "1"

    init() {
        Delta.register(MelonDS.core)
    }

    /// Boots the game with this id, ejecting any other game first.
    func start(gameID: String) {
        if core != nil, currentGameID == gameID { return }
        stop()
        currentGameID = gameID

        guard let game = BundledGame(id: gameID) else {
            status = .missingROM
            return
        }

        // Frames are drawn by ScreenRenderer, but this keeps DeltaCore from creating OpenGL ES contexts.
        guard let core = EmulatorCore(game: game, options: [.metal: true]) else {
            status = .failed("The DS core is not registered.")
            return
        }

        core.updateHandler = Self.frameHandler(uploadingTo: screenRenderer)
        core.start()
        if isMuted { core.audioManager.isEnabled = false }

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
        if isMuted { core.audioManager.isEnabled = false }
        status = .running
    }

    /// Ejects the game, saving it first; the next `start(gameID:)` boots it from scratch.
    func stop() {
        if let core {
            core.stop()
            bridge.resetInputs()
            self.core = nil
        }
        currentGameID = nil
        status = .stopped
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

    /// Built outside the main actor because DeltaCore calls it on its emulation thread.
    private nonisolated static func frameHandler(uploadingTo renderer: ScreenRenderer) -> (EmulatorCore) -> Void {
        { core in
            guard let pixels = core.videoManager.videoBuffer else { return }
            renderer.upload(pixels)
        }
    }
}

/// A game copied into the bundle at build time as `Games/<id>.nds`.
private struct BundledGame: GameProtocol {
    let fileURL: URL
    let gameSaveURL: URL
    let type = GameType.ds

    init?(id: String) {
        guard let url = Bundle.main.url(forResource: id, withExtension: "nds", subdirectory: "Games") else { return nil }
        fileURL = url
        // Saves can't live next to the ROM because the app bundle is read-only.
        let saves = URL.applicationSupportDirectory.appending(path: "Saves")
        gameSaveURL = saves.appending(path: "\(id).dsv")
        try? FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
        // Mario Kart was once the only game, saved as `game.dsv`.
        if id == "kart" {
            try? FileManager.default.moveItem(at: .applicationSupportDirectory.appending(path: "game.dsv"), to: gameSaveURL)
        }
    }
}
