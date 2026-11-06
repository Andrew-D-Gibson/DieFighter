shader_type canvas_item;
// "You" (RECKONING_ENDINGS.md §4): the player's own hull with Fate still
// taking it over. Purple crawls across it in dithered waves, a burning edge
// where the wash advances, and horizontal slices tear sideways in the
// GlitchShader's manner. `tear` pulls it apart for good when it's destroyed.
//
// Works in texels, so every effect lands on the art's own pixel grid, and
// every colour it writes is one of the approved palette's. Drawn on a hull
// padded with clear texels to the sides (FateSelfLook), so a slice can slide
// out past the art without being clipped.
//
// Carries enemy_shader's uniforms, so whatever drives an enemy's look (the hit
// flash, the fade, the cloak wash) still drives this one.

uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float cloak_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cloak_key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloak_main_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 cloak_bg_color : source_color = vec4(0.502, 0.208, 0.616, 1.0);
uniform float cloak_tolerance : hint_range(0.0, 0.5) = 0.1;

// How much of the hull the wash holds on average, and how far the waves
// swing it either way.
uniform float corruption : hint_range(0.0, 1.0) = 0.42;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.7;
// Texels from one wave crest to the next, and crests per second.
uniform float wave_length = 13.0;
uniform float wave_speed = 0.45;
// How often a slice tears, 0 to 1, and how many texels it may slide.
uniform float slice_rate : hint_range(0.0, 1.0) = 0.22;
uniform float slice_reach = 3.0;
// 0 whole, 1 gone: the slices pull the hull apart.
uniform float tear : hint_range(0.0, 1.0) = 0.0;

// Fate's purples, darkest first, and the outline navy.
const vec3 PURPLE_0 = vec3(0.145, 0.110, 0.420);
const vec3 PURPLE_1 = vec3(0.502, 0.208, 0.616);
const vec3 PURPLE_2 = vec3(0.659, 0.275, 0.808);
const vec3 PURPLE_3 = vec3(0.773, 0.322, 0.945);
const vec3 OUTLINE = vec3(0.016, 0.008, 0.090);
const vec3 WHITE = vec3(0.808, 0.941, 0.945);
const vec3 CYAN = vec3(0.553, 0.945, 0.957);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// 4x4 ordered dither: the wash's edge breaks up into a pixel pattern rather
// than blending to colours off the palette.
float bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	int index = x + y * 4;
	const float M[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (M[index] + 0.5) / 16.0;
}

// Takes a hull colour to the purple of the same weight.
vec3 to_purple(vec3 c) {
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	if (l < 0.12) return OUTLINE;
	if (l < 0.3) return PURPLE_0;
	if (l < 0.5) return PURPLE_1;
	if (l < 0.68) return PURPLE_2;
	return PURPLE_3;
}

void fragment() {
	vec2 texels = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * texels);

	// The slices: bands a few rows tall, re-rolled a dozen times a second,
	// some slid sideways. Tearing, more of them slide, further, and stay.
	float step_time = floor(TIME * 12.0);
	float band_height = 2.0 + floor(hash(vec2(step_time, 7.1)) * 3.0);
	float band = floor((px.y + floor(hash(vec2(step_time, 3.3)) * 4.0)) / band_height);
	float roll = hash(vec2(band, step_time));
	float rate = mix(slice_rate, 1.0, tear);
	float slid = step(roll, rate);
	// Torn, each band keeps one way, so the pieces separate instead of jitter.
	float side = hash(vec2(band, 91.7)) < 0.5 ? -1.0 : 1.0;
	float jitter = (hash(vec2(band, step_time + 0.5)) - 0.5) * 2.0 * slice_reach;
	float pull = side * (slice_reach + tear * tear * 26.0) * (0.6 + hash(vec2(band, 13.0)));
	float shift = round(mix(jitter, pull, tear)) * slid;
	vec2 sample_px = px - vec2(shift, 0.0);
	vec4 tex_color = texture(TEXTURE, (sample_px + 0.5) * TEXTURE_PIXEL_SIZE);
	if (sample_px.x < 0.0 || sample_px.x >= texels.x) {
		tex_color.a = 0.0;
	}

	// The wash crawling across: two waves on a slant, so it never settles
	// into stripes, held back by the dither.
	float along = dot(px, normalize(vec2(1.0, 0.45)));
	float across = dot(px, normalize(vec2(-0.3, 1.0)));
	float wave = sin((along / wave_length - TIME * wave_speed) * 6.2832) * 0.65
		+ sin((across / (wave_length * 1.7) + TIME * wave_speed * 0.6) * 6.2832) * 0.35;
	float hold = clamp(corruption + wave * wave_strength + tear, 0.0, 1.0);
	float threshold = bayer(px);
	vec3 color = tex_color.rgb;
	if (hold > threshold) {
		// Just taken: the edge burns bright.
		color = hold - threshold < 0.06 ? PURPLE_3 : to_purple(tex_color.rgb);
	}

	// Now and then a sliding slice's top row flickers to one hot colour:
	// data, not hull, for a frame.
	float band_top = mod(px.y + floor(hash(vec2(step_time, 3.3)) * 4.0), band_height) < 1.0 ? 1.0 : 0.0;
	if (slid > 0.5 && band_top > 0.5 && hash(vec2(band, step_time + 9.0)) < 0.25) {
		color = hash(vec2(band, step_time + 4.0)) < 0.25 ? CYAN : PURPLE_3;
	}

	// The enemy shader's own looks, so a hit still flashes and a cloak still
	// shows.
	float key = distance(tex_color.rgb, cloak_key_color.rgb);
	vec3 cloaked = key < cloak_tolerance ? cloak_main_color.rgb : cloak_bg_color.rgb;
	color = mix(color, cloaked, step(0.5, cloak_amount));
	color = mix(color, flash_color.rgb, flash_amount);

	// Torn, pixels drop out, the slid bands first.
	float survive = hash(px + vec2(band * 3.1, 0.0));
	float gone = step(survive, tear * tear * (slid > 0.5 ? 1.4 : 0.9));

	COLOR = vec4(color, tex_color.a * alpha * (1.0 - gone));
}
