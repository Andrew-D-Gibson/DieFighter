shader_type canvas_item;

uniform vec3 dark_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 bright_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float speed = 1.0;
uniform vec2 static_resolution = vec2(64, 64); // Number of pixels across

void fragment() {
	// UVs relative to the node
	vec2 uv = UV;
	
	// Snap UVs to static_resolution grid
	vec2 pixelated_uv = floor(uv * static_resolution) / static_resolution;
	
	// Generate noise based on pixelated position and time
	float noise = fract(sin(dot(pixelated_uv * TIME * speed, vec2(12.9898, 78.233))) * 43758.5453);

	// Interpolate between dark and bright colors based on noise
	COLOR = vec4(mix(dark_color, bright_color, noise), COLOR.a);
}
