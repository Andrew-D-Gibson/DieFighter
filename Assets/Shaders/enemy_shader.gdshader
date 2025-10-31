shader_type canvas_item;

uniform float alpha : hint_range(0.0, 1.0) = 0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

uniform float cloak_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec4 cloak_key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // chosen color in sprite
uniform vec4 cloak_main_color : source_color = vec4(0.0, 0.1, 0.6, 1.0); // dark blue
uniform vec4 cloak_bg_color   : source_color = vec4(0.4, 0.8, 1.0, 0.2); // light blue transparent
uniform float cloak_tolerance : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	// Sample sprite texture
	vec4 tex_color = texture(TEXTURE, UV);

	// Apply flash effect
	vec4 flash_color_mix = mix(tex_color, vec4(flash_color.rgb, tex_color.a), flash_amount);

	// Cloak mapping
	float diff = distance(tex_color.rgb, cloak_key_color.rgb);
	vec4 cloaked_color = (diff < cloak_tolerance)
		? vec4(cloak_main_color.rgb, tex_color.a * cloak_main_color.a)
		: vec4(cloak_bg_color.rgb, tex_color.a * cloak_bg_color.a);

	// Mix uncloaked vs cloaked
	vec4 final_color = mix(flash_color_mix, cloaked_color, cloak_amount);

	// Apply global alpha override
    final_color.a *= alpha;

	COLOR = final_color;
}
