#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3 - 2 * f);
    return mix(mix(hash(i), hash(i + float2(1, 0)), u.x),
               mix(hash(i + float2(0, 1)), hash(i + float2(1, 1)), u.x), u.y);
}

static float positiveMod(float x, float m) {
    return x - m * floor(x / m);
}

/// Painted hardboard with round holes, lit from above: each hole's upper wall is in shadow, its lower wall
/// and lip catch the light, and the paint is never quite even. A fill, so it's drawn straight into the layer.
/// The board is drawn in tiles, each starting `top` points down the board.
[[stitchable]] half4 pegboard(float2 position, float width, float top) {
    float2 size = float2(width, 0);
    float s = width / 376;
    float2 p = float2(position.x, position.y + top);

    float blotches = 0.6 * valueNoise(p / (80 * s)) + 0.4 * valueNoise(p / (23 * s));
    float grain = hash(floor(p * 3));
    float paint = 0.84 + (blotches - 0.5) * 0.06 + (grain - 0.5) * 0.035;
    float3 rgb = paint * float3(1, 0.985, 0.955);

    // Holes line up on either side of the middle, where the two panels meet.
    float pitch = 22 * s;
    float radius = 2.6 * s;
    float2 local = float2(positiveMod(p.x - size.x / 2, pitch), positiveMod(p.y, pitch)) - pitch / 2;
    float distance = length(local) - radius;
    float2 normal = local / max(length(local), 0.001);

    // The lower lip catches the light; the paint above the hole falls into its shadow.
    float lip = 1 - smoothstep(0, 1.8 * s, distance);
    rgb += lip * max(normal.y, 0.0) * 0.22;
    rgb -= lip * max(-normal.y, 0.0) * 0.14;
    rgb *= 1 - 0.1 * (1 - smoothstep(0, 5 * s, distance));

    float depth = smoothstep(-0.3, 1.0, local.y / radius);
    float3 hole = float3(mix(0.03, 0.3, depth * depth));
    rgb = mix(rgb, hole, 1 - smoothstep(-0.35, 0.35, distance));

    float seam = abs(p.x - size.x / 2);
    rgb *= 1 - 0.2 * (1 - smoothstep(0.3 * s, 0.9 * s, seam));
    rgb += 0.06 * (1 - smoothstep(0.2 * s, 0.6 * s, abs(seam - 1.3 * s)));

    return half4(half3(rgb), 1);
}

/// Fine horizontal brushing for the shelves' metal edge, laid over its shading.
[[stitchable]] half4 brushedMetal(float2 position, float scale) {
    float streaks = 0.6 * valueNoise(float2(position.x * 0.012, position.y * 2.2) / scale)
                  + 0.4 * hash(float2(floor(position.x * 0.25), floor(position.y * 3)));
    float shade = (streaks - 0.5) * 0.14;
    // Premultiplied: white where the brushing is lighter, black where it's darker.
    return shade > 0 ? half4(half3(shade), half(shade)) : half4(0, 0, 0, half(-shade));
}
