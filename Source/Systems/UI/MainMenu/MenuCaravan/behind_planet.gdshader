shader_type canvas_item;
// Hides whatever this draws where the planet's disc is, for ships on the
// far side of it.

uniform vec2 planet_center;
uniform float planet_radius;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	if (distance(local_position, planet_center) < planet_radius) {
		discard;
	}
}
