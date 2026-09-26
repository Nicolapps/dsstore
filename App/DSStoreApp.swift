import SwiftUI

@main
struct DSStoreApp: App {
    var body: some Scene {
        WindowGroup {
            GameLibraryView()
        }
    }
}

private struct GameLibraryView: View {
    @State private var emulator = DSEmulator()
    @State private var isPlaying = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if isPlaying {
                ConsoleView(emulator: emulator, onReturnToShelf: {
                    emulator.pause()
                    isPlaying = false
                })
                .onAppear {
                    emulator.start()
                    if scenePhase == .active { emulator.resume() }
                    else { emulator.pause() }
                }
                .onDisappear { emulator.pause() }
            } else {
                GameSelectionView(onPlay: { isPlaying = true })
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isPlaying { emulator.resume() }
            else { emulator.pause() }
        }
    }
}
