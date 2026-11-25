shader_type spatial;
render_mode unshaded, cull_back;
// Old green-phosphor CRT: curved vignette, scanlines, a slow rolling bar,
// faint noise and flicker. Emissive (unshaded) so it glows in the dark.

uniform vec3 phosphor : source_color = vec3(0.18, 0.9, 0.35);
uniform float brightness = 0.55;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float vig = 1.0 - smoothstep(0.55, 1.15, length(uv * vec2(0.9, 1.1)));
	float scan = 0.72 + 0.28 * sin(UV.y * 260.0);
	float roll = 0.85 + 0.15 * smoothstep(0.0, 0.08, abs(fract(UV.y * 0.6 - TIME * 0.11 + seed) - 0.5));
	float noise = hash(UV * 480.0 + fract(TIME * 13.0 + seed)) * 0.12;
	float flick = 0.96 + 0.04 * sin(TIME * 59.0 + seed * 10.0);
	vec3 c = phosphor * brightness * (0.35 + noise) * scan * roll * flick * vig;
	ALBEDO = c;
	EMISSION = c * 1.6;
}
