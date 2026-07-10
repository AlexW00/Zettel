---
name: msl-techniques
description: Metal Shading Language (MSL) techniques for 2D visual effects on iOS. Use this skill whenever writing or debugging MSL shader code for UI effects, procedural noise (Perlin, Simplex, Worley, fBm), signed distance fields (SDF shapes, antialiasing, boolean ops), hash functions for deterministic randomness, GLSL-to-MSL porting, or half vs float precision decisions. Also trigger when the user asks about fwidth, smoothstep for antialiasing, SDF text rendering, MSDF atlases, or procedural texture generation in Metal. This covers the non-obvious MSL knowledge that trips up engineers who know Swift but not GPU shading.
---

# MSL Techniques for 2D Visual Effects

This skill covers Metal Shading Language patterns for UI-quality 2D effects: precision rules, procedural noise, signed distance fields, hash functions, and GLSL porting. All code is MSL (Metal Shading Language) targeting iOS.

## Precision: half vs float

`half` (16-bit float) is the default choice for colors, texture reads, and interpolates. `float` (32-bit) is for positions and accumulators.

**Why it matters:** On Apple GPUs (A8+), `half` halves register pressure and bandwidth. Conversions between half and float are free (hardware-accelerated, zero cost). Using `float` everywhere doubles energy and register use for no visual benefit in color math.

**Rules:**
- Use `half` / `half4` for colors, texture samples, intermediate color math, shader output.
- Use `float` / `float2` for positions, UV coordinates, distance calculations, accumulators.
- **Literal suffix matters:** `someHalf * 1.0` promotes to float. Write `someHalf * 1.0h` to stay in half.
- `half` max is 65504. The value 65535 becomes `+inf` in half. Precision near 1.0 is ~10⁻³.
- Fast-math (on by default) enables FMA formation and built-in approximations. Keep it on unless you need bit-exact reproducibility.

## GLSL → MSL Porting Cheat Sheet

| GLSL | MSL |
|------|-----|
| `vec2/3/4` | `float2/3/4` (or `half2/3/4`) |
| `mat3` | `float3x3` (column-major in both) |
| `texture2D(tex, uv)` | `tex.sample(sampler, uv)` |
| `gl_FragCoord.xy` | `float2 position` (first param of `[[stitchable]]`) |
| `mix(a, b, t)` | `mix(a, b, t)` (same) |
| `mod(x, y)` | `fmod(x, y)` — **careful:** differs for negatives. GLSL `mod` = `x - y * floor(x/y)`. MSL `fmod` = `x - y * trunc(x/y)`. |
| `dFdx` / `dFdy` | `dfdx` / `dfdy` (lowercase) |
| `fwidth(x)` | `fwidth(x)` (same — `abs(dfdx(x)) + abs(dfdy(x))`) |
| `#extension GL_OES_standard_derivatives` | Not needed — derivatives always available in MSL fragments |
| `atan(y, x)` | `atan2(y, x)` (C convention) |

## Useful MSL Built-ins for Effects

- `smoothstep(edge0, edge1, x)` — Hermite interpolation. Foundation of SDF antialiasing.
- `mix(a, b, t)` / `clamp(x, lo, hi)` / `step(edge, x)` / `sign(x)`
- `fract(x)` / `floor(x)` / `round(x)` — tiling, pixelation
- `length(v)` / `distance(a, b)` / `normalize(v)` / `dot(a, b)`
- `atan2(y, x)` — polar coordinates
- `fwidth(x)` — screen-space derivative magnitude; essential for resolution-independent AA
- `reflect` / `refract` / `pow` / `exp` / `log` / `sin` / `cos` — trig is fast-math optimized

## Texture Sampling

Declare a constexpr sampler in MSL:
```cpp
constexpr sampler s(
    coord::normalized,          // UVs in [0,1]
    address::clamp_to_edge,     // or repeat, clamp_to_zero, mirrored_repeat
    filter::linear,             // or nearest
    mip_filter::linear
);
half4 color = tex.sample(s, uv);
```

Common choices for UI shaders:
- `address::clamp_to_zero` — outside is transparent (layer-style)
- `address::repeat` — tiled textures / noise lookups
- `filter::nearest` — pixel-art / pixelation effects

**Color space:** `bgra8Unorm_srgb` and `rgba8Unorm_srgb` pixel formats auto-decode sRGB on read and re-encode on write (hardware-accelerated, free). `bgra8Unorm` gives raw bytes — you must convert manually if data is sRGB.

---

## Hash Functions for Deterministic Randomness

**Do NOT use** `fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453)`. This widely copy-pasted hash has visible banding, hash collisions at large coordinates, and becomes unstable under fast-math rewrites.

### Recommended: pcg3d

From Jarzynski & Olano, "Hash Functions for GPU Rendering," JCGT 2020. High quality, fast, no trig:

```cpp
uint3 pcg3d(uint3 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v ^= v >> 16u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

// Usage: deterministic float3 in [0,1] from a uint3 seed
float3 hash3(uint3 seed) {
    return float3(pcg3d(seed)) / float(0xFFFFFFFFu);
}
```

### 1D Wang hash

