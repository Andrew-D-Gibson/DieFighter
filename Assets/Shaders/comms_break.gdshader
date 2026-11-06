// A comms signal giving out (the Alone ending's "Pilot? ...Pilot?"): what
// the speech bubble is drawn with as the line breaks apart. Built from the
// same ideas as the map's corrupting icon (corrupting_icon.gdshader): stepped
// at a low frame rate so it reads as broken signal rather than smooth fading,
// bands of rows dropping out together, and static pixels. Nothing here
// resamples the bubble's texture, so its pixels stay crisp.
//
// Run the item in a 320x180 art-pixel viewport: the effect works on whole
// pixels of FRAGCOORD, so every fleck is exactly one art pixel.
shader_type canvas_item;

// 0 intact, 1 gone. Tween it.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Glitch frames a second. Low on purpose: choppy reads as a dying signal.
uniform float step_rate = 14.0;
// The static the signal breaks into, and the cold light it flashes before it
// goes. The ending's sky has no Fate in it, so there is no purple here.
uniform vec4 static_color : source_color = vec4(0.808, 0.941, 0.945, 1.0);
uniform vec4 glitch_color : source_color = vec4(0.553, 0.945, 0.957, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	// The whole bubble shudders a pixel or two as it goes: a held breath, then
	// a flinch. Whole pixels only.
	float step_time = floor(TIME * step_rate);
	float flinch = step(0.35, progress) * step(hash(vec2(step_time, 3.1)), progress);
	VERTEX.x += floor(hash(vec2(step_time, 9.7)) * 3.0 - 1.0) * flinch;
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy);
	float step_time = floor(TIME * step_rate);

	// Bands of two to four rows, each with its own luck this frame, so whole
	// slices of the bubble go together while single pixels go on their own.
	float band_height = 2.0 + floor(hash(vec2(step_time, 1.7)) * 3.0);
	float band = floor(px.y / band_height);
	float band_luck = hash(vec2(band, step_time));
	float pixel_luck = hash(px + step_time * 17.0);

	float gone = progress * 1.15 + (band_luck - 0.5) * 0.5 * progress;
	// Untouched until it starts: the bubble is drawn as it always is.
	if (progress > 0.0) {
		if (pixel_luck < gone) {
			COLOR.a = 0.0;
		} else if (pixel_luck < gone + 0.2) {
			// What's about to go flashes to static first.
			vec3 flash = hash(px + step_time) > 0.5 ? static_color.rgb : glitch_color.rgb;
			COLOR.rgb = mix(COLOR.rgb, flash, 0.85);
		}
		// Pixels that were never there fizz in as static for a frame.
		if (COLOR.a < 0.05 && hash(px * 1.3 + step_time * 3.7) > 1.0 - 0.06 * sin(progress * 3.14159)) {
			COLOR = vec4(static_color.rgb, 0.9);
		}
	}
}
