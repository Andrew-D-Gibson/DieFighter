shader_type canvas_item;

uniform vec2 speed = vec2(0.0, -0.02);
uniform vec4 nebula_color; // = vec4(0.2, 0.4, 1.0, 0.1); // Blueish nebula color

void fragment() {
    //vec2 uv = UV + TIME * speed;

    float noise = texture(TEXTURE, UV + (speed * TIME)).r;
	float low_step = step(0.4, noise);
	float mid_step = step(0.6, noise);
	float high_step = step(0.8, noise);

	vec4 low_color = low_step * nebula_color;
	vec4 mid_color = mid_step * nebula_color;
	vec4 high_color = high_step * nebula_color;

    COLOR = low_color + mid_color + high_color;
}
