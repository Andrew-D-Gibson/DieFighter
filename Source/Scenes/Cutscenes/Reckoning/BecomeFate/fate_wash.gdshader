shader_type canvas_item;
// The player's hull as the hole takes it (RECKONING_ENDINGS.md §6.5, Become
// Fate): first the Vanguard Drive's gold, as drive_recolor.gdshader burns
// it, then Fate's purple spreading from the nose back, a whole art pixel row
// at a time, until the gold engines go purple too.
//
// The washed hull keeps its shading: each pixel takes the purple of its own
// brightness from a ramp of approved palette colours, so it reads as the same
// ship, cloaked, the way the cloak wash recolours a ship in the fight. The
// row the purple is taking glows, and the row ahead of it is dithered half
// in, so the wash is seen eating its way back rather than fading.
//
// Rows are counted in the sprite's own pixels (nose up, as every cutscene
// hull is drawn), so it works whichever way the ship is turned. Takes the
// flash JumpFx.flare() drives, as enemy_shader does.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
// Rows of the hull the purple has taken, from the nose. Keep it whole.
uniform float washed_rows = 0.0;
// The hull's height, in art pixels: its sprite frame's.
uniform float hull_rows = 28.0;
// The drive lights and flames: gold at 0, Fate's purple at 1.
uniform float drive_purple : hint_range(0.0, 1.0) = 0.0;

// The drive's blues in the art, and the gold drive_recolor.gdshader burns
// them in.
const vec3 FROM[4] = vec3[](
	vec3(0.553, 0.945, 0.957), vec3(0.263, 0.651, 0.988),
	vec3(0.216, 0.537, 0.800), vec3(0.173, 0.443, 0.667));
const vec3 GOLD[4] = vec3[](
	vec3(0.933, 0.827, 0.365), vec3(0.933, 0.827, 0.365),
	vec3(0.800, 0.710, 0.314), vec3(0.596, 0.529, 0.231));
// The same lights in Fate's purples, brightest first.
const vec3 PURPLE[4] = vec3[](
	vec3(0.773, 0.322, 0.945), vec3(0.773, 0.322, 0.945),
	vec3(0.659, 0.275, 0.808), vec3(0.502, 0.208, 0.616));

// The washed hull, darkest to brightest: outline navy, the deep navies, then
// Fate's three purples.
const vec3 RAMP[6] = vec3[](
	vec3(0.016, 0.008, 0.090), vec3(0.098, 0.075, 0.278),
	vec3(0.145, 0.110, 0.420), vec3(0.502, 0.208, 0.616),
	vec3(0.659, 0.275, 0.808), vec3(0.773, 0.322, 0.945));
const float STEPS[5] = float[](0.09, 0.2, 0.34, 0.52, 0.72);
const vec3 HOT = vec3(0.773, 0.322, 0.945);

varying vec2 local_pos;
// The node's modulate, kept apart: in fragment(), COLOR already has the
// texture multiplied in.
varying vec4 modulate;

void vertex() {
	local_pos = VERTEX;
	modulate = COLOR;
}

vec3 washed(vec3 c) {
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 out_color = RAMP[5];
	for (int i = 0; i < 5; i++) {
		if (lum < STEPS[i]) {
			out_color = RAMP[i];
			break;
		}
	}
	return out_color;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool drive = false;
	for (int i = 0; i < 4; i++) {
		if (distance(c.rgb, FROM[i]) < 0.04) {
			c.rgb = drive_purple >= 0.5 ? PURPLE[i] : GOLD[i];
			drive = true;
			break;
		}
	}

	float row = floor(local_pos.y + hull_rows * 0.5);
	float column = floor(local_pos.x + 64.0);
	if (!drive) {
		if (row < washed_rows - 1.0) {
			c.rgb = washed(c.rgb);
		} else if (row < washed_rows) {
			// The row being taken.
			c.rgb = HOT;
		} else if (row < washed_rows + 1.0 && washed_rows > 0.0 && mod(column + row, 2.0) < 1.0) {
			// Half in: the purple eating into the next row.
			c.rgb = washed(c.rgb);
		}
	}

	c.rgb = mix(c.rgb, flash_color.rgb, flash_amount);
	COLOR = c * modulate;
}
