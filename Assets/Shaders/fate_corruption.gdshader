// A scrolling piece Fate is eating. The piece's own art fades into the
// background by depth, exactly as scrolling_object.gdshader does, and Fate
// works on it in the same language as corrupting_icon.gdshader on the map:
//
// - Pure black in the art is void Fate already holds: a hole cut through the
//   piece, so whatever is behind shows through. It crawls with static.
// - A seam creeps in from one corner and back out, ragged row by row, with a
//   hot edge, so every piece is visibly being chewed rather than just tinted.
// - On glitch frames a band of rows tears sideways and red splits off a
//   texel; now and then the whole piece blinks to void.
// - Lightning in the background (FateStorm) raises the global fate_flash,
//   which rims every piece in Fate's colour for as long as the flash lasts.
//
// Pieces must be single-frame textures: the seam is laid out across the
// whole texture. Untextured bits (particles) only get the depth fade.
//
// Everything is snapped to whole texels and stepped at a low frame rate, so
// the pieces stay crisp pixel art rather than smearing.
shader_type canvas_item;

// 0 to 1, how lit the sky is right now. Set by FateStorm.
global uniform float fate_flash;

// --- Depth fade: the same contract as scrolling_object.gdshader ----------
uniform vec4 color : source_color;
uniform vec4 background_color : source_color;
uniform bool keep_texture_colors = false;
uniform float velocity_level;
uniform float base_visibility = 0.0;
uniform float visibility_per_depth = 0.1;

// --- Corruption ----------------------------------------------------------
// Desynchronises pieces so a field of them doesn't glitch in unison.
uniform float seed = 0.0;
// Glitch frames per second. Low on purpose: choppy reads as broken signal.
uniform float step_rate = 10.0;
// Chance any given step is a glitch frame (row tear + colour split).
uniform float glitch_rate : hint_range(0.0, 1.0) = 0.07;
// Chance any given step blinks the whole piece to void.
uniform float flicker_rate : hint_range(0.0, 1.0) = 0.012;
// How far the seam gets across the piece, as a share of it, at its
// shallowest and deepest, and how long one advance and retreat takes.
uniform float reach_min : hint_range(0.0, 1.0) = 0.05;
uniform float reach_max : hint_range(0.0, 1.0) = 0.4;
uniform float reach_period = 7.0;
// Share of void texels lit with static at any moment.
uniform float static_density : hint_range(0.0, 1.0) = 0.14;

// Approved palette: #000000, #80359D, #A846CE, #C552F1, #CEF0F1.
uniform vec4 void_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 ember_color : source_color = vec4(0.502, 0.208, 0.616, 1.0);
uniform vec4 static_color : source_color = vec4(0.659, 0.275, 0.808, 1.0);
uniform vec4 hot_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 spark_color : source_color = vec4(0.808, 0.941, 0.945, 1.0);

// Modulate, kept apart from the texture so torn rows resample it correctly.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

bool is_void(vec4 texel_color) {
	return texel_color.a > 0.0 && dot(texel_color.rgb, vec3(1.0)) < 0.05;
}

void fragment() {
	float visibility = clamp(base_visibility + visibility_per_depth * velocity_level, 0.0, 1.0);
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;

	if (size.x < 3.0 || size.y < 3.0) {
		vec3 own = keep_texture_colors ? COLOR.rgb : color.rgb;
		COLOR = vec4(mix(background_color.rgb, own, visibility), COLOR.a);
	} else {
		vec2 texel = floor(UV * size);
		float step_time = floor(TIME * step_rate) + seed * 97.0;
		bool glitching = hash(vec2(step_time, seed + 1.3)) < glitch_rate;
		bool flicker = hash(vec2(step_time, seed + 7.1)) < flicker_rate;

		// Row tear: on a glitch frame, a band of rows slides sideways.
		float band_start = floor(hash(vec2(step_time, seed + 2.7)) * size.y);
		float band_height = 1.0 + floor(hash(vec2(step_time, seed + 3.9)) * 3.0);
		bool in_band = glitching && texel.y >= band_start && texel.y < band_start + band_height;
		vec2 source = texel;
		if (in_band) {
			source.x += hash(vec2(step_time, seed + 4.4)) < 0.5 ? -1.0 : 1.0;
		}
		vec4 base = texture(TEXTURE, (source + 0.5) / size);

		// The seam: a diagonal from the corner this piece's seed picked, that
		// advances and retreats, ragged row by row so it looks like chewing.
		vec2 flip = vec2(step(0.5, hash(vec2(seed, 5.1))), step(0.5, hash(vec2(seed, 6.3))));
		vec2 from_corner = mix(texel, size - 1.0 - texel, flip);
		float wave = 0.5 + 0.5 * sin(TIME * 6.2832 / reach_period + seed * 6.2832);
		float reach = mix(reach_min, reach_max, wave) * (size.x + size.y);
		float ragged = floor(hash(vec2(texel.y + seed, step_time)) * 3.0) - 1.0;
		float depth_in = from_corner.x + from_corner.y - (reach + ragged);
		bool eaten = depth_in < 0.0;
		bool on_edge = !eaten && depth_in < 1.0;

		bool void_here = flicker || eaten || is_void(base);
		// Smoulder: stone right beside authored void glows faintly.
		bool beside_void = false;
		bool beside_space = false;
		for (int i = 0; i < 4; i++) {
			vec2 offset = vec2(float(i == 0) - float(i == 1), float(i == 2) - float(i == 3));
			vec4 neighbour = texture(TEXTURE, (source + offset + 0.5) / size);
			beside_void = beside_void || is_void(neighbour);
			beside_space = beside_space || neighbour.a <= 0.0;
		}

		float pulse = 0.5 + 0.5 * sin(TIME * 4.0 + seed * 3.0);
		vec3 rgb;
		// Static and edges are light Fate gives off, so depth dims them less.
		bool emissive = false;
		// Void is a hole, not paint: only its static is drawn.
		float alpha = base.a;

		if (void_here) {
			rgb = void_color.rgb;
			alpha = 0.0;
			float noise = hash(texel + vec2(step_time * 0.37, seed));
			float density = static_density + 0.25 * fate_flash;
			if (noise > 1.0 - density) {
				rgb = static_color.rgb;
				emissive = true;
				alpha = base.a;
			}
			if (noise > 1.0 - density * 0.35) {
				rgb = hot_color.rgb;
			}
			if (noise > 0.996) {
				rgb = spark_color.rgb;
			}
		} else if (on_edge) {
			rgb = mix(ember_color.rgb, hot_color.rgb, pulse);
			emissive = true;
		} else {
			rgb = keep_texture_colors ? base.rgb : color.rgb;
			if (beside_void) {
				rgb = mix(rgb, ember_color.rgb, 0.35 + 0.3 * pulse);
			}
			// Lit from behind by lightning: the silhouette's edge catches it.
			if (beside_space) {
				rgb = mix(rgb, hot_color.rgb, fate_flash * 0.85);
				emissive = emissive || fate_flash > 0.2;
			}
		}

		// Colour split: red pulled a texel out of line on glitch frames.
		if (glitching) {
			vec4 split = texture(TEXTURE, (source + vec2(1.0, 0.0) + 0.5) / size);
			rgb.r = max(rgb.r, split.r * 1.6);
		}

		// Modulate darkens Fate's light too: the cutscene shades depth with it.
		rgb *= tint.rgb;
		float shown = emissive ? sqrt(visibility) : visibility;
		COLOR = vec4(mix(background_color.rgb, rgb, shown), alpha * tint.a);
	}
}
