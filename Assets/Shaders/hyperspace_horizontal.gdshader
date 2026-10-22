shader_type canvas_item;
// Hyperspace for a sideways jump: rows of light, one art pixel tall, streaming
// past at their own speeds. jump_hyperspace.gdshader pixelates its UVs into
// screen-sized cells before scrolling them, so a cell edge stands still on
// screen as a hard seam. This scrolls the noise continuously and only snaps
// to the art grid where it reads it, so nothing on screen stays put.

uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.263, 0.651, 0.988, 1.0);
uniform sampler2D noise : repeat_enable, filter_nearest;
uniform vec2 pixel_resolution = vec2(320.0, 180.0);
// Noise texture widths per second.
uniform float speed = 1.2;
// How much of the noise's width one screen spans. Smaller is longer streaks.
uniform float streak_scale = 0.12;
// How much the rows differ in speed, as a fraction of `speed`.
uniform float speed_spread = 0.6;

float row_hash(float row) {
	return fract(sin(row * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * pixel_resolution);
	float row_speed = speed * (1.0 - speed_spread * 0.5 + speed_spread * row_hash(cell.y));
	vec2 noise_uv = vec2(
		cell.x / pixel_resolution.x * streak_scale + TIME * row_speed,
		(cell.y + 0.5) / pixel_resolution.y
	);
	vec4 streak = texture(noise, noise_uv) * tint_color;
	COLOR = vec4(streak.rgb, alpha);
}
