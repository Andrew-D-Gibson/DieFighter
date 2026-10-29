shader_type canvas_item;

uniform float outer_radius : hint_range(0.0, 10.0) = 10.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

uniform bool highlight_enabled = false;
uniform sampler2D vertical_gradient; // Used to set alpha values
uniform sampler2D color_gradient;    // Sets the effect color
uniform float size_effect: hint_range(1.0, 10.0, 1.0) = 1.0;
uniform float speed = 1.0;
uniform float highlight_strength: hint_range(-4.0, 4.0, 0.05) = 0.5;
uniform float pause_duration = 0.5;
uniform vec2 texture_size = vec2(24.0, 24.0);

uniform float brightness_max: hint_range(1.0, 3.0, 0.01) = 1.5;
uniform float brightness_period: hint_range(0.1, 10.0, 0.01) = 2.0;

uniform float time_offset = 0.0;

// Solid-colour flash laid over everything else, driven by Tile.flash().
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

// An upgraded tile: two bright bands chase round its border and spill a pixel
// past it, and the border breathes. Every tile shares one 22x24 rounded
// silhouette, so the border is worked out here rather than drawn into the art.
uniform bool upgraded = false;
uniform vec4 upgrade_color : source_color = vec4(0.808, 0.941, 0.945, 1.0);
uniform float upgrade_speed = 0.35;

bool in_silhouette(vec2 p) {
	if (p.x < 1.0 || p.x > 22.0 || p.y < 0.0 || p.y > 23.0) return false;
	if ((p.y < 1.0 || p.y > 22.0) && (p.x < 3.0 || p.x > 20.0)) return false;
	if ((p.y < 2.0 || p.y > 21.0) && (p.x < 2.0 || p.x > 21.0)) return false;
	return true;
}

int silhouette_neighbours(vec2 p) {
	return int(in_silhouette(p + vec2(1.0, 0.0))) + int(in_silhouette(p - vec2(1.0, 0.0)))
		+ int(in_silhouette(p + vec2(0.0, 1.0))) + int(in_silhouette(p - vec2(0.0, 1.0)));
}

// How lit the chasing bands are at tile pixel p: 1 inside a band, else 0.
float upgrade_bands(vec2 p) {
	float angle = atan(p.y - 11.5, p.x - 11.5) / 6.28318 + 0.5;
	float t = fract(angle - TIME * upgrade_speed);
	return step(t, 0.07) + step(0.5, t) * step(t, 0.57);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Grayscale fade
	float x = abs(UV.x - 1.0) * 2.0;
	float y = abs(UV.y - 1.0) * 2.0;
	float v = sqrt(x * x + y * y) / outer_radius;
	v = clamp(v, 0.0, 1.0);

	float adjusted_v = v * strength;
	vec3 gray = vec3(dot(tex_color.rgb, vec3(0.299, 0.587, 0.114)));
	vec3 final_color = mix(gray, tex_color.rgb, 1.0 - adjusted_v);

	if (highlight_enabled) {
		// Brightness oscillation
		float osc = (sin(TIME * (2.0 * 3.14159 / brightness_period)) * 0.5 + 0.5);
		float brightness_boost = mix(1.0, brightness_max, osc);
		final_color *= brightness_boost;

		// Highlight movement timing
		float time = (TIME + time_offset) * abs(speed);
		float effect_cycle_duration = 1.0 + pause_duration;
		float mod_time = mod(time, effect_cycle_duration);
		float progress = mod_time / 1.0;
		if (mod_time > 1.0) {
			progress = 1.0; // pause
		}
		if (speed < 0.0) {
			progress = 1.0 - progress;
		}

		// Convert size_effect from pixels to UV space
		float pixel_to_uv_x = size_effect / texture_size.x;

		// Diagonal position
		vec2 current_position = vec2(progress, progress);
		vec2 effect_lower_bound = current_position - vec2(pixel_to_uv_x * 0.5);
		vec2 effect_upper_bound = current_position + vec2(pixel_to_uv_x * 0.5);

		// Snap to pixel grid
		vec2 pixel_size_uv = 1.0 / texture_size;
		vec2 snapped_uv = floor(UV / pixel_size_uv) * pixel_size_uv;

		// Distance along diagonal
		float diag_pos = (snapped_uv.x + snapped_uv.y) * 0.5;

		// Crisp highlight mask
		float effect_distance = step(effect_lower_bound.x, diag_pos) - step(effect_upper_bound.x, diag_pos);

		// Gradient-based highlight
		vec4 grad_color = texture(color_gradient, vec2(progress, 0.5));
		float grad_alpha = texture(vertical_gradient, vec2(progress, 0.5)).r;

		// Blend final highlight into base color
		final_color = mix(final_color, grad_color.rgb, effect_distance * highlight_strength * grad_alpha);
	}

	float alpha = tex_color.a;
	if (upgraded) {
		// Tile frames are 24px cells of a horizontal strip, so the pixel
		// within this frame is the atlas pixel modulo the cell.
		vec2 p = floor(mod(UV / TEXTURE_PIXEL_SIZE, texture_size));
		bool inside = in_silhouette(p);
		int neighbours = silhouette_neighbours(p);
		float bands = upgrade_bands(p);
		if (inside && neighbours < 4) {
			float breathe = 0.2 + 0.15 * sin(TIME * 3.0);
			final_color = mix(final_color, upgrade_color.rgb, clamp(bands * 0.9 + breathe, 0.0, 1.0));
		} else if (!inside && neighbours > 0) {
			final_color = upgrade_color.rgb;
			alpha = max(alpha, bands * 0.85);
		}
	}

	final_color = mix(final_color, flash_color.rgb, flash_amount);

	COLOR.rgb = final_color;
	COLOR.a = alpha;
}
