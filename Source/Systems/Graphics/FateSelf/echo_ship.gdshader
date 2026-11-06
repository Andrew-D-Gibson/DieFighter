shader_type canvas_item;
// An echo of the Reckoning's Tally (RECKONING_ENDINGS.md §2): a ship the
// player destroyed, handed back by the hole with Fate's corruption already
// eating into it. Two looks in one, both worked in whole texels so the art
// stays on its pixel grid:
//
//  - Corrupting: the ship's own hull with the same hull washed through
//    Fate's purples eating into it from the top-left, the way the map shows a
//    tile Fate is about to take (corrupting_icon.gdshader). The seam crawls,
//    rows tear, the red channel splits, and now and then the whole ship
//    flickers to Fate. This is the look it keeps.
//  - Emerging: while it travels out of the black hole (`emerge` 1 at the
//    hole, 0 once it's on its slot) the hull is spaghettified along its line
//    of travel: dragged out long and thin toward the hole, wavering, and
//    wholly purple. It settles into its regular shape as `emerge` falls.
//
// Carries enemy_shader's uniforms (alpha, flash_*, cloak_*) and applies them
// the same way, so a hit still flashes, a cloak status still shows and the
// ship's fades still work: it replaces the ship's material and takes its
// values over (EchoLook).

uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float cloak_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cloak_key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloak_main_color : source_color = vec4(0.0, 0.1, 0.6, 1.0);
uniform vec4 cloak_bg_color : source_color = vec4(0.4, 0.8, 1.0, 0.2);
uniform float cloak_tolerance : hint_range(0.0, 0.5) = 0.1;

// The sprite's drawn rectangle in its own pixels, and which way its texture
// is flipped (0 or 1 on each axis): the quad is grown to make room for the
// stretch, so the shader has to know where the art really is.
uniform vec2 rect_origin = vec2(-12.0);
uniform vec2 rect_size = vec2(24.0);
uniform vec2 flip = vec2(0.0);

// Desynchronises echoes, so a wave of them doesn't glitch in unison.
uniform float seed = 0.0;
// How much of the hull Fate holds: 0 untouched, 0.5 the usual half, 1 all.
uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float step_rate = 12.0;
uniform float glitch_rate : hint_range(0.0, 1.0) = 0.18;
uniform float flicker_rate : hint_range(0.0, 1.0) = 0.04;
uniform float seam_sway = 1.5;

// 1 as it leaves the hole, 0 once it has settled. emerge_dir is the way it
// travels, in the sprite's own axes.
uniform float emerge : hint_range(0.0, 1.0) = 0.0;
uniform vec2 emerge_dir = vec2(0.0, 1.0);
// How many times longer the end nearest the hole is dragged out, how much
// thinner, and how far (texels) the strand wavers.
uniform float stretch = 4.0;
uniform float pinch = 1.4;
uniform float waver = 1.4;

// Fate's purples, darkest first, and the outline navy (as fate_self.gdshader).
const vec3 PURPLE_0 = vec3(0.145, 0.110, 0.420);
const vec3 PURPLE_1 = vec3(0.502, 0.208, 0.616);
const vec3 PURPLE_2 = vec3(0.659, 0.275, 0.808);
const vec3 PURPLE_3 = vec3(0.773, 0.322, 0.945);
const vec3 OUTLINE = vec3(0.016, 0.008, 0.090);
const vec3 STATIC = vec3(0.808, 0.941, 0.945);

varying vec2 grown;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// 4x4 ordered dither, so the wash's edge is a pixel pattern.
float bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	int index = x + y * 4;
	const float M[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (M[index] + 0.5) / 16.0;
}

// A hull colour taken to the purple of the same weight.
vec3 to_purple(vec3 c) {
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	if (l < 0.12) return OUTLINE;
	if (l < 0.3) return PURPLE_0;
	if (l < 0.5) return PURPLE_1;
	if (l < 0.68) return PURPLE_2;
	return PURPLE_3;
}

// The quad grows by as much as the stretch needs (nothing at rest), and every
// corner says where it is in units of the art's own size.
void vertex() {
	vec2 centre = rect_origin + rect_size * 0.5;
	vec2 out_from = VERTEX - centre;
	float room = max(rect_size.x, rect_size.y) * (stretch * 0.5 + 0.5) * emerge;
	vec2 pushed = out_from + vec2(out_from.x < 0.0 ? -room : room, out_from.y < 0.0 ? -room : room);
	VERTEX = centre + pushed;
	grown = pushed / rect_size + 0.5;
}

