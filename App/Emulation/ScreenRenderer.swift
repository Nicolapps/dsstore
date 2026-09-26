import MetalKit

/// Draws the DS screens with Metal, straight from melonDS' framebuffer.
///
/// DeltaCore's own `GameView` is not used: its OpenGL ES path crashes and its Metal path presents blank frames.
nonisolated final class ScreenRenderer: @unchecked Sendable {
    static let frameSize = (width: 256, height: 384) // Both screens, stacked.

    let device: MTLDevice
    fileprivate let commandQueue: MTLCommandQueue
    fileprivate let pipeline: MTLRenderPipelineState
    fileprivate let sampler: MTLSamplerState
    fileprivate let frame: MTLTexture

    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: Self.shaderSource, options: nil)
        else { fatalError("Metal is unavailable.") }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "screenVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "screenFragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Self.frameSize.width,
            height: Self.frameSize.height,
            mipmapped: false
        )

        self.device = device
        self.commandQueue = commandQueue
        self.pipeline = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        self.sampler = device.makeSamplerState(descriptor: samplerDescriptor)!
        self.frame = device.makeTexture(descriptor: textureDescriptor)!
    }

    /// Uploads a BGRA frame. Called from the emulation thread after every frame.
    func upload(_ pixels: UnsafePointer<UInt8>) {
        frame.replace(
            region: MTLRegionMake2D(0, 0, Self.frameSize.width, Self.frameSize.height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: Self.frameSize.width * 4
        )
    }
}

/// A view showing one of the two screens, redrawn at the display's refresh rate.
final class ScreenMTKView: MTKView, MTKViewDelegate {
    private let renderer: ScreenRenderer
    private var screenIndex: Float

    init(renderer: ScreenRenderer, screenIndex: Int) {
        self.renderer = renderer
        self.screenIndex = Float(screenIndex)
        super.init(frame: .zero, device: renderer.device)

        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        preferredFramesPerSecond = 60
        delegate = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let passDescriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else { return }

        encoder.setRenderPipelineState(renderer.pipeline)
        encoder.setVertexBytes(&screenIndex, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentTexture(renderer.frame, index: 0)
        encoder.setFragmentSamplerState(renderer.sampler, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

private nonisolated extension ScreenRenderer {
    /// Compiled at runtime so building doesn't require the separately downloaded Metal toolchain.
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct ScreenVertex {
        float4 position [[position]];
        float2 textureCoordinate;
    };

    /// Draws a full-view quad that samples one half of the stacked 256×384 frame.
    vertex ScreenVertex screenVertex(uint vertexID [[vertex_id]], constant float &screenIndex [[buffer(0)]]) {
        const float2 corners[4] = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } };
        float2 corner = corners[vertexID];

        ScreenVertex out;
        out.position = float4(corner.x * 2 - 1, 1 - corner.y * 2, 0, 1);
        out.textureCoordinate = float2(corner.x, (corner.y + screenIndex) * 0.5);
        return out;
    }

    fragment float4 screenFragment(ScreenVertex in [[stage_in]], texture2d<float> frame [[texture(0)]], sampler frameSampler [[sampler(0)]]) {
        // melonDS leaves alpha at 0, so ignore it.
        return float4(frame.sample(frameSampler, in.textureCoordinate).rgb, 1);
    }
    """
}
