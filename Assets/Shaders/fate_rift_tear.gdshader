// The tear in space over rift_space (FATE Rift, the Bastion gate). Fate
// keeps working at it: fate_rift_tear.gd rips it longer, prises it open,
// lets it knit back to a seam, and feeds this shader the shape every frame.
//
// Read outward from the spine (a fixed S-curve, so it stays the same tear):
// - the void inside: Fate's pure black, crawling with static that spirals
//   in toward the middle, the same language as fate_corruption.gdshader;
// - a white-hot lip, one pixel each side (or a two-pixel seam when shut);
// - a purple glow, ragged row by row;
// - a broken dark-purple fringe that crackles, with loose motes beyond and
//   short arcs that jump off the lips while it is tearing;
// - a hairline of crackle running on past each tip, where it will rip next.
//
// For a ColorRect of `size` art pixels centred on the tear. Snapped to whole
// art pixels and stepped at a low rate so it reads as broken signal, like
// every other Fate shader.
shader_type canvas_item;

uniform vec2 size = vec2(40.0, 80.0);
// How far the tear gapes, 0 (a glowing seam) to 1 (half_width_max either
// side of the spine). A strike pushes it a little past 1.
uniform float open = 0.0;
// How far along its length it has ripped: 0 is half_length.x, 1 half_length.y.
uniform float reach = 0.5;
// How hard it is tearing right now, 0 to 1: more arcs and motes.
uniform float energy = 0.0;
// A strike's blaze, 0 to 1. Already softened for Reduce Flashing.
uniform float glow = 0.0;
// 1 under Reduce Flashing: the lips stop flickering and the crackle slows.
uniform float calm = 0.0;
uniform float seed = 0.0;
uniform float step_rate = 12.0;

// The shape, written by fate_rift_tear.gd from its constants so the sparks
// it draws leave from the same lips. Spine: x = a1 sin(y f1 + p1) + a2 sin(y f2 + p2).
uniform vec4 spine = vec4(-2.6, 0.11, 0.9, 0.31);
uniform vec2 spine_phase = vec2(1.9, 0.4);
uniform vec2 half_length = vec2(14.0, 34.0);
uniform float half_width_max = 7.0;

