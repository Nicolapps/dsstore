import SwiftUI

/// Shows one of the DS screens (0 is the top one, 1 the bottom one).
struct ScreenView: UIViewRepresentable {
    let renderer: ScreenRenderer
    let screenIndex: Int

    func makeUIView(context: Context) -> ScreenMTKView {
        ScreenMTKView(renderer: renderer, screenIndex: screenIndex)
    }

    func updateUIView(_ uiView: ScreenMTKView, context: Context) {}
}
