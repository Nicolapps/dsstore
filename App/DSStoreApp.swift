import SwiftUI

@main
struct DSStoreApp: App {
    var body: some Scene {
        WindowGroup {
            DuoRootView()
        }
    }
}

/// Maps iPhone Duo's poses onto the store: closed, the outer display shows the shelf;
/// open, the inner display is the console. Every other configuration is unsupported.
private struct DuoRootView: View {
    private enum Pose { case unknown, noHinge, closed, open }

    @State private var emulator = DSEmulator()
    @State private var pose = Pose.unknown
    @State private var fillsScreen = true
    /// The game waiting in the middle of the store; it boots once the device opens.
    @State private var selectedGame: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .background { FullScreenReader(fillsScreen: $fillsScreen) }
            .onHingeChange { _, context in
                // The hinge doesn't go away, so ignore updates that briefly lack one.
                guard let status = context.hinge?.status else { return }
                pose = status == .closed ? .closed : .open
            }
            .task {
                // Devices without a hinge never report one.
                try? await Task.sleep(for: .milliseconds(500))
                if pose == .unknown { pose = .noHinge }
            }
            .onChange(of: pose) { syncEmulator() }
            .onChange(of: fillsScreen) { syncEmulator() }
            .onChange(of: selectedGame) { syncEmulator() }
            .onChange(of: scenePhase) { syncEmulator() }
    }

    @ViewBuilder private var content: some View {
        switch pose {
        case .unknown:
            Color.black.ignoresSafeArea()
        case .noHinge:
            UnsupportedView(reason: .needsDuo)
        case _ where !fillsScreen:
            UnsupportedView(reason: .splitView)
        case .closed:
            GameSelectionView(selection: $selectedGame)
        case .open:
            ConsoleView(emulator: emulator)
        }
    }

    /// Runs the selected game only while the console is on screen.
    private func syncEmulator() {
        guard selectedGame != nil else { return emulator.stop() }
        guard pose == .open, fillsScreen, scenePhase == .active else { return emulator.pause() }
        emulator.start()
        emulator.resume()
    }
}
