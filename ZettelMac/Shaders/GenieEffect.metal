//
//  GenieEffect.metal
//  ZettelMac
//
//  Genie / "suck" effect for the new-note card transition.
//  Collapses a SwiftUI layer toward a target point, mimicking
//  the macOS minimize-to-Dock genie animation.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Genie / suck effect: progressively squeezes a layer into a funnel
/// shape converging on `targetPos`. Rows closest to the target
/// collapse first, creating the characteristic genie silhouette.
///
/// Parameters after the mandatory (position, layer):
///   size       – layer dimensions in points (float2)
///   targetPos  – collapse target in layer-local coordinates (float2)
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
    if (progress >= 1.0) return half4(0.0);

    float2 uv     = position / size;
    float2 target  = targetPos / size;
    float  p       = progress;

    // ── Per-row collapse amount ──────────────────────────────────
    // Distance from this row to the target's Y, normalised 0-1.
    float yDist    = abs(uv.y - target.y);
    float maxYDist = max(abs(target.y), abs(1.0 - target.y));
    float normYDist = saturate(yDist / max(maxYDist, 0.001));

    // localP ramps from 0 → 1 per row.  Rows near the target
    // reach 1 sooner; far rows lag behind.  The coefficients
    // (1.5 / 0.5) keep the Jacobian monotonic everywhere
    // so no scan-line folding artefacts appear.
    float localP = smoothstep(0.0, 1.0, p * 1.5 - normYDist * 0.5);

    if (localP >= 0.998) return half4(0.0);

    // ── Horizontal squeeze ──────────────────────────────────────
    // Centre slides toward target.x; half-width shrinks with a
    // subtle power curve to widen the funnel mouth a little.
    float centerX  = mix(0.5, target.x, localP);
    float halfWidth = 0.5 * pow(1.0 - localP, 2.2);

    if (halfWidth < 0.001) return half4(0.0);

    float sourceX = 0.5 + (uv.x - centerX) / (halfWidth * 2.0);

    // ── Vertical inverse mapping ────────────────────────────────
    // Forward: out_y = mix(src_y, target.y, localP)
    // Inverse: src_y = (out_y – target.y·localP) / (1 – localP)
    float denom  = 1.0 - localP;
    float sourceY = (uv.y - target.y * localP) / denom;

    // Bounds check (small epsilon for float precision)
    if (sourceX < -0.001 || sourceX > 1.001 ||
        sourceY < -0.001 || sourceY > 1.001) {
        return half4(0.0);
    }
    sourceX = saturate(sourceX);
    sourceY = saturate(sourceY);

    // ── Sample & fade ───────────────────────────────────────────
    half4 color = layer.sample(float2(sourceX, sourceY) * size);

    // Smooth fade so the last wisp doesn't pop out
    half fade = half(1.0 - smoothstep(0.35, 0.92, p));
    color *= fade;

    return color;
}
