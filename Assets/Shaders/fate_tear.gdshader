// Fate tearing through the sky: ragged horizontal bands of void crawling
// with static, the screen-sized cousin of the row tears in
// corrupting_icon.gdshader. coverage 0 shows nothing; 1 swallows every band.
//
// For a ColorRect laid over a 320x180 art-pixel scene. Snapped to whole art
// pixels and stepped at a low rate so it reads as broken signal.
shader_type canvas_item;

uniform vec2 resolution = vec2(320.0, 180.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float step_rate = 14.0;
// Share of void pixels lit with static.
uniform float static_density : hint_range(0.0, 1.0) = 0.12;

// Approved palette: #000000, #A846CE, #C552F1, #CEF0F1.
uniform vec4 void_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 static_color : source_color = vec4(0.659, 0.275, 0.808, 1.0);
uniform vec4 hot_color : source_color = vec4(0.773, 0.322, 0.945, 1.0);
uniform vec4 spark_color : source_color = vec4(0.808, 0.941, 0.945, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 texel = floor(UV * resolution);
	float step_time = floor(TIME * step_rate) + seed * 31.0;

	// Bands of a few rows each; which tear, and how far across, changes
	// every step so the tears flicker rather than sit still.
	float band_height = 2.0 + floor(hash(vec2(seed, 1.7)) * 4.0);
	float band = floor(texel.y / band_height);
	bool torn = hash(vec2(band, step_time)) < coverage;
	float start = floor(hash(vec2(band + 0.5, step_time)) * resolution.x * 0.7);
	float span = resolution.x * mix(0.2, 1.0, hash(vec2(band + 0.25, step_time)));
	// At full coverage the tear owns the whole width.
	start *= 1.0 - coverage * coverage;
	span = mix(span, resolution.x, coverage * coverage);
	torn = torn && texel.x >= start && texel.x < start + span;

	if (!torn) {
		COLOR = vec4(0.0);
	} else {
		vec3 rgb = void_color.rgb;
		float noise = hash(texel + vec2(step_time * 0.37, seed));
		if (noise > 1.0 - static_density) {
			rgb = static_color.rgb;
		}
		if (noise > 1.0 - static_density * 0.35) {
			rgb = hot_color.rgb;
		}
		if (noise > 0.997) {
			rgb = spark_color.rgb;
		}
		COLOR = vec4(rgb, 1.0);
	}
}
