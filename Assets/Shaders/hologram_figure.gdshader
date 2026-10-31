// The tutorial's computer, drawn as a hologram in the same language as
// holographic dice (holographic_dice_highlight.gdshader): a diagonal band
// sweeps across while each pixel's alpha drifts a little, so the figure
// shimmers like a projected die. On top of that it's tinted a touch toward
// the hologram cyan, faintly scanlined, and now and then a row tears.
// Everything is kept light: the face is 18 pixels across and its eyes and
// mouth are one shade off the skin, so anything heavier than a whisper of
// shimmer or scanline breaks them up and the face stops reading as a face
// that's talking. Its features are pushed a little darker for the same reason.
//
// The sprite sheet draws a bezel around the head. The bezel is its own still
// sprite (computer_bezel.png), so it's cut out here and the head node can bob
// smoothly on its own.
//
// Works on sprite sheets: everything is laid out per frame of frame_size.
shader_type canvas_item;

// One frame of the sheet, in texels.
uniform vec2 frame_size = vec2(20.0, 20.0);
// Outer ring of each frame that's bezel rather than figure.
uniform float bezel = 1.0;

// Shimmer, as on holographic dice.
uniform float min_alpha = 0.93;
uniform float max_alpha = 1.0;
uniform float band_width = 0.2;
// How far out of step each pixel's shimmer is with its neighbours'. At 1 they
// drift independently, a speckle that fights the face's features at this size;
// lower, the shimmer moves over the figure as a whole.
uniform float pixel_drift : hint_range(0.0, 1.0) = 0.25;
uniform float seed = 0.0;

// Stretches the figure's shades away from its lit colour, so the darker
// features (eyes, mouth) stand clear of the face at 18 pixels across. 1 leaves
// the art as drawn.
uniform float feature_contrast = 1.6;
// #43A6FC, the face's lit shade in computer_head-Sheet.png.
uniform vec4 lit_color : source_color = vec4(0.263, 0.651, 0.988, 1.0);

// Approved palette: #8DF1F4, the holographic dice colour.
uniform vec4 holo_color : source_color = vec4(0.553, 0.945, 0.957, 1.0);
uniform float tint = 0.03;
// How much darker every other row is.
uniform float scanline_dim = 0.025;
// Chance a step tears a row, and steps per second.
uniform float glitch_rate : hint_range(0.0, 1.0) = 0.01;
uniform float step_rate = 8.0;

// Modulate, kept apart from the texture so shifted rows resample it cleanly.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 sheet = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = floor(UV * sheet);
	vec2 frame_origin = floor(texel / frame_size) * frame_size;
	vec2 local = texel - frame_origin;

	vec2 source = local;
	float step_time = floor(TIME * step_rate) + seed * 31.0;
	if (rand(vec2(step_time, seed)) < glitch_rate) {
		float torn_row = floor(rand(vec2(step_time, seed + 1.7)) * frame_size.y);
		if (local.y == torn_row) {
			source.x += rand(vec2(step_time, seed + 2.3)) < 0.5 ? -1.0 : 1.0;
		}
	}

	bool inside = source.x >= bezel && source.y >= bezel
			&& source.x < frame_size.x - bezel && source.y < frame_size.y - bezel;
	vec4 color = inside
			? texture(TEXTURE, (frame_origin + source + 0.5) / sheet)
			: vec4(0.0);

	// The holographic dice shimmer, on the figure's own pixel grid.
	vec2 cell = source / frame_size;
	float wave = sin((cell.x + cell.y) * 3.0 - (TIME + seed) * 3.0);
	float mask = smoothstep(-band_width, band_width, wave);
	float base_random = rand(cell + vec2(seed));
	float drift = (sin((TIME + seed) + base_random * 2.0 * pixel_drift) + 1.0) * 0.5;
	color.a *= mix(max_alpha, min_alpha, drift * mask);

	color.rgb = clamp(mix(lit_color.rgb, color.rgb, feature_contrast), 0.0, 1.0);
	color.rgb = mix(color.rgb, holo_color.rgb, tint);
	if (mod(local.y, 2.0) < 1.0) {
		color.rgb *= 1.0 - scanline_dim;
	}
	COLOR = color * modulate;
}
