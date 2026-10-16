// A map icon Fate will take on the next jump: the scenario's own icon with
// Fate's icon eating into it from the top-left. The seam crawls, rows tear,
// colours split and the whole icon sometimes flickers to Fate, so a threatened
// tile reads as "this is about to go" even at a glance across the map.
//
// Everything is snapped to whole texels and stepped at a low frame rate, so the
// 12x12 icons stay crisp pixel art rather than smearing.
shader_type canvas_item;

uniform sampler2D fate_texture : filter_nearest;
// Desynchronises icons so a row of threatened tiles doesn't glitch in unison.
uniform float seed = 0.0;
// Glitch frames per second. Low on purpose: choppy reads as broken signal.
uniform float step_rate = 12.0;
// Chance any given step is a glitch frame (row tear + colour split).
uniform float glitch_rate : hint_range(0.0, 1.0) = 0.18;
// Chance any given step flashes the whole icon to Fate.
uniform float flicker_rate : hint_range(0.0, 1.0) = 0.04;
// How far, in texels, the seam sways back and forth over time.
uniform float seam_sway = 2.0;
uniform vec4 hot_color : source_color = vec4(1.0, 0.35, 0.85, 1.0);
// How much of the icon Fate holds: 0 untouched, 0.5 the usual half (waiting
// for the next jump), 1 all of it. The map sweeps it either way during a jump.
uniform float progress : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = floor(UV * size);
	float step_time = floor(TIME * step_rate) + seed * 97.0;

	// The seam's wobble fades out toward either end, so an icon Fate has barely
	// touched shows none of it and one it's swallowed shows nothing else.
	float wobble = clamp(min(progress, 1.0 - progress) * 2.0, 0.0, 1.0);
	bool glitching = progress > 0.0 && hash(vec2(step_time, seed + 1.3)) < glitch_rate;
	bool flicker = wobble > 0.0 && hash(vec2(step_time, seed + 7.1)) < flicker_rate;

	// Row tear: on a glitch frame, a band of rows slides sideways.
	float band_start = floor(hash(vec2(step_time, seed + 2.7)) * size.y);
	float band_height = 1.0 + floor(hash(vec2(step_time, seed + 3.9)) * 3.0);
	if (glitching && texel.y >= band_start && texel.y < band_start + band_height) {
		texel.x += hash(vec2(step_time, seed + 4.4)) < 0.5 ? -1.0 : 1.0;
	}

	vec2 uv = (texel + 0.5) / size;
	vec4 base = texture(TEXTURE, uv);
	vec4 fate = texture(fate_texture, uv);

	// The seam: a diagonal that sways over time and is ragged row by row, so
	// Fate looks like it's actively chewing in rather than sitting still.
	float sway = round(sin(TIME * 2.2 + seed * 6.28) * seam_sway * wobble);
	float ragged = (floor(hash(vec2(texel.y, step_time)) * 3.0) - 1.0) * wobble;
	bool in_fate = flicker || texel.x + texel.y < progress * 2.0 * size.x + sway + ragged;

	vec4 color = in_fate ? fate : base;

	if (in_fate) {
		// Fate's half breathes toward a hot magenta and throws off static.
		float pulse = 0.5 + 0.5 * sin(TIME * 5.0 + seed * 3.0);
		color.rgb = mix(color.rgb, hot_color.rgb, 0.25 * pulse);
		if (hash(texel + step_time) > 0.93) {
			color.rgb = mix(color.rgb, vec3(1.0), 0.6);
		}
	}

	// Colour split: red pulled one texel out of line on glitch frames.
	if (glitching) {
		vec2 split_uv = (texel + vec2(1.0, 0.0) + 0.5) / size;
		vec4 split = in_fate ? texture(fate_texture, split_uv) : texture(TEXTURE, split_uv);
		color.r = split.r;
		color.a = max(color.a, split.a);
	}

	COLOR = color;
}
