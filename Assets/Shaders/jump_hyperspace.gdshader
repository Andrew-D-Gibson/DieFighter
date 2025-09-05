shader_type canvas_item;

uniform float bulge : hint_range(-1, 1);
uniform float shrink_progress : hint_range(0.0, 1.0) = 0.0; // 0 = no pull, 1 = fully collapsed
uniform vec4 shift_color : source_color;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float bulge_function(float y) {
	return sqrt(1.0 - y*y);
}

void fragment() {
    // Collapse toward center
    vec2 uv = UV;
	uv -= vec2(0.5, 0.5);
	
	// Shrink
	uv = uv + (normalize(uv) * shrink_progress);
	float dist = length(uv);
	
	// Bulge
	float displacement = 1.0 + bulge * bulge_function(uv.y);
	uv.x /= displacement;
	
	uv += vec2(0.5, 0.5);

    // Sample screen or show black outside
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
		vec4 color = texture(SCREEN_TEXTURE, uv);
        COLOR = mix(color, shift_color, max(shrink_progress / (2.0 * dist), 0.0));
    }
}
