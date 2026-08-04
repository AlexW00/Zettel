---
name: swiftui-metal-shaders
description: How to write and integrate Metal shaders into SwiftUI views using the iOS 17+ [[stitchable]] shader API. Use this skill whenever the user wants to add a Metal shader to a SwiftUI view, use .colorEffect / .distortionEffect / .layerEffect, pass arguments to a shader via ShaderLibrary, animate a shader with TimelineView, warm up shader compilation with Shader.compile(as:), or debug silent shader failures. Also use when the user asks about SwiftUI::Layer, stitchable attribute, Shader.Argument types, or maxSampleOffset. Trigger even for seemingly simple shader tasks — the API has many silent-failure pitfalls that this skill documents.
---

# SwiftUI Metal Shaders (iOS 17+)

The `[[stitchable]]` attribute + `ShaderLibrary` API lets you write Metal fragment functions that SwiftUI applies directly to views — no MTKView, no pipeline setup, no command buffers. This skill covers the exact contract, argument mappings, known bugs, and patterns.

## File Setup

Add a `.metal` file to your Xcode target. Xcode auto-compiles all `.metal` files into the default metallib and registers `[[stitchable]]` functions with SwiftUI's runtime.

```cpp
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>   // required ONLY when using SwiftUI::Layer
using namespace metal;
```

The `[[stitchable]]` attribute is mandatory — without it the function exists in the metallib but `ShaderLibrary.yourFunction()` silently fails to render.

## The Three Modifier Types

Each modifier has a **rigid function signature**. The first parameters are implicitly provided by SwiftUI — you never pass them from Swift. Your custom arguments come after.

### colorEffect — per-pixel color transform

```cpp
[[stitchable]] half4 name(float2 position, half4 color, args...)
```

- Receives the destination pixel position and the view's current color at that pixel.
- Use for: tinting, palette mapping, generative patterns, dithering, color grading.
- **Cannot read neighboring pixels.**

### distortionEffect — geometric remap

```cpp
[[stitchable]] float2 name(float2 position, args...)
```

- Receives the destination position; **returns the source position** SwiftUI should sample instead.
- Use for: waves, ripples, lens distortion, page curl, glitch shifts.
- If you return a position outside the padded region, the pixel is transparent.

### layerEffect — full filter with arbitrary sampling

```cpp
[[stitchable]] half4 name(float2 position, SwiftUI::Layer layer, args...)
```

- Receives a `SwiftUI::Layer` you can `.sample(float2)` at any position.
- Use for: blur, emboss, pixelate, RGB-split, any multi-sample effect.
- Most flexible, most expensive — each layerEffect is a separate render pass.

### SwiftUI::Layer details

`layer.sample(float2 position)` returns a **premultiplied, linearly-filtered `half4`** in the destination color space. Two consequences:
- Alpha is already multiplied into RGB — blending with `mix()` works, but multiplying by an additional alpha double-darkens.
- Sampling outside the layer's bounds returns `(0,0,0,0)`, not an error.

## Argument Type Mapping

This mapping is a **hard contract** — a type mismatch compiles cleanly but silently produces garbage at runtime. There is no runtime type-checking.

| Swift `Shader.Argument`                          | MSL parameter type                          |
|--------------------------------------------------|---------------------------------------------|
| `.float(T)`                                      | `float`                                     |
| `.float2(CGPoint)` / `.float2(T, T)`             | `float2`                                    |
| `.float3(T, T, T)`                               | `float3`                                    |
| `.float4(T, T, T, T)`                            | `float4`                                    |
| `.color(Color)`                                  | `half4` (premultiplied, target color space) |
| `.colorArray([Color])`                            | `device const half4 *ptr, int count`        |
| `.image(Image)`                                  | `texture2d<half>`                           |
| `.floatArray([Float])`                            | `device const float *ptr, int count`        |
| `.data(Data)`                                    | `device const void *ptr, int size_in_bytes` |
| `.boundingRect`                                  | `float4` as `(x, y, width, height)`         |

### The one-image limit

**Only ONE `.image()` argument is supported per `Shader` instance.** The `SwiftUI::Layer` in layerEffect does not count against this limit. If you need multiple textures, drop to MTKView.

