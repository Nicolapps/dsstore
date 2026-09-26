import SwiftUI

/// Shown whenever the app isn't in one of the two configurations it's designed for.
struct UnsupportedView: View {
    enum Reason { case needsDuo, splitView }

    let reason: Reason

    var body: some View {
        ContentUnavailableView {
            switch reason {
            case .needsDuo: Label("Made for iPhone Duo", systemImage: "iphone")
            case .splitView: Label("Split View Isn’t Supported", systemImage: "rectangle.split.2x1")
            }
        } description: {
            switch reason {
            case .needsDuo: Text("The console spans both halves of iPhone Duo’s inner display, just like the real thing.")
            case .splitView: Text("Use DS on its own to browse the shelf when closed and play when open.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }
}

/// Reports whether the scene covers its whole display, which it doesn't in Split View.
struct FullScreenReader: UIViewRepresentable {
    @Binding var fillsScreen: Bool

    func makeUIView(context: Context) -> FullScreenProbe {
        FullScreenProbe()
    }

    func updateUIView(_ probe: FullScreenProbe, context: Context) {
        probe.onChange = { fillsScreen = $0 }
    }
}

final class FullScreenProbe: UIView {
    var onChange: (Bool) -> Void = { _ in }
    private var reported = true
    private var pendingReport: Task<Void, Never>?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        check()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        check()
    }

    private func check() {
        guard let window, let screen = window.windowScene?.screen else { return }
        let scene = window.bounds.size
        let display = screen.bounds.size
        // Orientation-independent, so a rotation in flight doesn't count as a smaller scene.
        let fills = min(scene.width, scene.height) >= min(display.width, display.height) - 1
            && max(scene.width, scene.height) >= max(display.width, display.height) - 1

        pendingReport?.cancel()
        guard fills != reported else { return }
        // While opening or closing, the scene briefly has the other display's size;
        // only a smaller scene that lasts is Split View.
        pendingReport = Task { [weak self] in
            if !fills { try? await Task.sleep(for: .milliseconds(300)) }
            guard let self, !Task.isCancelled else { return }
            reported = fills
            onChange(fills)
        }
    }
}
