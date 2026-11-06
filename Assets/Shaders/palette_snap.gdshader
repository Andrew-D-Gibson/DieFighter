shader_type canvas_item;
// Puts something drawn at its own colours (a 3D render, lit and shaded) onto
// the approved palette (Art/_Palettes/aseprite_palette_final.aseprite): each
// pixel takes the nearest of its colours, and a one-pixel outline in the
// palette's outline navy goes round the silhouette, so it sits with the rest
// of the art. Draw it with nearest filtering at one texel per art pixel.

uniform vec4 outline_color : source_color = vec4(0.016, 0.008, 0.090, 1.0);
// Lifts every pixel toward white before it's snapped: a flash that still
// lands on palette colours.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

const int COUNT = 33;
const vec3 PALETTE[COUNT] = vec3[](
	vec3(0.000, 0.000, 0.000), vec3(0.808, 0.941, 0.945), vec3(0.816, 0.212, 0.337),
	vec3(0.565, 0.149, 0.235), vec3(0.318, 0.082, 0.129), vec3(0.263, 0.651, 0.988),
	vec3(0.216, 0.537, 0.800), vec3(0.173, 0.443, 0.667), vec3(0.478, 0.741, 0.200),
	vec3(0.396, 0.612, 0.165), vec3(0.298, 0.459, 0.125), vec3(0.933, 0.827, 0.365),
	vec3(0.800, 0.710, 0.314), vec3(0.596, 0.529, 0.231), vec3(0.949, 0.612, 0.365),
	vec3(0.933, 0.498, 0.184), vec3(0.741, 0.345, 0.059), vec3(0.773, 0.322, 0.945),
	vec3(0.659, 0.275, 0.808), vec3(0.502, 0.208, 0.616), vec3(0.337, 0.196, 0.149),
	vec3(0.769, 0.757, 0.737), vec3(0.647, 0.635, 0.616), vec3(0.557, 0.545, 0.522),
	vec3(0.388, 0.376, 0.361), vec3(0.204, 0.200, 0.188), vec3(0.553, 0.945, 0.957),
	vec3(0.016, 0.008, 0.090), vec3(0.059, 0.047, 0.180), vec3(0.075, 0.059, 0.220),
	vec3(0.098, 0.075, 0.278), vec3(0.145, 0.110, 0.420), vec3(0.275, 0.235, 0.569)
);

vec3 snap(vec3 c) {
	vec3 best = PALETTE[0];
	float best_d = 1e9;
	for (int i = 0; i < COUNT; i++) {
		vec3 d = c - PALETTE[i];
		// Weighted toward green, as the eye is: keeps bone from going blue.
		float dist = dot(d * d, vec3(0.3, 0.59, 0.11));
		if (dist < best_d) {
			best_d = dist;
			best = PALETTE[i];
		}
	}
	return best;
}

// The node's modulate, kept apart: in fragment(), COLOR already has the
// texture multiplied in.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a >= 0.5) {
		vec3 lifted = mix(c.rgb, vec3(1.0), flash);
		COLOR = vec4(snap(lifted), 1.0) * vec4(1.0, 1.0, 1.0, modulate.a);
	} else {
		float around = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
		COLOR = around >= 0.5 ? vec4(outline_color.rgb, modulate.a) : vec4(0.0);
	}
}
