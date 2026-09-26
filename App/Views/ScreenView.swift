import SwiftUI
@preconcurrency import DeltaCore

/// Hosts one of the emulator's `GameView`s.
struct ScreenView: UIViewRepresentable {
    let gameView: GameView

    func makeUIView(context: Context) -> GameView {
        gameView.backgroundColor = .black
        return gameView
    }

    func updateUIView(_ uiView: GameView, context: Context) {}
}
