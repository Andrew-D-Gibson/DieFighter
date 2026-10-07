shader_type canvas_item;
// A ring of refraction that races out from `center`, splitting red and blue
// at its edge. Everything on screen is read back and bent, UI included.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 center = vec2(0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 0.03;
uniform float band_width = 0.07;
uniform float aspect = 1.7778;
uniform float aberration = 0.006;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_pixel = uv - center;
	to_pixel.x *= aspect;
	float dist = length(to_pixel);
	float radius = progress * 0.85;
	float band = 1.0 - smoothstep(0.0, band_width, abs(dist - radius));
	float fade = 1.0 - progress;
	vec2 dir = dist > 0.0001 ? to_pixel / dist : vec2(0.0);
	dir.x /= aspect;

	vec2 bent = uv - dir * band * strength * fade;
	vec2 split = dir * aberration * band * fade;
	COLOR = vec4(
		texture(screen_texture, bent + split).r,
		texture(screen_texture, bent).g,
		texture(screen_texture, bent - split).b,
		1.0
	);
}
