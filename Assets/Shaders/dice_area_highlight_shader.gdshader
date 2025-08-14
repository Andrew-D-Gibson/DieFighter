shader_type canvas_item;

uniform float pulse_speed : hint_range(0.1, 10.0) = 2.0; // Pulses per second
uniform float pulse_strength : hint_range(0.0, 5.0) = 1.5; // Max brightness boost
uniform float base_strength : hint_range(0.0, 5.0) = 1.0; // Base brightness multiplier

void fragment() {
	// Get the base texture color
	vec4 tex_color = texture(TEXTURE, UV);

	// Sinusoidal pulse value from 0 to 1
	float pulse = (sin(TIME * pulse_speed * 6.28318) * 0.5) + 0.5;

	// Apply brightness multiplier
	float brightness = base_strength + pulse * pulse_strength;
	vec4 final_color = tex_color * brightness;

	// Output color (can go above 1.0 for bloom)
	COLOR = final_color;
}
