shader_type canvas_item;
// Fate, behind the player: the rim of the black hole the whole fleet is
// running from, just showing over the bottom of the main menu, with its glow
// washing up the screen. Drawn on a ColorRect in whole game pixels, its
// light dithered between the Fate purples rather than blended.

// The rect's size, in game pixels.
uniform vec2 size_px = vec2(320.0, 70.0);
// The event horizon, a circle mostly below the rect. Relative to the rect's
// top-left, in game pixels.
uniform vec2 horizon_center = vec2(100.0, 330.0);
uniform float horizon_radius = 270.0;
// How high above the rim the glow reaches, in game pixels.
uniform float glow_reach = 18.0;
// How fast the bright patches swirl round the rim, in pixels per second.
uniform float swirl_speed = 4.0;
uniform float pulse_period = 9.0;

uniform vec4 rim_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 bright_color : source_color = vec4(0.659, 0.275, 0.808, 1.0);
uniform vec4 glow_color : source_color = vec4(0.502, 0.208, 0.616, 1.0);
uniform vec4 far_glow_color : source_color = vec4(0.275, 0.235, 0.569, 1.0);
uniform vec4 void_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

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
	vec2 from_center = cell + 0.5 - horizon_center;
	// Positive above the rim, in game pixels.
	float height = length(from_center) - horizon_radius;
	if (height < 0.0) {
		COLOR = void_color;
	} else {
		// Distance along the rim, so the swirl follows its curve.
		float along = atan(from_center.x, -from_center.y) * horizon_radius;
		float swirl = noise(vec2((along - TIME * swirl_speed) / 14.0, height / 6.0 - TIME * 0.15));
		float pulse = 0.85 + 0.15 * sin(TIME * 6.2832 / pulse_period);
		float light = exp(-height / glow_reach) * pulse * mix(0.45, 1.25, swirl);

		int bayer_index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
		float level = light * 4.0 + (BAYER[bayer_index] + 0.5) / 16.0 - 0.5;
		if (height < 1.0) {
			COLOR = rim_color;
		} else if (level >= 3.0) {
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
