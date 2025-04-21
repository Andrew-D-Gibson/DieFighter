shader_type canvas_item;

uniform float outer_radius : hint_range(0.0, 10.0) = 10.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    float x = abs(UV.x - 1.0) * 2.0;
    float y = abs(UV.y - 1.0) * 2.0;
    float v = sqrt(x * x + y * y) / outer_radius;
    v = clamp(v, 0.0, 1.0);

    float adjusted_v = v * strength;

    vec3 gray = vec3(dot(tex_color.rgb, vec3(0.299, 0.587, 0.114)));
    vec3 final_color = mix(gray, tex_color.rgb, 1.0 - adjusted_v);

    COLOR.rgb = final_color;
    COLOR.a = tex_color.a;
}
