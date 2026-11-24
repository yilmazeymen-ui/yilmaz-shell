#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 screenSize;
    vec4 leftRect;    // centerX, centerY, halfW, halfH
    vec4 centerRect;  // centerX, centerY, halfW, halfH
    vec4 rightRect;   // centerX, centerY, halfW, halfH
    vec4 params;      // smoothK, innerAlpha, impactGlow, unused
    vec4 glassTintColor;
    vec4 pureGlassColor;
    vec4 highlightTint;
};

layout(binding = 1) uniform sampler2D wallpaperTex;

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Polynomial smooth minimum for organic liquid-glass coalescence
float smin(float a, float b, float k) {
    if (k <= 0.001)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sceneSDF(vec2 p) {
    float k = params.x;
    float dL = sdRoundedBox(p - leftRect.xy, leftRect.zw, min(leftRect.z, leftRect.w));
    float dC = sdRoundedBox(p - centerRect.xy, centerRect.zw, min(centerRect.z, centerRect.w));
    float dR = sdRoundedBox(p - rightRect.xy, rightRect.zw, min(rightRect.z, rightRect.w));
    return smin(smin(dL, dC, k), dR, k);
}

vec2 calcNormal(vec2 p) {
    const float eps = 0.75;
    float dx = sceneSDF(p + vec2(eps, 0.0)) - sceneSDF(p - vec2(eps, 0.0));
    float dy = sceneSDF(p + vec2(0.0, eps)) - sceneSDF(p - vec2(0.0, eps));
    return normalize(vec2(dx, dy) + vec2(1e-5));
}

void main() {
    vec2 pixelPos = qt_TexCoord0 * itemSize;
    float d = sceneSDF(pixelPos);

    float mask = 1.0 - smoothstep(-0.75, 0.75, d);
    if (mask <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 normal = calcNormal(pixelPos);
    float edgeDist = max(-d, 0.0);
    float rim = exp(-edgeDist * 0.11);

    vec2 baseUv = pixelPos / screenSize;
    float impact = params.z;

    // Optical refraction + slight extra curvature during liquid impact
    vec2 refractOffset = -normal * rim * ((26.0 + 10.0 * impact) / screenSize);
    vec2 disp = normal * rim * ((4.0 + 2.0 * impact) / screenSize);

    vec3 colR = texture(wallpaperTex, clamp(baseUv + refractOffset + disp, 0.001, 0.999)).rgb;
    vec3 colG = texture(wallpaperTex, clamp(baseUv + refractOffset, 0.001, 0.999)).rgb;
    vec3 colB = texture(wallpaperTex, clamp(baseUv + refractOffset - disp, 0.001, 0.999)).rgb;
    vec3 refracted = vec3(colR.r, colG.g, colB.b);

    vec2 b1 = 4.5 / screenSize;
    vec2 b2 = 8.5 / screenSize;
    vec3 blurred = (
        refracted +
        texture(wallpaperTex, clamp(baseUv + refractOffset + vec2(b1.x, 0.0), 0.001, 0.999)).rgb +
        texture(wallpaperTex, clamp(baseUv + refractOffset - vec2(b1.x, 0.0), 0.001, 0.999)).rgb +
        texture(wallpaperTex, clamp(baseUv + refractOffset + vec2(0.0, b1.y), 0.001, 0.999)).rgb +
        texture(wallpaperTex, clamp(baseUv + refractOffset - vec2(0.0, b1.y), 0.001, 0.999)).rgb +
        texture(wallpaperTex, clamp(baseUv + refractOffset + vec2(b2.x, b2.y), 0.001, 0.999)).rgb +
        texture(wallpaperTex, clamp(baseUv + refractOffset + vec2(-b2.x, b2.y), 0.001, 0.999)).rgb +
        texture(wallpaperTex, clamp(baseUv + refractOffset + vec2(b2.x, -b2.y), 0.001, 0.999)).rgb +
        texture(wallpaperTex, clamp(baseUv + refractOffset + vec2(-b2.x, -b2.y), 0.001, 0.999)).rgb
    ) / 9.0;

    vec3 glassSample = mix(blurred, refracted, rim * 0.40);
    vec3 glassTint = glassTintColor.rgb;
    vec3 baseColor = mix(glassSample, glassTint, 0.28 + impact * 0.08);

    float topSheen = exp(-max(pixelPos.y - 8.0, 0.0) * 0.065) * 0.10;
    baseColor += mix(vec3(1.0), highlightTint.rgb, 0.85) * topSheen;

    float rimLine = exp(-edgeDist * 0.78);
    float topLight = clamp(dot(normal, normalize(vec2(-0.35, -1.0))), 0.0, 1.0);
    float bottomBounce = clamp(dot(normal, normalize(vec2(0.35, 1.0))), 0.0, 1.0);
    float fresnel = rimLine * (0.18 + 0.52 * pow(topLight, 1.35) + 0.20 * pow(bottomBounce, 2.0) + 0.22 * impact);

    vec3 finalRgb = baseColor + highlightTint.rgb * fresnel;
    float finalAlpha = clamp(params.y + rimLine * 0.24, 0.0, 1.0) * mask * qt_Opacity;
    fragColor = vec4(finalRgb * finalAlpha, finalAlpha);
}
