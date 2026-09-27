import AVFoundation
import SwiftUI

/// The camera capture accessory only appears while a capture session runs, so the
/// console keeps one going to put the back of the DS on the outer display.
final class AccessoryCamera {
    /// Only touched on `queue` once configured, as AVFoundation recommends.
    nonisolated(unsafe) let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "AccessoryCamera")
    private var isConfigured = false

    func start() {
        Task {
            guard await AVCaptureDevice.requestAccess(for: .video) else { return }
            if !isConfigured { configure() }
            queue.async { [session] in session.startRunning() }
        }
    }

    func stop() {
        queue.async { [session] in session.stopRunning() }
    }

    private func configure() {
        isConfigured = true
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.beginConfiguration()
        session.addInput(input)
        session.commitConfiguration()
    }
}

/// The capture session's preview, which has to be on screen for the accessory to be allowed.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// The back of a DS Lite's top half, as seen by someone facing the player.
struct ConsoleBack: View {
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 500, proxy.size.height / 430)
            ZStack {
                Palette.background
                lid(scale: scale)
                    .padding(.horizontal, 22 * scale)
                    .padding(.vertical, 30 * scale)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.light)
    }

    private func lid(scale: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 34 * scale, style: .continuous)
        return ZStack {
            shape.fill(LinearGradient(stops: [
                .init(color: .white, location: 0),
                .init(color: Palette.shellLight, location: 0.35),
                .init(color: Palette.shellDark, location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            // Glossy reflection across the lid.
            shape.fill(LinearGradient(stops: [
                .init(color: .white.opacity(0.7), location: 0),
                .init(color: .white.opacity(0), location: 0.45)
            ], startPoint: .top, endPoint: .bottom))
                .padding(4 * scale)
            shape.stroke(Color(white: 0.62), lineWidth: 1.5 * scale)

            VStack(spacing: 20 * scale) {
                Spacer()
                Text("Nintendo")
                    .font(.system(size: 34 * scale, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20 * scale).padding(.vertical, 4 * scale)
                    .overlay { Capsule().stroke(lineWidth: 3 * scale) }
                HStack(spacing: 8 * scale) {
                    Text("DS").font(.system(size: 30 * scale, weight: .heavy, design: .rounded)).italic()
                    Text("Lite").font(.system(size: 26 * scale, weight: .light, design: .rounded))
                }
                Spacer()
                Hinge(scale: scale)
            }
            .foregroundStyle(Palette.engraving)
            .shadow(color: .white, radius: 0, x: scale, y: scale)
        }
    }

    /// The two hinge barrels along the bottom edge.
    private struct Hinge: View {
        let scale: CGFloat
        var body: some View {
            HStack {
                barrel
                Spacer()
                barrel
            }
            .padding(.horizontal, 26 * scale)
            .padding(.bottom, 14 * scale)
        }

        private var barrel: some View {
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.7), .white, Color(white: 0.72)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 70 * scale, height: 16 * scale)
                .overlay { Capsule().stroke(.black.opacity(0.15), lineWidth: 0.6) }
        }
    }
}
