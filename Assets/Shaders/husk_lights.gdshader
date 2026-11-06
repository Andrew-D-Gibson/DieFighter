shader_type canvas_item;
// A wreck whose power is failing: every pixel of its running-light colours
// goes to a dead grey as `lights` falls, all at once, so a script can flicker
// it. Everything else in the art is left as drawn.

uniform float lights : hint_range(0.0, 1.0) = 1.0;
// The Rearguard's regulation blue (LORE.md §12): the colours that are lights.
uniform vec4 light_a : source_color = vec4(0.263, 0.651, 0.988, 1.0);
uniform vec4 light_b : source_color = vec4(0.216, 0.537, 0.800, 1.0);
uniform vec4 light_c : source_color = vec4(0.173, 0.443, 0.667, 1.0);
// What a dead light looks like: a dark hull grey from the approved palette.
uniform vec4 dead : source_color = vec4(0.204, 0.200, 0.188, 1.0);

bool is_light(vec3 c) {
	return distance(c, light_a.rgb) < 0.04 || distance(c, light_b.rgb) < 0.04
		|| distance(c, light_c.rgb) < 0.04;
}

// The node's modulate, kept apart: in fragment(), COLOR already has the
// texture multiplied in.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (is_light(c.rgb) && lights < 0.5) {
		c.rgb = dead.rgb;
	}
	COLOR = c * modulate;
}
