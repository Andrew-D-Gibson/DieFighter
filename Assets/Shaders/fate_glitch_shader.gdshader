shader_type canvas_item;

// --- General Uniforms ---
uniform vec2 pixel_resolution = vec2(160.0, 90.0); // pixelation grid resolution

// --- Distortion Uniforms ---
uniform float wave_frequency : hint_range(0.0, 50.0) = 15.0; // Number of waves across the sprite
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.01; // Strength of the wave distortion
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0; // Speed of the wave animation

// --- Color Effect Uniforms (driven by NoiseTexture2D) ---
uniform sampler2D noise_texture; // Texture to control color change
uniform vec4 effect_color : source_color = vec4(0.8, 0.2, 1.0, 1.0); // Color to apply
uniform float color_noise_speed : hint_range(0.0, 10.0) = 0.5; // Speed of the color noise scrolling
uniform float color_noise_scale : hint_range(0.1, 10.0) = 1.0; // Tiling/scale of the noise texture
uniform float color_threshold : hint_range(0.0, 1.0) = 0.5; // Base threshold for the color change
uniform float color_intensity : hint_range(0.0, 1.0) = 0.5; // Softness of the color transition
uniform bool invert_color = false; // Invert the color change pattern

// --- Transparency Effect Uniforms (driven by procedural noise) ---
uniform float alpha_noise_speed : hint_range(0.0, 10.0) = 0.8; // Speed of the transparency noise
uniform float alpha_noise_scale : hint_range(0.1, 10.0) = 3.0; // Scale of the transparency noise
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5; // Base visibility threshold
uniform float alpha_intensity : hint_range(0.0, 1.0) = 0.4; // Softness of the transparency fade
uniform bool invert_alpha = false; // Invert visible vs transparent regions

// Simple hash-based noise function (for transparency effect)
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// Noise generation function (for transparency effect)
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// --- 1. Wavy Distortion ---
	vec2 distorted_uv = UV;
	distorted_uv.x += sin(distorted_uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude;
	
	// --- 2. Pixelation ---
	vec2 pixelated_uv = floor(distorted_uv * pixel_resolution) / pixel_resolution;

	// --- 3. Texture Sampling ---
	vec4 tex_color = texture(TEXTURE, pixelated_uv);

	// --- 4. Color Blending (from Noise Texture) ---
	// Calculate scrolling UVs for the noise texture.
	vec2 color_noise_uv = UV * color_noise_scale + TIME * color_noise_speed;
	// Sample the noise texture (we only need one channel, e.g., 'r').
	float color_n = texture(noise_texture, color_noise_uv).r;
	
	// Create a mask from the noise texture to determine where the color change happens.
	float effect_mask = smoothstep(color_threshold - color_intensity, color_threshold + color_intensity, color_n);
	if (invert_color) {
		effect_mask = 1.0 - effect_mask;
	}
	vec3 final_rgb = mix(tex_color.rgb, effect_color.rgb, effect_mask);
	
	// --- 5. Transparency (from Procedural Noise) ---
	// Calculate a second, independent noise pattern for the alpha.
	float t = TIME * alpha_noise_speed;
	float alpha_n = noise(UV * alpha_noise_scale + vec2(t, t * 0.7));
	
	// Create the alpha mask.
	float alpha_mod = smoothstep(alpha_threshold - alpha_intensity, alpha_threshold + alpha_intensity, alpha_n);
	if (invert_alpha) {
		alpha_mod = 1.0 - alpha_mod;
	}
	
	// --- 6. Final Output ---
	COLOR.rgb = final_rgb;
	// Apply the procedural alpha mask to the texture's original alpha.
	COLOR.a = tex_color.a * alpha_mod;
}

