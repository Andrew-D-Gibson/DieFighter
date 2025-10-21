shader_type canvas_item;
uniform vec4 tint_color : source_color = vec4(1.0, 0.5, 0.2, 1.0); // Color tint
uniform vec2 speed = vec2(0.0, -0.02);
uniform vec2 pixel_resolution = vec2(320.0, 180.0); // pixelation grid resolution

void fragment() {
	// Pixelate UVs to the target resolution
	vec2 pixelated_uv = floor(UV * pixel_resolution) / pixel_resolution;

	// Sample the noise texture & tint it
	vec4 noise_col = texture(TEXTURE, pixelated_uv + (speed * TIME)) * tint_color;

	// Blend background → noise texture
	COLOR = noise_col;
}