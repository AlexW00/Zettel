---
name: metal-motion-effects
description: Integrating device motion (gyroscope/accelerometer) with Metal shaders on iOS, and the MTKView fallback for when SwiftUI shaders are insufficient. Use this skill when the user wants to add tilt-reactive effects (parallax, specular highlights, holographic shimmer) driven by CMMotionManager, needs to wrap MTKView in SwiftUI via UIViewRepresentable, wants to render a shader result to an offscreen MTLTexture (bake/cache), or needs to optimize Metal shader performance and battery usage. Also trigger for questions about CMDeviceMotion attitude, render-to-texture patterns, Low Power Mode gating, or when to choose MTKView over SwiftUI shaders.
---

# Metal Motion Effects & MTKView Integration

This skill covers three related topics: piping device motion into shaders, the MTKView fallback for when SwiftUI's shader API is insufficient, and performance/battery patterns for shipping shader-based UI effects.

## Core Motion → Shader Pipeline

### Minimum Viable Motion Provider

```swift
import CoreMotion

@Observable
final class MotionProvider {
    private let manager = CMMotionManager()
    var roll: Double = 0
    var pitch: Double = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0  // 30 Hz for UI effects
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            self?.roll = d.attitude.roll
            self?.pitch = d.attitude.pitch
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
```

### Key Decisions

**Use `startDeviceMotionUpdates`, not `startGyroUpdates` or `startAccelerometerUpdates`.** Device motion is sensor-fused (gyro + accelerometer + magnetometer), yields stable `attitude` (roll/pitch/yaw), and is what Apple's own parallax effects use internally.

**30 Hz is enough for UI effects.** Even on ProMotion 120 Hz displays, motion data only needs to update fast enough that the current sample is fresh when each shader frame draws. 60 Hz costs roughly double the sensor power for negligible visual improvement. Use 60 Hz only for high-fidelity parallax centered on screen where 30 Hz is visibly steppy.

**Apply smoothing and clamping before feeding to shaders:**
```swift
// Exponential smoothing
smoothedRoll = 0.85 * smoothedRoll + 0.15 * rawRoll

// Clamp to useful range (avoid discontinuities at ±π boundary)
let clampedRoll = max(-0.5, min(0.5, rawRoll))
```

Raw `attitude.roll` ranges over -π…π and can flip discontinuously near the boundary. For "shiny card" effects, ±0.5 rad is a safe working range.

### Composing Motion with TimelineView

Motion updates push into `@Observable` properties. `TimelineView(.animation)` causes the body to re-evaluate every frame, reading the freshest available motion:

```swift
struct TiltShaderView: View {
    @State private var motion = MotionProvider()

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = startDate.distance(to: context.date)
            stampView
                .colorEffect(
                    ShaderLibrary.myShader(
                        .float(Float(elapsed)),
                        .float2(Float(motion.roll), Float(motion.pitch))
                    )
                )
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }  // critical for battery
    }
}
```

### In the Shader: Tilt-Driven Specular

```cpp
// Map tilt to a specular hotspot center
float2 specCenter = float2(0.5 + tilt.x * 0.35, 0.5 + tilt.y * 0.35);
float d = distance(uv, specCenter);
float hotspot = exp(-d * d * 9.0);  // tight Gaussian falloff

// Modulate by wetness / time so effect fades
half3 specular = half3(1.0h) * half(hotspot) * half(wetness);
```

The 0.35 multiplier caps the hotspot offset at ±35% of UV space — it never leaves the stamp/card region.

---

## MTKView in SwiftUI — When and How

### When to Use MTKView Instead of SwiftUI Shaders

- ≥ 2 texture inputs (SwiftUI limits to 1 `.image()` per Shader)
- Compute kernels (particle systems, separable blur, FFT)
- Offscreen render targets / bake-to-texture caching
- `MTLFunctionConstantValues` for shader specialization
- Full control over command buffers, encoders, blend states

### Minimum UIViewRepresentable Wrapper

```swift
import MetalKit

struct MetalCanvas: UIViewRepresentable {
    let renderer: MetalRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.delegate = renderer
        view.framebufferOnly = true          // true unless you read the drawable
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0) // transparent
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {}
}
```

### Renderer Skeleton

```swift
final class MetalRenderer: NSObject, MTKViewDelegate, ObservableObject {
    let device: MTLDevice
    let queue: MTLCommandQueue
    private var pipeline: MTLRenderPipelineState!

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        super.init()

        let lib = device.makeDefaultLibrary()!
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = lib.makeFunction(name: "vertex_main")
        desc.fragmentFunction = lib.makeFunction(name: "fragment_main")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb

        // For transparent overlay on SwiftUI:
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .one
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .one
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipeline = try! device.makeRenderPipelineState(descriptor: desc)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cb = queue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }

        enc.setRenderPipelineState(pipeline)
        // Set uniforms, textures, etc.
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }
}
```

**Critical:** `MTLDevice` and `MTLCommandQueue` are expensive to create — keep them alive for the app's lifetime (e.g., in an environment object or singleton). Pipeline states are also expensive (compile + link); cache per shader variant.

### Full-screen Quad Vertex Shader

A common pattern for 2D effects — no vertex buffer, just hardcoded positions:

```cpp
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(uint vid [[vertex_id]]) {
    float2 positions[6] = {
        {-1, -1}, { 1, -1}, {-1,  1},
        {-1,  1}, { 1, -1}, { 1,  1}
    };
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.uv = positions[vid] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;  // flip Y for UIKit coordinates
    return out;
}
```

