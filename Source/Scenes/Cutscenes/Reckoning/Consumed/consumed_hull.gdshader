shader_type canvas_item;
// The player's hull as Fate takes it (ConsumedHull). Three things happen to
// the same sprite, so they live in one shader:
//   - the drive: the Vanguard Drive's gold (drive_recolor.gdshader's mapping),
//     and each flame shortening toward its nozzle as it goes out;
//   - Fate's cloak (enemy_shader.gdshader's mapping, as
//     FateLedger._dress_as_fallen sets it), reaching across the hull from the
//     hole's side, dithered on the art grid rather than blended;
//   - cracks, lit from inside by Fate's purple, opening along their length.
// With gold 0, wash_reach 1, cloak_amount 0.4, no flash and no cracks, this
// draws exactly what enemy_shader draws for the Fallen.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

// 1: the drive's lights and flames burn gold. 0: the art's own colours.
uniform float gold : hint_range(0.0, 1.0) = 1.0;

// Per pixel of the frame: r is which flame it belongs to (index + 1, in
// 1/255ths; 0 for the hull) and g how far down that flame it sits (0 at the
// nozzle, 1 at the longest tip).
uniform sampler2D flame_mask : filter_nearest;
// How much of each flame still burns: 1 all of it, 0 none.
uniform float flame_power[8];

uniform vec4 cloak_key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloak_main_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 cloak_bg_color : source_color = vec4(0.425, 0.177, 0.520, 1.0);
uniform float cloak_tolerance = 0.1;
// How strongly the cloak tints the hull where it has reached.
uniform float cloak_amount : hint_range(0.0, 1.0) = 0.4;
// The way to the hole, in the texture's own space (y down is the tail of a
// nose-up hull). The cloak starts on that edge.
uniform vec2 wash_from = vec2(0.0, 1.0);
// How far across the hull the cloak has reached: 0 nowhere, 1 everywhere.
uniform float wash_reach : hint_range(0.0, 1.0) = 0.0;

// Per pixel of the frame: a is 1 on a crack, r when along the crack's
// growth it opens (0 first, 1 last).
uniform sampler2D crack_mask : filter_nearest;
// How far the cracks have opened, 0-1.
uniform float crack = 0.0;
// How far the cloak has sealed them over again, 0-1.
uniform float crack_seal : hint_range(0.0, 1.0) = 0.0;
uniform vec4 crack_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 crack_hot_color : source_color = vec4(0.808, 0.941, 0.945, 1.0);

const vec3 FROM[4] = vec3[](
	vec3(0.553, 0.945, 0.957), vec3(0.263, 0.651, 0.988),
	vec3(0.216, 0.537, 0.800), vec3(0.173, 0.443, 0.667));
const vec3 TO[4] = vec3[](
	vec3(0.933, 0.827, 0.365), vec3(0.933, 0.827, 0.365),
	vec3(0.800, 0.710, 0.314), vec3(0.596, 0.529, 0.231));

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 c = tex;

	vec4 flame = texture(flame_mask, UV);
	int flame_index = int(round(flame.r * 255.0)) - 1;
	if (flame_index >= 0 && flame_index < 8 && flame.g > flame_power[flame_index] - 0.001) {
		c.a = 0.0;
	}

	for (int i = 0; i < 4; i++) {
		if (distance(c.rgb, FROM[i]) < 0.04) {
			c.rgb = mix(c.rgb, TO[i], gold);
			break;
		}
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash_amount);

	// 0 on the hole's edge of the hull, 1 on the far edge.
	float from_hole = 0.5 - dot(UV - 0.5, normalize(wash_from)) / (abs(normalize(wash_from).x) + abs(normalize(wash_from).y));
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
	int bayer_index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	float threshold = (BAYER[bayer_index] + 0.5) / 16.0;
	float front = (wash_reach * 1.25 - from_hole) / 0.25;
	if (front > threshold) {
		vec4 cloaked = distance(tex.rgb, cloak_key_color.rgb) < cloak_tolerance
			? vec4(cloak_main_color.rgb, c.a * cloak_main_color.a)
			: vec4(cloak_bg_color.rgb, c.a * cloak_bg_color.a);
		c = mix(c, cloaked, cloak_amount);
	}

	vec4 cracked = texture(crack_mask, UV);
	if (cracked.a > 0.5 && cracked.r < crack && tex.a > 0.5) {
		// The newest part of a crack is white-hot, the rest Fate's purple.
		vec3 lit = crack - cracked.r < 0.12 ? crack_hot_color.rgb : crack_color.rgb;
		c.rgb = mix(lit, c.rgb, crack_seal);
	}

	COLOR = c * modulate;
}