For simple 1D seed → float:
```cpp
uint wangHash(uint s) {
    s = (s ^ 61u) ^ (s >> 16u);
    s *= 9u;
    s = s ^ (s >> 4u);
    s *= 0x27d4eb2du;
    s = s ^ (s >> 15u);
    return s;
}
float hash01(uint s) { return float(wangHash(s)) / float(0xFFFFFFFFu); }
```

Feed `(userSeed, pixelIndex)` to get per-user, per-pixel deterministic randomness.

---

## Procedural Noise

### Simplex / Perlin

Port Stefan Gustavson's webgl-noise (github.com/stegu/webgl-noise) — canonical, purely computational, no lookup textures. Porting requires only `vec→float` renames and `mod` → `fmod` attention (see porting table).

Alternative: JoshuaSullivan/SimplexNoiseFilter provides a ready-made MSL Simplex wrapped as a Core Image filter.

Simplex noise output range is approximately [-1, 1] (slightly exceeds in some implementations — clamp before mapping to [0,1]).

### fBm (Fractal Brownian Motion)

Summed octaves at increasing frequency / decreasing amplitude:

```cpp
float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; ++i) {
        value += amplitude * snoise(p);   // snoise = your Simplex impl
        p *= 2.02;    // 2.02 not 2.0 — breaks visible grid alignment
        amplitude *= 0.5;
    }
    return value;
}
```

4–6 octaves is typical. Performance: a 2D Simplex call costs tens of ALU ops; fBm with 5 octaves is ~5× that. Comfortable at 60 Hz for UI-sized regions (a few hundred thousand pixels).

### Worley / Cellular Noise

More expensive than Simplex (~2–3× cost) due to the 3×3 cell neighborhood scan. Produces organic cell patterns, fiber textures, voronoi cracks. Port Matt Rix's HLSL gist or Gustavson's GLSL `cellular` function.

---

## 2D Signed Distance Fields (SDF)

SDF primitives return the signed distance from a point to a shape's boundary: negative inside, positive outside, zero on the edge.

### Core Primitives

Port directly from iquilezles.org/articles/distfunctions2d — `vec2→float2`, all math functions are identical:

```cpp
float sdCircle(float2 p, float r) {
    return length(p) - r;
}

float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdRoundedBox(float2 p, float2 b, float r) {
    return sdBox(p, b - r) - r;
}

float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}
```

### Boolean Operations

```cpp
float opUnion(float d1, float d2)        { return min(d1, d2); }
float opIntersect(float d1, float d2)    { return max(d1, d2); }
float opSubtract(float d1, float d2)     { return max(d1, -d2); }
float opAnnular(float d, float r)        { return abs(d) - r; }     // ring / outline
float opRound(float d, float r)          { return d - r; }          // round corners

// Smooth union (soft blend between shapes)
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
```

### Antialiasing — Resolution-Independent Recipe

```cpp
float d = sdCircle(uv - center, radius);
float w = fwidth(d);                            // screen-space pixel footprint of d
half alpha = half(smoothstep(w, -w, d));         // 1 inside, 0 outside, smooth at edge
```

This works at any zoom because `fwidth` measures the actual on-screen derivative. For very thin shapes, clamp `w` to a minimum (~1.5 pixels) to prevent the shape from disintegrating at small sizes.

### SDF Text Rendering with MSDF

Multi-channel SDF atlases (via Chlumsky/msdfgen or msdf-atlas-gen) give crisp text edges at all scales:

```cpp
float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}
// In fragment shader:
half3 s = tex.sample(sampler, uv).rgb;
float sigDist = median(float(s.r), float(s.g), float(s.b));
float w = fwidth(sigDist);
float opacity = smoothstep(0.5 - w, 0.5 + w, sigDist);
```

**MSDF caveats:** Mark the texture as Data (not sRGB), disable mipmaps, keep `pxrange` consistent between bake-time and shader runtime.

---

## Emboss / Height-Map Lighting in 2D

Sample neighbors and compute a pseudo-normal for directional lighting:

```cpp
// In a layerEffect shader
half4 center = layer.sample(pos);
half4 right  = layer.sample(pos + float2(1, 0));
half4 below  = layer.sample(pos + float2(0, 1));
float dx = dot(float4(right - center), float4(1));
float dy = dot(float4(below - center), float4(1));
float3 normal = normalize(float3(-dx, -dy, 0.5));
float3 lightDir = normalize(float3(-1, -1, 1));
float lighting = max(0.0, dot(normal, lightDir));
```

For a tilt-reactive emboss, drive `lightDir` from CMDeviceMotion roll/pitch (see the `metal-motion-effects` skill).

## Open-Source References

- **twostraws/Inferno** (MIT) — canonical SwiftUI shader collection with heavily commented `.metal` files. Copy individual shaders as starting points.
- **iquilezles.org/articles/distfunctions2d** — primary source for 2D SDF primitives, smooth minimum, and annular operators.
- **stegu/webgl-noise** — Gustavson's canonical GLSL noise implementations (Simplex, cellular). Port to MSL.
- **JoshuaSullivan/SimplexNoiseFilter** — ready-made MSL Simplex + fBm wrapped as a CIFilter.
- **MetalPetal** — production-grade Metal filter chain with explicit sRGB↔linear conversion utilities.
- **Jarzynski & Olano, JCGT 2020** — "Hash Functions for GPU Rendering." The pcg3d hash used above.
