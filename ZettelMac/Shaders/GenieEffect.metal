//
//  GenieEffect.metal
//  ZettelMac
//
//  Horizontal genie / "suck" effect for note transitions.
//  Collapses (or expands) a SwiftUI layer toward a target point
//  using a per-column vertical squeeze, creating a funnel shape
//  that sweeps horizontally — ideal for sidebar-to-editor transitions.
//
//  Forward  (progress 0 → 1): layer collapses into the target (genie-out).
//  Reverse  (progress 1 → 0): layer expands from the target (genie-in).
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Horizontal genie effect: progressively squeezes a layer into a funnel
/// converging on `targetPos` along the X axis. Columns closest to the
/// target collapse first; each column squeezes vertically toward `target.y`.
///
/// Parameters after the mandatory (position, layer):
///   size       – layer dimensions in points (float2)
///   targetPos  – collapse target in layer-local coordinates (float2).
///                May be outside [0, size] when the target is in the sidebar.
///   progress   – animation progress 0 (identity) → 1 (fully collapsed)
[[ stitchable ]] half4 genieEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float2 targetPos,
    float progress
) {
    // Fast paths
    if (progress <= 0.0) return layer.sample(position);
    if (progress > 0.999) return half4(0.0);

    float2 uv     = position / size;
    float2 target  = targetPos / size;
    float  p       = progress;

    // ── Per-column collapse amount ──────────────────────────────
    // Distance from this column to the target's X, normalised 0-1.
    float xDist    = abs(uv.x - target.x);
    float maxXDist = max(abs(target.x), abs(1.0 - target.x));
    float normXDist = saturate(xDist / max(maxXDist, 0.001));

    // localP ramps from 0 → 1 per column.  Columns near the target
    // reach 1 sooner; far columns lag behind.  The coefficients
    // (1.5 / 0.5) keep the Jacobian monotonic everywhere
    // so no scan-line folding artefacts appear.
    float localP = smoothstep(0.0, 1.0, p * 1.5 - normXDist * 0.5);

    if (localP >= 0.998) return half4(0.0);

    // ── Vertical squeeze ────────────────────────────────────────
    // Centre slides toward target.y; half-height shrinks with a
    // subtle power curve to widen the funnel mouth a little.
    float centerY   = mix(0.5, target.y, localP);
    float halfHeight = 0.5 * pow(1.0 - localP, 2.2);

    if (halfHeight < 0.001) return half4(0.0);

    float sourceY = 0.5 + (uv.y - centerY) / (halfHeight * 2.0);

    // ── Horizontal inverse mapping ──────────────────────────────
    // Forward: out_x = mix(src_x, target.x, localP)
    // Inverse: src_x = (out_x – target.x·localP) / (1 – localP)
    float denom   = 1.0 - localP;
    float sourceX = (uv.x - target.x * localP) / denom;

    // Bounds check (small epsilon for float precision)
    if (sourceX < -0.001 || sourceX > 1.001 ||
        sourceY < -0.001 || sourceY > 1.001) {
        return half4(0.0);
    }
    sourceX = saturate(sourceX);
    sourceY = saturate(sourceY);

    // ── Sample & fade ───────────────────────────────────────────
    half4 color = layer.sample(float2(sourceX, sourceY) * size);

    // Smooth fade prevents wisps from popping.
    // Works in both directions: fades out near p=1, fades in near p=0.
    half fade = half(1.0 - smoothstep(0.4, 0.95, p));
    color *= fade;

    return color;
}
