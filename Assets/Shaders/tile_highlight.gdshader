shader_type canvas_item;

uniform sampler2D vertical_gradient; // Used to set alpha values
uniform sampler2D color_gradient; // Sets the effect color
uniform float size_effect: hint_range(1.0, 10.0, 1.0) = 1.0; // Size of the effect in pixel units
uniform float speed = 1; // Effect speed
uniform float highlight_strength: hint_range(-4.0, 4.0, 0.05) = 0.5; // Strength of the highlight
uniform bool color_mode_toggle = false; // Toggle for color gradient application
uniform float pause_duration = 0.5; // Pause duration between cycles
uniform vec2 texture_size = vec2(16, 16); // Texture size in pixels

// Brightness oscillation parameters
uniform float brightness_max: hint_range(1.0, 3.0, 0.01) = 1.5; // Max brightness
uniform float brightness_period: hint_range(0.1, 10.0, 0.01) = 2.0; // Seconds per full oscillation

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Sample what's already drawn behind this shader
    vec4 old_color = texture(SCREEN_TEXTURE, SCREEN_UV);

    // Time logic for highlight movement
    float time = TIME * abs(speed);
    float effect_cycle_duration = 1.0 + pause_duration;
    float mod_time = mod(time, effect_cycle_duration);
    float progress = mod_time / 1.0;

    if (mod_time > 1.0) {
        progress = 1.0; // Hold during pause
    }

    if (speed < 0.0) {
        progress = 1.0 - progress;
    }

    // Convert size_effect from pixels to UV space (diagonal movement uses both x and y)
    float pixel_to_uv_x = size_effect / texture_size.x;
    float pixel_to_uv_y = size_effect / texture_size.y;

    // Current diagonal position (0 to 1 along both axes)
    vec2 current_position = vec2(progress, progress);

    // Bounds for the diagonal effect
    vec2 effect_lower_bound = current_position - vec2(pixel_to_uv_x / 2.0, pixel_to_uv_y / 2.0);
    vec2 effect_upper_bound = current_position + vec2(pixel_to_uv_x / 2.0, pixel_to_uv_y / 2.0);

    // Snap to pixel grid
    vec2 pixel_size_uv = vec2(1.0) / texture_size;
    vec2 snapped_uv = floor(UV / pixel_size_uv) * pixel_size_uv;

    // Distance along the diagonal
    float diag_pos = (snapped_uv.x + snapped_uv.y) * 0.5;

    // Crisp highlight edges along the diagonal
    float effect_distance = step(effect_lower_bound.x, diag_pos) - step(effect_upper_bound.x, diag_pos);

    // Color gradient sampling
    float inner_effect_position = step(effect_lower_bound.x, diag_pos) * step(diag_pos, effect_upper_bound.x);
    vec2 color_position = (color_mode_toggle) ? vec2(UV.x, inner_effect_position) : vec2(progress);
    vec4 new_color = texture(color_gradient, color_position);
    new_color = mix(old_color, new_color, texture(vertical_gradient, vec2(progress)));

    // Apply highlight effect
    vec3 final_rgb = mix(old_color.rgb, new_color.rgb, vec3(effect_distance * highlight_strength));

    // Oscillating brightness multiplier
    float osc = (sin(TIME * (2.0 * 3.14159 / brightness_period)) * 0.5 + 0.5);
    float brightness_boost = mix(1.0, brightness_max, osc);

    final_rgb *= brightness_boost;

    COLOR = vec4(final_rgb, 1.0);
}
