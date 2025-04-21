shader_type canvas_item;

uniform vec2 pixel_size;
uniform float min_alpha = 0.3;
uniform float max_alpha = 0.9;
uniform vec4 target_color : source_color; // Color to match
uniform float color_tolerance = 0.05;     // How close the color must be
uniform float line_width = 0.05; // Diagonal effect width (UV space, try 0.05–0.2)

uniform float seed = 0.0;        // Unique value per instance (set in the material)


float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Snap to visual pixel grid
	vec2 snapped_uv = floor(UV / pixel_size) * pixel_size;

	// Diagonal position = UV.x + UV.y (gives stripes along diagonals)
	float diag_pos = snapped_uv.x + snapped_uv.y;

	// Animate diagonal using time
	float wave = sin(diag_pos * 3.0 - (TIME + seed) * 3.0); // speed and frequency increased
	float mask = smoothstep(-line_width, line_width, wave); // creates a soft diagonal band

	// Generate a per-block random fade
	float base_random = rand(snapped_uv + vec2(seed, seed));
	float time_variation = sin((TIME + seed) * 1.0 + base_random * 2.0);
	float alpha_variation = (time_variation + 1.0) * 0.5;

	// Mix between full opacity and min_alpha, modulated by both mask and randomness
	float adjusted_alpha = mix(max_alpha, min_alpha, alpha_variation * mask);
	
	
	// Check if pixel color is close to the target color
	float diff = distance(tex_color.rgb, target_color.rgb);

	if (diff < color_tolerance) {
		// Pixel matches the target color — apply fading with min alpha clamp
		tex_color.a *= adjusted_alpha;
	}

	COLOR = tex_color;
}
