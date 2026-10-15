shader_type canvas_item;

uniform vec4 color : source_color;
uniform vec4 background_color : source_color;
uniform bool keep_texture_colors = false;

uniform float velocity_level;      // Passed in from code; nearer pieces are higher
uniform float base_visibility = 0.0;
uniform float visibility_per_depth = 0.1;

void fragment() {
	float visibility = clamp(base_visibility + visibility_per_depth * velocity_level, 0.0, 1.0);
	vec3 own_color = keep_texture_colors ? COLOR.rgb : color.rgb;

	COLOR = vec4(mix(background_color.rgb, own_color, visibility), COLOR.a);
}
