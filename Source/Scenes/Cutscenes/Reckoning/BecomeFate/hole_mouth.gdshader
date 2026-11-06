shader_type canvas_item;
// Fate's rim seen from inside the hole (RECKONING_ENDINGS.md §6.5, Become
// Fate): the opening's black hole turned inside out. The way out is a disc of
// open sky in the middle of the frame; round it the rim burns and swirls the
// way the main menu's fate_behind.gdshader draws it, its glow spilling
// inward over the sky; everywhere past the rim is the inside of the hole,
// dark, with faint bands of purple wheeling round it.
//
// Drawn on a ColorRect in whole art pixels, its light dithered between the
// Fate purples rather than blended, so it sits on the approved palette.

// The rect's size, in art pixels.
uniform vec2 size_px = vec2(336.0, 196.0);
// The middle of the way out, from the rect's top-left, in art pixels.
uniform vec2 mouth_center = vec2(168.0, 98.0);
uniform float mouth_radius = 80.0;
// How far in over the sky the rim's glow reaches, in art pixels.
uniform float glow_reach = 9.0;
// How fast the bright patches wheel round the rim, in pixels per second.
uniform float swirl_speed = 10.0;
uniform float pulse_period = 7.0;
// Radians the whole picture is turned by: the camera turning round.
uniform float turn = 0.0;
// Seconds, driven by the cutscene, so the swirl never jumps on a skip.
uniform float time = 0.0;

uniform vec4 rim_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 bright_color : source_color = vec4(0.659, 0.275, 0.808, 1.0);
uniform vec4 glow_color : source_color = vec4(0.502, 0.208, 0.616, 1.0);
uniform vec4 far_glow_color : source_color = vec4(0.275, 0.235, 0.569, 1.0);
uniform vec4 band_color : source_color = vec4(0.098, 0.075, 0.278, 1.0);
uniform vec4 deep_band_color : source_color = vec4(0.059, 0.047, 0.180, 1.0);
uniform vec4 void_color : source_color = vec4(0.016, 0.008, 0.090, 1.0);

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 cell = floor(UV * size_px);
	vec2 from_center = cell + 0.5 - mouth_center;
	float r = length(from_center);
	// Positive past the rim, into the hole; negative in over the sky.
	float depth = r - mouth_radius;
	float angle = atan(from_center.x, -from_center.y) - turn;
	float pulse = 0.85 + 0.15 * sin(time * 6.2832 / pulse_period);
	int bayer_index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	float threshold = (BAYER[bayer_index] + 0.5) / 16.0 - 0.5;

	if (depth >= 0.0) {
		// Inside the hole: bands wheel round, faster near the rim, and fade
		// into the dark with depth.
		float along = angle * mouth_radius;
		float spin = time * swirl_speed * (1.0 + 30.0 / (depth + 10.0));
		float band = noise(vec2((along - spin) / 22.0, depth / 9.0 - time * 0.2));
		float light = exp(-depth / 34.0) * pulse * mix(0.2, 1.3, band);
		float level = light * 3.0 + threshold;
		if (depth < 1.0) {
			COLOR = rim_color;
		} else if (depth < 2.0 && level >= 1.2) {
			COLOR = bright_color;
		} else if (level >= 2.0) {
			COLOR = glow_color;
		} else if (level >= 1.3) {
			COLOR = band_color;
		} else if (level >= 0.7) {
			COLOR = deep_band_color;
		} else {
			COLOR = void_color;
		}
	} else {
		// Over the sky: the rim's glow, swirling, spilling in.
		float height = -depth;
		float along = angle * mouth_radius;
		float swirl = noise(vec2((along - time * swirl_speed) / 14.0, height / 5.0 - time * 0.15));
		float light = exp(-height / glow_reach) * pulse * mix(0.45, 1.25, swirl);
		float level = light * 4.0 + threshold;
		if (level >= 3.0) {
			COLOR = bright_color;
		} else if (level >= 2.0) {
			COLOR = glow_color;
		} else if (level >= 1.0) {
			COLOR = far_glow_color;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
