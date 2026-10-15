import CoreGraphics
import Foundation
import Metal

/// Renders a `PixelFormulaProgram` to a `CGImage` (PRD FR-10). The formula is transpiled to
/// MSL and compiled at runtime; pixels are computed in row bands so a heavy 50-term double
/// sum never trips the GPU watchdog, and cancellation is checked between bands. Without a
/// Metal device the CPU evaluator renders a small preview instead.
nonisolated final class PixelFormulaRenderer: @unchecked Sendable {
    static let shared = PixelFormulaRenderer()

    struct RenderError: Error, CustomStringConvertible {
        let description: String
    }

    /// Rows per compute dispatch. 64 rows × 2000 columns of the sample formula finish in
    /// well under the ~1s GPU command timeout on A-series hardware.
    static let bandRows = 64
    /// CPU fallback stays tiny on purpose: the tree-walking evaluator costs ~60ms per pixel
    /// on the bundled sample.
    static let cpuFallbackMaxWidth = 64

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let pipelineLock = NSLock()
    private var pipelineCache: [String: MTLComputePipelineState] = [:]

    var isGPUAvailable: Bool { device != nil && commandQueue != nil }

    private init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
    }

    // MARK: - Public API

    /// Renders `program` at `program.width × program.height` divided by `downsample`
    /// (1 = full resolution). Runs off the main actor; throws `CancellationError` if the
    /// task is cancelled between bands.
    func render(_ program: PixelFormulaProgram, downsample: Int = 1) async throws -> CGImage {
        let factor = max(1, downsample)
        let width = max(1, program.width / factor)
        let height = max(1, program.height / factor)
        guard width * height <= PixelFormulaProgram.maxPixels else {
            throw RenderError(description: "이미지가 너무 큽니다 (최대 \(PixelFormulaProgram.defaultSize.width)×\(PixelFormulaProgram.defaultSize.height))")
        }
        let scaleX = Float(program.width) / Float(width)
        let scaleY = Float(program.height) / Float(height)

        if isGPUAvailable {
            return try await Task.detached(priority: .userInitiated) { [self] in
                try renderOnGPU(program, width: width, height: height, scaleX: scaleX, scaleY: scaleY)
            }.value
        }
        return try await renderOnCPU(program, width: width, height: height, scaleX: scaleX, scaleY: scaleY)
    }

    /// Compiles the shader without rendering — lets callers surface MSL errors early.
    func compile(_ program: PixelFormulaProgram) throws {
        _ = try pipeline(for: program)
    }

    // MARK: - GPU path

    private func pipeline(for program: PixelFormulaProgram) throws -> MTLComputePipelineState {
        guard let device else { throw RenderError(description: "이 기기에서는 Metal을 사용할 수 없습니다") }
        let source = MetalShaderTranspiler.source(for: program)
        pipelineLock.lock()
        let cached = pipelineCache[source]
        pipelineLock.unlock()
        if let cached { return cached }

        let options = MTLCompileOptions()
        // Precise IEEE semantics matter here: the formulas lean on exp overflow → ∞ → 0
        // chains that fast-math would happily "optimize" into garbage.
        options.mathMode = .safe
        options.mathFloatingPointFunctions = .precise
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: source, options: options)
        } catch {
            throw RenderError(description: "셰이더 컴파일 실패: \(error.localizedDescription)")
        }
        guard let function = library.makeFunction(name: MetalShaderTranspiler.kernelName) else {
            throw RenderError(description: "셰이더 커널을 찾을 수 없습니다")
        }
        let state = try device.makeComputePipelineState(function: function)
        pipelineLock.lock()
        pipelineCache[source] = state
        if pipelineCache.count > 8 { pipelineCache.removeAll() }
        pipelineLock.unlock()
        return state
    }

    private func renderOnGPU(_ program: PixelFormulaProgram, width: Int, height: Int,
                             scaleX: Float, scaleY: Float) throws -> CGImage {
        guard let device, let commandQueue else { throw RenderError(description: "Metal을 사용할 수 없습니다") }
        let state = try pipeline(for: program)
        let byteCount = width * height * 4
        guard let buffer = device.makeBuffer(length: byteCount, options: .storageModeShared) else {
            throw RenderError(description: "GPU 버퍼를 만들 수 없습니다")
        }

        let threadWidth = min(state.threadExecutionWidth, width)
        let threadHeight = max(1, min(state.maxTotalThreadsPerThreadgroup / threadWidth, Self.bandRows))
        let threadsPerGroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)

        var row = 0
        while row < height {
            try Task.checkCancellation()
            let rows = min(Self.bandRows, height - row)
            var uniforms = MetalShaderTranspiler.Uniforms(width: UInt32(width), height: UInt32(height),
                                                          rowOffset: UInt32(row), bandRows: UInt32(rows),
                                                          scaleX: scaleX, scaleY: scaleY)
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw RenderError(description: "GPU 명령을 만들 수 없습니다")
            }
            encoder.setComputePipelineState(state)
            encoder.setBuffer(buffer, offset: 0, index: 0)
            encoder.setBytes(&uniforms, length: MemoryLayout<MetalShaderTranspiler.Uniforms>.stride, index: 1)
            // dispatchThreadgroups (uniform grid, rounded up) rather than dispatchThreads: the
            // simulator's Metal device doesn't support non-uniform threadgroup sizes and the
            // API validation layer aborts on it — the kernel discards the overhang itself.
            let groups = MTLSize(width: (width + threadWidth - 1) / threadWidth,
                                 height: (rows + threadHeight - 1) / threadHeight, depth: 1)
            encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            if let error = commandBuffer.error {
                throw RenderError(description: "GPU 렌더링 오류: \(error.localizedDescription)")
            }
            row += rows
        }

        let data = Data(bytes: buffer.contents(), count: byteCount)
        return try Self.makeImage(rgba: data, width: width, height: height)
    }

    // MARK: - CPU fallback

    private func renderOnCPU(_ program: PixelFormulaProgram, width: Int, height: Int,
                             scaleX: Float, scaleY: Float) async throws -> CGImage {
        // Shrink further; this path exists for correctness, not speed.
        let shrink = max(1, Int((Double(width) / Double(Self.cpuFallbackMaxWidth)).rounded(.up)))
        let w = max(1, width / shrink), h = max(1, height / shrink)
        let sx = Double(scaleX) * Double(shrink), sy = Double(scaleY) * Double(shrink)
        let evaluator = PixelFormulaEvaluator(program: program)

        let rows: [[UInt8]] = try await withThrowingTaskGroup(of: (Int, [UInt8]).self) { group in
            for y in 0..<h {
                group.addTask {
                    try Task.checkCancellation()
                    var line = [UInt8](repeating: 255, count: w * 4)
                    let n = (Double(y) + 0.5) * sy + 0.5
                    for x in 0..<w {
                        let m = (Double(x) + 0.5) * sx + 0.5
                        let c = evaluator.pixelColor(m: m, n: n)
                        line[x * 4] = c.r
                        line[x * 4 + 1] = c.g
                        line[x * 4 + 2] = c.b
                    }
                    return (y, line)
                }
            }
            var collected = [[UInt8]](repeating: [], count: h)
            for try await (y, line) in group { collected[y] = line }
            return collected
        }
        var data = Data(capacity: w * h * 4)
        for line in rows { data.append(contentsOf: line) }
        return try Self.makeImage(rgba: data, width: w, height: h)
    }

    // MARK: - Image packaging

    static func makeImage(rgba data: Data, width: Int, height: Int) throws -> CGImage {
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw RenderError(description: "이미지를 만들 수 없습니다")
        }
        return image
    }
}
