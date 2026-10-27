// The jump gate's map icons, alive: the portal inside the ring swirls and
// draws inward, a glint orbits the ring, and the whole thing breathes
// brighter. Works on the 20 px map icon and the 12 px caption icon alike,
// since everything is measured from the texture's own size.
//
// Each texel keeps its place and colour family; only which palette colour it
// shows changes, so the icon stays crisp pixel art.
shader_type canvas_item;

// How far out the portal reaches, as a share of the icon's half-width. Texels
// inside it swirl; texels outside are the ring, and catch the glint.
uniform float portal_radius = 0.62;
// Swirl: arms, how tightly they wind, and turns per second.
uniform float arms = 3.0;
uniform float twist = 1.6;
uniform float spin = 0.35;
// Rings of light travelling in towards the centre, per second.
uniform float pull_rate = 0.9;
// Glint: turns per second round the ring, and its width in radians.
uniform float glint_speed = 0.25;
uniform float glint_width = 0.5;
// 0 to 1: how strongly it's lit. The map raises this once the gate is open.
uniform float energy : hint_range(0.0, 1.0) = 0.5;

// Approved palette.
uniform vec4 core_color : source_color = vec4(0.808, 0.941, 0.945, 1.0); // #CEF0F1
uniform vec4 glow_color : source_color = vec4(0.553, 0.945, 0.957, 1.0); // #8DF1F4
uniform vec4 bright_color : source_color = vec4(0.263, 0.651, 0.988, 1.0); // #43A6FC
uniform vec4 mid_color : source_color = vec4(0.216, 0.537, 0.8, 1.0); // #3789CC
uniform vec4 deep_color : source_color = vec4(0.145, 0.11, 0.42, 1.0); // #251C6B
uniform vec4 void_color : source_color = vec4(0.098, 0.075, 0.278, 1.0); // #191347

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = floor(UV * size);
	vec4 base = texture(TEXTURE, (texel + 0.5) / size);
	vec2 p = texel + 0.5 - size * 0.5;
	float half_width = size.x * 0.5;
	float r = length(p) / half_width;
	float angle = atan(p.y, p.x);
	vec3 rgb = base.rgb;

	if (base.a > 0.0 && r < portal_radius) {
		float depth = r / portal_radius;
		// Spiral arms winding in, turning.
		float arm = fract(angle / TAU * arms + depth * twist - TIME * spin);
		// Rings drawn inward.
		float pull = fract(depth - TIME * pull_rate);
		float light = (1.0 - depth) * (0.75 + 0.3 * energy) + 0.12;
		light += (arm < 0.35 ? 0.25 : 0.0);
		light += (pull < 0.18 ? 0.3 : 0.0) * (0.5 + 0.5 * energy);
		if (light > 0.95) {
			rgb = core_color.rgb;
		} else if (light > 0.7) {
			rgb = glow_color.rgb;
		} else if (light > 0.5) {
			rgb = bright_color.rgb;
		} else if (light > 0.32) {
			rgb = mid_color.rgb;
		} else if (light > 0.18) {
			rgb = deep_color.rgb;
		} else {
			rgb = void_color.rgb;
		}
	} else if (base.a > 0.0) {
		// The glint, orbiting the ring.
		float glint_angle = TIME * glint_speed * TAU;
		float off = abs(mod(angle - glint_angle + PI, TAU) - PI);
		if (off < glint_width * 0.35) {
			rgb = core_color.rgb;
		} else if (off < glint_width) {
			rgb = glow_color.rgb;
		}
	}
	COLOR = vec4(rgb, base.a) * modulate;
}
