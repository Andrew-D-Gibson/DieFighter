// The border between Fate's corrupted zone and the danger zone it's about to
// take. Both zones stop short of the border and this strip owns the gap: the
// corrupted tint left of a wavy line, the danger tint right of it, and a hot
// line along the wave itself, so the front reads as alive and advancing.
//
// Snapped to whole texels so it stays crisp pixel art.
shader_type canvas_item;

uniform vec4 left_color : source_color = vec4(0.502, 0.208, 0.616, 0.149);
uniform vec4 right_color : source_color = vec4(0.565, 0.149, 0.235, 0.263);
uniform vec4 edge_color : source_color = vec4(0.85, 0.25, 0.65, 0.8);
// How far, in texels, the wave swings either side of the strip's centre.
uniform float amplitude = 2.0;
uniform float speed = 3.0;

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = floor(UV * size);

	// Two out-of-step sines, so the wave never settles into an obvious loop.
	float wave = sin(texel.y * 0.35 + TIME * speed) * 0.6
		+ sin(texel.y * 0.13 - TIME * speed * 0.55) * 0.4;
	float edge_x = floor(size.x * 0.5) + round(wave * amplitude);

	vec4 color = texel.x < edge_x ? left_color : right_color;
	if (texel.x == edge_x) {
		float flicker = 0.75 + 0.25 * sin(TIME * 7.0 + texel.y * 0.5);
		color = vec4(edge_color.rgb, edge_color.a * flicker);
	}
	COLOR = color;
}
