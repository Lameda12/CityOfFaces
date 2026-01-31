// Sanity Glitch Shader for "The Escape from Veritas"
// Creates chromatic aberration and wave/wobble effects based on intensity

extern float intensity;   // 0.0 to 1.0 (sanity / 100)
extern float time;        // For animated effects

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;
    
    // Wave/Wobble effect - distorts UV coordinates
    // Intensity controls amplitude, time controls animation
    float waveStrength = intensity * 0.015;
    float waveFreq = 10.0;
    float waveSpeed = 3.0;
    
    // Horizontal wave
    uv.x += sin(uv.y * waveFreq + time * waveSpeed) * waveStrength;
    // Vertical wave (smaller)
    uv.y += cos(uv.x * waveFreq * 0.8 + time * waveSpeed * 1.2) * waveStrength * 0.5;
    
    // Chromatic Aberration - split RGB channels
    // Higher intensity = more separation
    float aberrationStrength = intensity * 0.008;
    
    // Add some randomness based on time for glitchy feel
    float glitchOffset = sin(time * 20.0) * intensity * 0.002;
    
    // Sample each color channel at slightly different positions
    float r = Texel(texture, vec2(uv.x + aberrationStrength + glitchOffset, uv.y)).r;
    float g = Texel(texture, uv).g;
    float b = Texel(texture, vec2(uv.x - aberrationStrength - glitchOffset, uv.y)).b;
    
    // Combine channels
    vec4 finalColor = vec4(r, g, b, 1.0);
    
    // Add some noise/grain at high intensity
    if (intensity > 0.5) {
        float noise = fract(sin(dot(screen_coords, vec2(12.9898, 78.233)) + time) * 43758.5453);
        float noiseStrength = (intensity - 0.5) * 0.1;
        finalColor.rgb += (noise - 0.5) * noiseStrength;
    }
    
    // Slight vignette darkening at edges when intensity is high
    if (intensity > 0.3) {
        vec2 center = vec2(0.5, 0.5);
        float dist = distance(texture_coords, center);
        float vignette = 1.0 - (dist * intensity * 0.5);
        finalColor.rgb *= vignette;
    }
    
    return finalColor * color;
}
