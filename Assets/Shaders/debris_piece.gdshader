shader_type canvas_item;

uniform vec4 color : source_color;
uniform vec4 background_color : source_color;

uniform float velocity_level;      // Passed in from code
uniform float blend_jump = 0.3;     // Maximum blend amount at zero velocity

void fragment() {
	float blend_factor = blend_jump * velocity_level;

	vec4 final_color = mix(background_color, color, blend_factor);
	
	COLOR = vec4(final_color.rgb, COLOR.a);
}
