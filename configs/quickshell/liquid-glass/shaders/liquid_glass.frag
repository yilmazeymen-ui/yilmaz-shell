#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 itemPos;
    vec2 screenSize;
    float cornerRadius;
    float hoverAmount;
    float innerAlpha;
    float wallpaperMix;
    vec4 glassTintColor;
    vec4 pureGlassColor;
    vec4 highlightTint;
};

layout(binding = 1) uniform sampler2D wallpaperTex;

// Signed distance to a rounded box centered at origin
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Analytical-style gradient of the rounded box SDF for smooth edge normals
vec2 calcNormal(vec2 p, vec2 b, float r) {
    const float eps = 0.75;
    float dx = sdRoundedBox(p + vec2(eps, 0.0), b, r) - sdRoundedBox(p - vec2(eps, 0.0), b, r);
    float dy = sdRoundedBox(p + vec2(0.0, eps), b, r) - sdRoundedBox(p - vec2(0.0, eps), b, r);
    return normalize(vec2(dx, dy) + vec2(1e-5));
}

void main() {
    vec2 pixelPos = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;
    vec2 p = pixelPos - halfSize;
    float r = min(cornerRadius, min(halfSize.x, halfSize.y));

    float d = sdRoundedBox(p, halfSize, r);
    // Razor-sharp 1px anti-aliased edge
    float mask = 1.0 - smoothstep(-0.75, 0.75, d);
    if (mask <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 normal = calcNormal(p, halfSize, r);

    // Distance from edge (0 at border, grows inward)
    float edgeDist = max(-d, 0.0);
    // Optical lens curvature concentrated near the rounded rim (0..22px)
    float rim = exp(-edgeDist * 0.11);

    // Screen-space UV of this pixel on the wallpaper
    vec2 baseUv = (itemPos + pixelPos) / screenSize;

    // Refraction bends background outward/inward along the curved glass normal
    vec2 refractOffset = -normal * rim * (26.0 / screenSize);
    vec2 disp = normal * rim * (4.0 / screenSize);

    // Chromatic dispersion at the curved rim + 9-tap frosted diffusion
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

    // Keep chromatic rim dispersion crisp while diffusing the interior
    vec3 glassSample = mix(blurred, refracted, rim * 0.40);

    // Clear glass tint driven by active wallpaper theme
    vec3 glassTint = glassTintColor.rgb;
    vec3 refractedGlass = mix(glassSample, glassTint, 0.28 + hoverAmount * 0.06);
    vec3 pureGlass = mix(pureGlassColor.rgb, glassTint, 0.65);
    vec3 baseColor = mix(pureGlass, refractedGlass, wallpaperMix);

    // Subtle top-to-bottom internal sheen (pixel-space so bar & tall menus match)
    float topSheen = exp(-pixelPos.y * 0.065) * 0.10;
    baseColor += mix(vec3(1.0), highlightTint.rgb, 0.85) * topSheen;

    // Organic curved Fresnel rim highlight (overhead light from top-left + soft bottom bounce)
    float rimLine = exp(-edgeDist * 0.78);
    float topLight = clamp(dot(normal, normalize(vec2(-0.35, -1.0))), 0.0, 1.0);
    float bottomBounce = clamp(dot(normal, normalize(vec2(0.35, 1.0))), 0.0, 1.0);
    float fresnel = rimLine * (0.18 + 0.52 * pow(topLight, 1.35) + 0.20 * pow(bottomBounce, 2.0) + 0.16 * hoverAmount) * mix(0.35, 1.0, wallpaperMix);

    vec3 highlightColor = highlightTint.rgb;
    vec3 finalRgb = baseColor + highlightColor * fresnel;

    // Alpha stays above Hyprland's ignore_alpha=0.28 inside, and softly brightens at the rim
    float finalAlpha = clamp(innerAlpha + rimLine * 0.24, 0.0, 1.0) * mask * qt_Opacity;
    fragColor = vec4(finalRgb * finalAlpha, finalAlpha);
}
