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
/// and lip catch the light, and the paint is never quite even. `offset` moves the board with the shelves.
[[stitchable]] half4 pegboard(float2 position, half4 color, float2 size, float offset) {
    float s = size.x / 390;
    float2 p = float2(position.x, position.y - offset);

    float blotches = 0.6 * valueNoise(p / (80 * s)) + 0.4 * valueNoise(p / (23 * s));
    float grain = hash(floor(position * 3));
    float paint = 0.845 + (blotches - 0.5) * 0.05 + (grain - 0.5) * 0.03;
    float3 rgb = paint * float3(1, 0.99, 0.962);

    // Holes line up on either side of the middle, where the two panels meet.
    float pitch = 22 * s;
    float radius = 2.7 * s;
    float2 local = float2(positiveMod(p.x - size.x / 2, pitch), positiveMod(p.y, pitch)) - pitch / 2;
    float distance = length(local) - radius;
    float2 normal = local / max(length(local), 0.001);

    float lip = 1 - smoothstep(0, 1.3 * s, distance);
    rgb += lip * normal.y * 0.09;
    rgb *= 1 - 0.07 * (1 - smoothstep(0, 3.5 * s, distance));

    float depth = smoothstep(-0.3, 1.0, local.y / radius);
    float3 hole = float3(mix(0.05, 0.24, depth));
    rgb = mix(rgb, hole, 1 - smoothstep(-0.35, 0.35, distance));

    float seam = abs(position.x - size.x / 2);
    rgb *= 1 - 0.16 * (1 - smoothstep(0.3 * s, 0.9 * s, seam));
    rgb += 0.05 * (1 - smoothstep(0.2 * s, 0.6 * s, abs(seam - 1.3 * s)));

    return half4(half3(rgb), 1);
}

/// The window-shaped reflection on a case's clear plastic. It's fixed in the room, so it slides across
/// the case as the case moves: `y` is the case's top edge on screen.
[[stitchable]] half4 caseGlare(float2 position, half4 color, float2 size, float y) {
    float2 uv = position / size;
    float along = uv.y + 0.55 * uv.x + 0.04 * sin(uv.x * 5);
    float center = 1.3 - y * 0.0011;
    float band = 0.2 * exp(-pow((along - center) / 0.15, 2));
    float streak = 0.13 * exp(-pow((along - center - 0.23) / 0.022, 2));
    float sheen = 0.07 * (1 - smoothstep(0, 0.1, uv.y));
    half glare = half(band + streak + sheen);
    // Screen the light over the premultiplied color.
    return half4(color.rgb + (color.a - color.rgb) * glare, color.a);
}

/// Fine horizontal brushing on the shelves' metal edge.
[[stitchable]] half4 brushedMetal(float2 position, half4 color, float scale) {
    float streaks = 0.6 * valueNoise(float2(position.x * 0.012, position.y * 2.2) / scale)
                  + 0.4 * hash(float2(floor(position.x * 0.25), floor(position.y * 3)));
    return half4(color.rgb * half(1 + (streaks - 0.5) * 0.07), color.a);
}
