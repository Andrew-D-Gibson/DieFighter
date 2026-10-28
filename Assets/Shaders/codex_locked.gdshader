shader_type canvas_item;

// A codex entry the player hasn't found yet: its art redrawn in the palette's
// greys, a shade dark, so the shape shows but nothing else does. Snapping to
// the palette's own greys, rather than desaturating, keeps it on palette.

// The palette's greys, lightest first: #C4C1BC #A5A29D #8E8B85 #63605C #343330.
const vec3 GREYS[5] = vec3[5](
	vec3(0.769, 0.757, 0.737),
	vec3(0.647, 0.635, 0.616),
	vec3(0.557, 0.545, 0.522),
	vec3(0.388, 0.376, 0.361),
	vec3(0.204, 0.200, 0.188)
);

// How many steps further down the ramp to draw, for pale art.
uniform int darken = 0;

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float luma = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
	int step_index = 4;
	if (luma > 0.6) {
		step_index = 2;
	} else if (luma > 0.3) {
		step_index = 3;
	}
	COLOR = vec4(GREYS[min(step_index + darken, 4)], colour.a * COLOR.a);
}