vec4 hull_at(sampler2D tex, vec2 texel) {
	vec2 size = rect_size;
	if (texel.x < 0.0 || texel.y < 0.0 || texel.x >= size.x || texel.y >= size.y) {
		return vec4(0.0);
	}
	vec2 uv = (texel + 0.5) / size;
	uv = mix(uv, 1.0 - uv, flip);
	return texture(tex, uv);
}

void fragment() {
	vec2 size = rect_size;
	float e = emerge;

	// Spaghettification: the pixel at this spot is read from further in the
	// hull the nearer the hole it is, so that end is dragged out into a
	// thread while the leading end keeps its shape.
	vec2 p = (grown - 0.5) * size;
	vec2 dir = normalize(emerge_dir);
	vec2 side = vec2(-dir.y, dir.x);
	float reach = max(size.x, size.y);
	float along = dot(p, dir);
	float across = dot(p, side);
	float tail = 1.0 - smoothstep(-reach * 0.5, reach * 0.5, along);
	float read_along = along / (1.0 + e * stretch * tail);
	float read_across = across * (1.0 + e * pinch * tail)
		+ sin(along * 0.5 - TIME * 16.0) * e * waver * tail;
	vec2 texel = floor(dir * read_along + side * read_across + size * 0.5);

	// Corruption, as the map's icons wear it: a ragged seam, a band of rows
	// sliding a texel on glitch frames, the whole hull flickering to Fate.
	float step_time = floor(TIME * step_rate) + seed * 97.0;
	float wobble = clamp(min(progress, 1.0 - progress) * 2.0, 0.0, 1.0);
	bool glitching = progress > 0.0 && hash(vec2(step_time, seed + 1.3)) < glitch_rate;
	bool flicker = wobble > 0.0 && hash(vec2(step_time, seed + 7.1)) < flicker_rate;
	float band_start = floor(hash(vec2(step_time, seed + 2.7)) * size.y);
	float band_height = 1.0 + floor(hash(vec2(step_time, seed + 3.9)) * 3.0);
	if (glitching && texel.y >= band_start && texel.y < band_start + band_height) {
		texel.x += hash(vec2(step_time, seed + 4.4)) < 0.5 ? -1.0 : 1.0;
	}

	vec4 hull = hull_at(TEXTURE, texel);
	float sway = round(sin(TIME * 2.2 + seed * 6.28) * seam_sway * wobble);
	float ragged = (floor(hash(vec2(texel.y, step_time)) * 3.0) - 1.0) * wobble;
	bool in_fate = flicker || texel.x + texel.y < progress * 2.0 * size.x + sway + ragged;

	vec3 color = hull.rgb;
	if (in_fate) {
		color = to_purple(hull.rgb);
		// Fate's half breathes toward its brightest purple and throws off
		// static.
		float pulse = 0.5 + 0.5 * sin(TIME * 5.0 + seed * 3.0);
		if (pulse > 0.75 && bayer(texel) < 0.25) {
			color = PURPLE_3;
		}
		if (hash(texel + step_time) > 0.95) {
			color = STATIC;
		}
	}
	if (glitching) {
		// Red pulled a texel out of line.
		color.r = hull_at(TEXTURE, texel + vec2(1.0, 0.0)).r;
	}

	// Still coming out of the hole: all of it purple, the dither giving way as
	// it settles.
	if (clamp(e * 1.7, 0.0, 1.0) > bayer(texel)) {
		color = to_purple(hull.rgb);
	}

	// enemy_shader's own looks, applied as it applies them.
	vec4 shown = mix(vec4(color, hull.a), vec4(flash_color.rgb, hull.a), flash_amount);
	float key = distance(hull.rgb, cloak_key_color.rgb);
	vec4 cloaked = key < cloak_tolerance
		? vec4(cloak_main_color.rgb, hull.a * cloak_main_color.a)
		: vec4(cloak_bg_color.rgb, hull.a * cloak_bg_color.a);
	vec4 final_color = mix(shown, cloaked, cloak_amount);

	// Nothing of it shows at the mouth of the hole itself.
	final_color.a *= alpha * (1.0 - smoothstep(0.9, 1.0, e));
	COLOR = final_color;
}
