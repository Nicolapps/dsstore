import SwiftUI

extension View {
    /// Keeps this view attached to the physical display, independent of interface rotation.
    /// `upsideDown` holds it upside down relative to the display's fixed portrait orientation.
    func attachedToPhysicalDisplay(upsideDown: Bool = false) -> some View {
        PhysicalDisplay(content: self, upsideDown: upsideDown)
            .ignoresSafeArea()
    }
}

private struct PhysicalDisplay<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let upsideDown: Bool

    func makeUIViewController(context: Context) -> PhysicalDisplayController<Content> {
        PhysicalDisplayController(content: content, upsideDown: upsideDown)
    }

    func updateUIViewController(_ controller: PhysicalDisplayController<Content>, context: Context) {
        controller.update(content: content, upsideDown: upsideDown)
    }
}

private final class PhysicalDisplayController<Content: View>: UIViewController {
    private let host: UIHostingController<Content>
    private var upsideDown: Bool

    init(content: Content, upsideDown: Bool) {
        host = UIHostingController(rootView: content)
        self.upsideDown = upsideDown
        super.init(nibName: nil, bundle: nil)
        host.safeAreaRegions = []
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    /// Freezes the scene's interface orientation while this is on screen, so the system
    /// never runs a rotation. SwiftUI's hosting controller forwards this preference to us.
    override var prefersInterfaceOrientationLocked: Bool { true }

    func update(content: Content, upsideDown: Bool) {
        host.rootView = content
        guard upsideDown != self.upsideDown else { return }
        self.upsideDown = upsideDown
        layoutContent()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfPrefersInterfaceOrientationLocked()
        layoutContent()
    }

    private func layoutContent() {
        guard let screen = view.window?.windowScene?.screen else { return }
        // The lock keeps whichever orientation the scene had when it engaged, so map
        // that orientation onto the hardware, whose coordinate space never rotates.
        let physicalSpace = screen.fixedCoordinateSpace
        let physicalBounds = view.convert(view.bounds, to: physicalSpace)
        let origin = view.convert(CGPoint.zero, from: physicalSpace)
        let right = view.convert(CGPoint(x: 1, y: 0), from: physicalSpace)
        let angle = atan2(right.y - origin.y, right.x - origin.x)

        host.view.bounds = CGRect(origin: .zero, size: physicalBounds.size)
        host.view.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        host.view.transform = CGAffineTransform(rotationAngle: upsideDown ? angle + .pi : angle)
    }
}
