// The Ion Storm Front's nebula. The standard nebula is one colour in three
// flat steps; this is a storm front: thick banks of cloud stepped through the
// palette's navies and blues, threaded with bright ion filaments, its edges
// slowly crawling. IonStorm lights it from inside through the global
// ion_flash, so a strike just off screen still shows, as glow on the near
// cloud.
//
// Drop-in for sprite_nebula.gdshader on the nebula sprite (same uv_offset and
// nebula_color uniforms). The sprite's noise texture maps one texel to one
// art pixel, and every band edge is ordered-dithered in texel space, so it
// stays pixel art and the dither scrolls with the cloud.
shader_type canvas_item;

uniform float uv_offset = 0.0;
// Set by BackgroundManager from the background's nebula_color. Only its alpha
// is read: how opaque the whole front is.
uniform vec4 nebula_color = vec4(1.0);
// Small seamless noise for the filaments and the slow churn of the edges.
uniform sampler2D detail_noise : repeat_enable, filter_nearest;
// Art pixels per second the cloud edges crawl, independent of the scroll.
uniform float churn_speed = 0.8;

// Cloud density (0-1) at which each band starts, thinnest to thickest.
uniform vec4 thresholds = vec4(0.45, 0.53, 0.61, 0.69);
// How far a full-strength flash lifts the cloud's density at its centre.
uniform float flash_lift = 0.3;
// Ridge sharpness a filament needs; nearer 1 is thinner.
uniform float filament_threshold : hint_range(0.8, 1.0) = 0.965;

// Approved palette: #191347, #251C6B, #2C71AA, #3789CC, #43A6FC, #8DF1F4.
uniform vec4 band_1 : source_color = vec4(0.098, 0.075, 0.278, 0.5);
uniform vec4 band_2 : source_color = vec4(0.145, 0.110, 0.420, 0.7);
uniform vec4 band_3 : source_color = vec4(0.173, 0.443, 0.667, 0.75);
uniform vec4 band_4 : source_color = vec4(0.216, 0.537, 0.800, 0.8);
uniform vec4 filament_color : source_color = vec4(0.263, 0.651, 0.988, 0.85);
uniform vec4 lit_color : source_color = vec4(0.553, 0.945, 0.957, 0.9);

// xy: the flash's centre in screen art pixels (may be off screen);
// z: strength 0-1; w: radius in art pixels.
global uniform vec4 ion_flash;

varying vec2 world_px;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);


float bayer(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	return (BAYER[q.y * 4 + q.x] + 0.5) / 16.0;
}


float detail(vec2 texel) {
	return texture(detail_noise, texel / vec2(textureSize(detail_noise, 0))).r;
}


void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = floor((UV + vec2(0.0, uv_offset)) * size);
	float drift = TIME * churn_speed;

	// The big banks come from the sprite's own noise, pushed about by a
	// slowly drifting detail field so their edges boil.
	float warp = detail(texel * 0.5 + vec2(drift, 0.0)) - 0.5;
	// Two banks from opposite corners of the texture, so the front is never
	// thin for long as it scrolls.
	vec2 warped = texel + vec2(warp * 28.0, warp * 12.0) + 0.5;
	float body = max(texture(TEXTURE, warped / size).r,
			texture(TEXTURE, (warped + size * vec2(0.5, 0.5)) / size).r * 0.88);
	float grain = detail(texel + vec2(0.0, drift)) - 0.5;
	float density = body * 0.9 + grain * 0.18;

	float lit = 0.0;
	if (ion_flash.z > 0.0) {
		float reach = distance(floor(world_px), ion_flash.xy) / max(ion_flash.w, 1.0);
		lit = ion_flash.z * smoothstep(1.0, 0.2, reach);
	}
	float level = density + lit * flash_lift + (bayer(texel) - 0.5) * 0.035;

	vec4 color = vec4(0.0);
	if (level > thresholds.w) {
		color = band_4;
	} else if (level > thresholds.z) {
		color = band_3;
	} else if (level > thresholds.y) {
		color = band_2;
	} else if (level > thresholds.x) {
		color = band_1;
	}

	// Ion filaments: thin ridges of a second field, only inside thick cloud.
	float ridge = 1.0 - abs(detail(texel * 0.75 + vec2(-drift, drift * 0.5) + 37.0) * 2.0 - 1.0);
	if (level > thresholds.z && ridge > filament_threshold - lit * 0.04) {
		color = lit > 0.3 ? lit_color : filament_color;
	}

	COLOR = vec4(color.rgb, color.a * nebula_color.a);
}
