shader_type canvas_item;

uniform float alpha: hint_range(0.0, 1.0) = 0;
uniform vec4 tint_color : source_color = vec4(1.0, 0.5, 0.2, 1.0); // Color tint
uniform vec2 speed = vec2(0.0, -0.02); // Scrolling direction & speed
uniform vec2 pixel_resolution = vec2(320.0, 180.0); // Pixelation grid resolution

void fragment() {
    // Pixelate UVs to the target resolution
    vec2 pixelated_uv = floor(UV * pixel_resolution) / pixel_resolution;

    // Scroll and wrap UVs for infinite looping
    vec2 scrolling_uv = fract(pixelated_uv + speed * TIME);

    // Sample the noise texture & tint it
    vec4 noise_col = texture(TEXTURE, scrolling_uv) * tint_color;

    // Output color
    COLOR = noise_col;
	COLOR.a = alpha;
}