---

## Bake-to-Texture (Cache a Shader Result)

For effects that become static after an animation completes (e.g., a stamp whose ink has dried), render the expensive shader once to an offscreen texture, then display that texture as a static image.

### Create the Offscreen Texture

```swift
let desc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgba8Unorm_srgb,
    width: Int(size.width * scale),
    height: Int(size.height * scale),
    mipmapped: false
)
desc.usage = [.renderTarget, .shaderRead]
let cachedTexture = device.makeTexture(descriptor: desc)!
```

### Render to It Once

```swift
let rpd = MTLRenderPassDescriptor()
rpd.colorAttachments[0].texture = cachedTexture
rpd.colorAttachments[0].loadAction = .clear
rpd.colorAttachments[0].storeAction = .store
rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

let cb = queue.makeCommandBuffer()!
let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
enc.setRenderPipelineState(pipeline)
// bind uniforms at final state (e.g., wetness = 0)
enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
enc.endEncoding()
cb.commit()
cb.waitUntilCompleted()
```

### Display as SwiftUI Image

Convert `MTLTexture` → `CGImage` → `Image`:
```swift
func textureToImage(_ texture: MTLTexture) -> CGImage? {
    let w = texture.width, h = texture.height
    let bytesPerRow = w * 4
    var bytes = [UInt8](repeating: 0, count: h * bytesPerRow)
    texture.getBytes(&bytes, bytesPerRow: bytesPerRow,
                     from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: &bytes, width: w, height: h,
                        bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    return ctx?.makeImage()
}
```

After baking, switch the view from the live shader to a static `Image` — the shader stops running entirely, recovering GPU and battery.

---

## Performance and Battery

### Low Power Mode Gating

```swift
if ProcessInfo.processInfo.isLowPowerModeEnabled {
    // Show a pre-rendered static PNG instead of running the shader
    Image("stamp-static")
} else {
    // Run the live shader
    StampShaderView()
}

// React to state changes mid-session:
NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
    .sink { _ in /* update @State flag */ }
```

### Motion Lifecycle

**Always call `manager.stopDeviceMotionUpdates()` in `.onDisappear`.** Core Motion keeps the sensors powered until explicitly stopped. If the view scrolls off-screen or is covered by a sheet, the sensors burn battery for no visible effect.

### Shader Cost Budget

A fragment shader on a 200×200 pt region at 3× scale = 360,000 pixels at 60 fps = 21.6M shader invocations/sec. Apple Family 9 GPUs (A17 Pro, M3) handle this trivially even with 3 octaves of Perlin + a 9-cell Worley lookup. **UI shader cost is almost never the bottleneck** — overdraw (multiple layerEffect passes) and CPU-side state churn (recreating Shader objects) are the real risks.

### Optimization Checklist

1. **Use `half` precision** for colors and intermediates. See the `msl-techniques` skill.
2. **Reorder modifiers** to put `.colorEffect`s before `.distortionEffect` / `.layerEffect` — they fold into one render pass.
3. **Bake to texture** when the animation completes. Switch from live shader to static `Image`.
4. **Gate on Low Power Mode.** Show a static fallback when `isLowPowerModeEnabled` is true.
5. **Stop Core Motion** on `.onDisappear`. Do not just lower the frequency — stop entirely.
6. **Pre-warm with `Shader.compile(as:)`** (iOS 18+) on app launch for gesture-driven effects.
7. **Keep shader arguments ≤ 8 scalars.** Pack vectors. Avoid array arguments when possible.

### Debugging

**GPU Frame Capture in Xcode:** Scheme → Run → Options → "GPU Frame Capture: Metal". Click the camera icon in the debug bar at runtime. Xcode pauses, captures the frame, and opens the Metal Debugger with per-encoder breakdown, bound buffers/textures, generated MSL, and shader stepping.

For SwiftUI `[[stitchable]]` shaders, your shader appears inside SwiftUI's compositor in the captured frame. The Debug Shader workflow works: edit MSL in the debugger, hit "Reload Shader," see the result without rebuilding.

**Metal System Trace** (Instruments) shows CPU/GPU timing, shader occupancy, memory bandwidth, and frame pacing. Use it to verify the shader isn't blocking CPU on encode or saturating bandwidth on a layer effect sampling too many pixels.

---

## iOS 26 / Metal 4 Note

Metal 4 (WWDC 2025) is mostly orthogonal to UI shader work. Its features — tensors in MSL, `MTL4CommandQueue`, residency sets, MetalFX Frame Interpolation — target games and ML workloads. For SwiftUI `[[stitchable]]` shaders, nothing changes at the language level. Existing shaders run unchanged on iOS 26. No migration needed.

## Open-Source References

- **maustinstar/shiny** — gyroscope-driven lighting effects as a `.shiny()` SwiftUI view modifier. Inspect for the Core Motion → gradient pipeline pattern.
- **Mercari Merpay engineering blog (Dec 2022)** — holographic card effect using CMDeviceMotion attitude at 60 fps, pure SwiftUI + Combine. Documents the 0–360° HSB hue mapping and explicit `.stop()` lifecycle.
- **twostraws/Inferno** — emboss, noise gradient, transition shaders. Study the `layerEffect` sampling patterns.
- **Apple "Create custom visual effects with SwiftUI"** (WWDC24 session 10151) — the most current Apple-authored walkthrough of layerEffect + TimelineView.
