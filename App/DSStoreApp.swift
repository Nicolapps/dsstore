import SwiftUI

@main
struct DSStoreApp: App {
    @State private var emulator = DSEmulator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ConsoleView(emulator: emulator)
                .onAppear { emulator.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        emulator.resume()
                    } else {
                        emulator.pause()
                    }
                }
        }
    }
}
