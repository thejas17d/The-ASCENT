shader_type canvas_item;
// Cinematic post-process: film grain, vignette, dread-driven chromatic
// aberration + red edge pulse, and VHS line tearing during violations.
// All effects are subtle by default and scaled by Settings (grain, reduced flashing).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.045;
uniform float vignette = 0.55;
uniform float dread = 0.0;        // 0..1
uniform float aberration = 0.0;   // pixels at screen edge
uniform float tear = 0.0;         // 0..1 VHS tearing
uniform float pulse_speed = 1.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (tear > 0.0) {
		float band = floor(uv.y * 180.0);
		float t = floor(TIME * 24.0);
		float on = step(0.82, hash(vec2(band * 0.37, t)));
		uv.x += (hash(vec2(band, t)) - 0.5) * 0.03 * tear * on;
		uv.y += (hash(vec2(t, 3.1)) - 0.5) * 0.004 * tear;
	}
	vec2 d = uv - 0.5;
	float r = length(d);
	vec2 ca = d * aberration * SCREEN_PIXEL_SIZE * 2.0 * r;
	vec3 col;
	col.r = texture(screen_tex, uv + ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - ca).b;
	// vignette tightens as dread rises
	float vig = 1.0 - smoothstep(0.25 - dread * 0.1, 0.85, r * (1.0 + vignette * 0.6));
	col *= mix(1.0, vig, clamp(vignette + dread * 0.3, 0.0, 1.0));
	// red pulse at the edges at high dread (heartbeat)
	float beat = pow(0.5 + 0.5 * sin(TIME * 6.2831 * pulse_speed), 6.0);
	col = mix(col, vec3(0.35, 0.0, 0.0), smoothstep(0.3, 0.75, r) * smoothstep(0.55, 1.0, dread) * (0.25 + 0.35 * beat));
	// luminance-weighted film grain (stronger in shadows, like film)
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float n = hash(uv * vec2(1931.0, 1087.0) + fract(TIME * 7.3) * 113.0) - 0.5;
	col += n * grain * (1.4 - lum);
	COLOR = vec4(col, 1.0);
}
