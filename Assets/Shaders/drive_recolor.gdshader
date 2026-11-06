shader_type canvas_item;
// The player's ship running on the Vanguard Drive (LORE.md §4): its blue
// drive lights and flames burn in the drive's gold. Each light blue in the
// art goes to the gold of the same brightness, so the art keeps its shading
// and stays on the approved palette. Also takes the flash JumpFx.flare()
// drives, as enemy_shader does.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

const vec3 FROM[4] = vec3[](
	vec3(0.553, 0.945, 0.957), vec3(0.263, 0.651, 0.988),
	vec3(0.216, 0.537, 0.800), vec3(0.173, 0.443, 0.667));
const vec3 TO[4] = vec3[](
	vec3(0.933, 0.827, 0.365), vec3(0.933, 0.827, 0.365),
	vec3(0.800, 0.710, 0.314), vec3(0.596, 0.529, 0.231));

// The node's modulate, kept apart: in fragment(), COLOR already has the
// texture multiplied in.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < 4; i++) {
		if (distance(c.rgb, FROM[i]) < 0.04) {
			c.rgb = TO[i];
			break;
		}
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash_amount);
	COLOR = c * modulate;
}