### Array arguments expand to TWO MSL parameters

`.colorArray([Color])` becomes `device const half4 *colors, int colorCount` in MSL — two parameters from one Swift argument. Same for `.floatArray` and `.data`. Account for this in your parameter ordering.

## Reading View Size

Use `visualEffect { content, proxy in }` to read the view's size without affecting layout:

```swift
myView
    .visualEffect { content, proxy in
        content.colorEffect(
            ShaderLibrary.myShader(
                .float2(proxy.size)   // pass size as float2
            )
        )
    }
```

## Animation with TimelineView

```swift
TimelineView(.animation) { context in
    let elapsed = startDate.distance(to: context.date)
    myView.colorEffect(
        ShaderLibrary.myShader(.float(Float(elapsed)))
    )
}
```

On ProMotion displays this drives the shader at up to 120 Hz. Cost is zero when the TimelineView is off-screen.

## Shader Compilation Warming (iOS 18+)

Pre-compile shaders to avoid first-frame stutter:

```swift
.task {
    let shader = ShaderLibrary.myEffect(.float2(.zero), .float(0))
    try? await shader.compile(as: .colorEffect)  // or .distortionEffect, .layerEffect
}
```

Pass the same argument **types** you will use at draw time. The cache key is function name + argument type signature (not values). Changing argument values every frame is cheap; changing argument types triggers a recompile.

## Render Pass Optimization

- Sequential `.colorEffect`s on the same view fold into a **single render pass**.
- A `.colorEffect` before a `.distortionEffect` also folds into one pass.
- Every `.layerEffect` and every `.distortionEffect` after the first one introduces a **new render pass**.
- **Reorder shaders to put `.colorEffect`s first** when possible.

## maxSampleOffset

`maxSampleOffset` on `.distortionEffect` and `.layerEffect` is **not optional advisory metadata** — it expands the rasterized region SwiftUI prepares. If your shader samples beyond `maxSampleOffset` from the destination pixel, the result is **clipped to transparent** (the classic "shader cut off at edges" bug).

The common fix pattern:

```swift
myView
    .padding(40)                  // expand layout to make room
    .drawingGroup()               // rasterize before the effect
    .distortionEffect(
        ShaderLibrary.ripple(...),
        maxSampleOffset: CGSize(width: 40, height: 40)
    )
```

## Known Bugs and Silent Failures

1. **Argument type mismatch** — compiles fine, renders garbage. Always verify argument order and types match the MSL signature exactly.

2. **Too many arguments** — no published hard limit, but shaders may fail silently when many parameters are passed. Keep argument lists short (≤ 8 scalars). Pack vectors when possible.

3. **UIKit-backed views don't render into layerEffect** — Apple's docs state: "Views backed by AppKit or UIKit views may not render into the filtered layer." Workaround: apply `.drawingGroup()` before the effect, or apply the effect to a pure SwiftUI view layered above.

4. **Second `.image()` breaks layer sampling** — passing a second `.image()` to a `layerEffect` either fails silently or corrupts `SwiftUI::Layer.sample()` (the Layer appears to occupy the single texture slot internally).

5. **Core Image + SwiftUI shader conflict** — if the same target has both `[[stitchable]]` SwiftUI shaders and `extern "C"` Core Image custom kernels, Xcode's `-fcikernel` build rule applies to all `.metal` files. Solution: put CI kernels in a separate target.

6. **No runtime `MTLLibrary` → `ShaderLibrary` bridge** — `ShaderLibrary(data:)` accepts metallib Data from disk but is undocumented for runtime-compiled shaders. For dynamic shader generation, use MTKView.

7. **No backdrop sampling** — there is no API to sample what's behind a view. For Material-like backdrop blur, apply the effect to a common ancestor containing both background and foreground.

## When to Drop to MTKView

Use SwiftUI shaders for ~95% of UI effects. Drop to MTKView (via `UIViewRepresentable`) when you need:
- ≥ 2 texture inputs
- Compute kernels
- Offscreen render targets / bake-to-texture
- `MTLFunctionConstantValues` for shader specialization
- Arbitrary numbers of inputs or full pipeline control

See the `metal-motion-effects` skill for the MTKView wrapper pattern.
