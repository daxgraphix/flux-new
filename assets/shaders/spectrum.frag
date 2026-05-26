#version 460 core

uniform float uWidth;
uniform float uHeight;
uniform float uCurrentFreq;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(uWidth, uHeight);

    // Frequency from 0 to 1 (87.5 to 108)
    float freq = uv.x;

    // Simulate signal strength with peaks
    float strength = sin(freq * 20.0) * 0.3 + 0.4;
    strength += sin(freq * 40.0) * 0.1;

    // Heatmap color
    vec3 color = vec3(strength, 0.5, 1.0 - strength);

    // Highlight current frequency
    if (abs(freq - (uCurrentFreq - 87.5) / 20.5) < 0.01) {
        color = vec3(1.0, 0.0, 0.0);
    }

    fragColor = vec4(color, 1.0);
}