// Approved palette: #000000 void, #191347 swirl, #80359D fringe,
// #A846CE static, #C552F1 glow, #CEF0F1 lip, #8DF1F4 lip flicker.
uniform vec4 void_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 swirl_color : source_color = vec4(0.098, 0.075, 0.278, 1.0);
uniform vec4 fringe_color : source_color = vec4(0.502, 0.208, 0.616, 1.0);
uniform vec4 static_color : source_color = vec4(0.659, 0.275, 0.808, 1.0);
uniform vec4 glow_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 lip_color : source_color = vec4(0.808, 0.941, 0.945, 1.0);
uniform vec4 flicker_color : source_color = vec4(0.553, 0.945, 0.957, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float spine_x(float y) {
	return spine.x * sin(y * spine.y + spine_phase.x) + spine.z * sin(y * spine.w + spine_phase.y);
}

// Lens-shaped: widest in the middle, closing to nothing at the tips.
float profile(float v) {
	return v * v < 1.0 ? pow(1.0 - v * v, 0.6) : 0.0;
}

vec4 void_at(vec2 rel, float edge, float half_len, float t) {
	// Normalised so the lips sit at radius 1 whatever the tear's size.
	vec2 n = rel / vec2(max(edge, 1.0), half_len);
	float r = length(n);
	float angle = atan(n.y, n.x);
	// Inner rings turn faster, so the static winds in toward the middle.
	float swirl = angle + (1.0 - r) * 3.5 - t * 1.4;
	// Two dark arms, barely lighter than the void, to show the turning.
	if (fract(swirl / 6.2832 * 2.0) < 0.16 && r > 0.25) {
		return swirl_color;
	}
	// Static, thickest near the lips, where Fate is still pouring in.
	float cell = hash(vec2(floor(swirl * 4.0), floor(r * 6.0) + seed));
	float density = 0.05 + 0.3 * smoothstep(0.45, 1.0, r);
	if (cell > 1.0 - density) {
		return cell > 1.0 - density * 0.3 ? static_color : fringe_color;
	}
	return void_color;
}

void fragment() {
	vec2 texel = floor(UV * size);
	// Art pixels from the tear's centre, pixel centres, y down.
	vec2 p = texel + 0.5 - size * 0.5;
	float rate = mix(step_rate, step_rate * 0.5, calm);
	float step_t = floor(TIME * rate) + seed * 17.0;
	float stepped_time = floor(TIME * rate) / rate;
	float slow_t = floor(TIME * 3.0) + seed * 5.0;

	float half_len = mix(half_length.x, half_length.y, reach);
	float v = p.y / half_len;
	float sx = spine_x(p.y);
	float dx = p.x - sx;
	float d = abs(dx);
	float side = dx < 0.0 ? -1.0 : 1.0;
	float seam = v * v < 1.0 ? sqrt(1.0 - v * v) : 0.0;
	float lens = profile(v);

	// Ragged lips: a fixed bite per row and side, plus a tremor each step,
	// growing in as the tear opens.
	float bite = hash(vec2(texel.y, seed + side * 3.1)) - 0.5;
	float tremor = hash(vec2(texel.y + side * 0.37, step_t)) - 0.5;
	float ragged = (bite * 1.6 + tremor) * clamp(open * 3.0, 0.0, 1.0) * lens;
	float edge = open * half_width_max * lens + ragged;

	float lip_end = max(edge, 0.0) + 0.5 + 0.6 * (1.0 - clamp(open * 4.0, 0.0, 1.0)) * seam;
	float glow_end = lip_end + 1.0 + 1.6 * seam + hash(vec2(texel.y, slow_t + side)) * 0.9;
	float fringe_end = glow_end + 1.2 + 1.2 * seam;

	vec4 color = vec4(0.0);
	if (v * v >= 1.0) {
		// Past the tips: a hairline of crackle where it will rip next.
		float past = abs(v) - 1.0;
		if (past < 0.18 && d < 1.0 && hash(vec2(texel.y, step_t)) < 0.55 - past * 2.0) {
			color = hash(vec2(texel.y, step_t + 0.5)) < 0.25 + glow ? glow_color : fringe_color;
		}
	} else if (d < edge - 0.5 && edge > 1.0) {
		color = void_at(vec2(dx, p.y), edge, half_len, stepped_time);
	} else if (d < lip_end) {
		bool flicker = calm < 0.5 && hash(vec2(texel.y, step_t + side)) < 0.25;
		color = flicker ? flicker_color : lip_color;
	} else if (d < glow_end) {
		// A strike burns the glow white.
		color = hash(texel + step_t) < glow * 0.7 ? lip_color : glow_color;
	} else if (d < fringe_end) {
		// Broken, and re-broken a few times a second, so the edge crackles.
		if (hash(texel + vec2(slow_t, seed)) < 0.65 + glow * 0.35) {
			color = glow > 0.4 ? glow_color : vec4(fringe_color.rgb, 0.85);
		}
	} else {
		float beyond = d - fringe_end;
		// Arcs off the lips while it is tearing: one per five-row band at
		// most, wandering a row or so as it reaches out.
		float band = floor((p.y + 200.0) / 5.0);
		float arc_seed = hash(vec2(band, step_t + side * 7.0));
		float arc_chance = 0.04 + 0.35 * energy + 0.4 * glow;
		if (arc_seed < arc_chance && lens > 0.2) {
			float arc_len = 2.0 + hash(vec2(band, step_t + 3.0)) * 6.0 * (0.5 + energy);
			float arc_row = band * 5.0 - 200.0 + 2.0 + floor(sin(beyond * 1.1 + arc_seed * 40.0) * 1.4 + 0.5);
			if (beyond < arc_len && floor(p.y) == floor(arc_row)) {
				color = beyond < arc_len * 0.5 ? lip_color : glow_color;
			}
		}
		// Loose motes drifting off it, thicker while it tears.
		if (color.a == 0.0 && beyond < 6.0 * seam + 1.0) {
			float mote = hash(texel + vec2(floor(TIME * 2.0) + seed, 1.3));
			if (mote > 0.985 - energy * 0.03 - glow * 0.03) {
				color = mote > 0.995 ? glow_color : fringe_color;
			}
		}
		// A strike lights a faint halo round the whole tear.
		if (color.a == 0.0 && glow > 0.0 && beyond < 3.0 * seam) {
			color = vec4(fringe_color.rgb, glow * 0.5);
		}
	}
	COLOR = color;
}
