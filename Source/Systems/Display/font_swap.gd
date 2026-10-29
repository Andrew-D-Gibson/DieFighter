class_name FontSwap
extends RefCounted
## The Readable Font option: swaps the game's pixel fonts for Atkinson
## Hyperlegible Next, a sans designed for low-vision readers, everywhere at
## once and while the game runs.
##
## Nothing in the game uses m3x6.ttf or m5x7.ttf directly. The theme, scene
## overrides and scripts that draw_string all hold a FontVariation wrapper per
## pixel font (m3x6_ui.tres, m5x7_ui.tres), and swapping is setting each
## wrapper's base_font. Every holder sees the change, and Controls re-lay out
## because the wrapper emits `changed`. Swapping back restores the very same
## FontFile, so the pixel look returns exactly. New text must use a wrapper
## too: test_font_swap.gd fails on a direct reference to a pixel font file.
##
## Font sizes stay as they are. Each readable font was rescaled once by
## tools/fit_readable_font.py to cover its pixel font's footprint at the same
## size (same line height and baseline, same width of mixed-case text), so the
## sizes chosen for the pixel fonts all still fit. All-caps text runs about a
## fifth wider than in the narrow pixel fonts.
##
## Each readable font also rides a little higher or lower than its pixel
## font, so its capitals centre where the pixel font's do (see
## _CAP_CENTRE_OFFSETS): every label box laid out for the pixel fonts then
## frames the readable text just as squarely.
##
## The readable fonts import as MSDF at msdf_size 192. The game samples every
## texture with nearest filtering, and at the stock 64 a glyph's field texels
## came out bigger than a screen pixel (a size-16 em is 96 screen pixels
## through the 6x camera), which left stair-stepped, uneven strokes.
##
## Other languages: fonts for scripts these lack (CJK, Cyrillic) belong in
## each wrapper's `fallbacks`, which apply whichever base font is in, fitted
## with the same tool so their sizes match too. A language that needs its own
## primary font can set it as the readable entry's replacement here.

## Per wrapper: [the pixel font it normally shows, its readable replacement].
const _SWAPS: Dictionary[FontVariation, Array] = {
	preload("res://Assets/Fonts/m3x6/m3x6_ui.tres"): [
		preload("res://Assets/Fonts/m3x6/m3x6.ttf"),
		preload("res://Assets/Fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext-Medium-m3x6.ttf"),
	],
	preload("res://Assets/Fonts/m5x7/m5x7_ui.tres"): [
		preload("res://Assets/Fonts/m5x7/m5x7.ttf"),
		preload("res://Assets/Fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext-Medium-m5x7.ttf"),
	],
}

## Per wrapper: the readable font's FontVariation.baseline_offset (a fraction
## of the line height; negative is up) that puts its capitals' centre on the
## pixel font's. Measured offline at sizes 16 and 32: Atkinson's capitals are
## shorter than m3x6's and taller than m5x7's, both sitting on the baseline.
const _CAP_CENTRE_OFFSETS: Dictionary[FontVariation, float] = {
	preload("res://Assets/Fonts/m3x6/m3x6_ui.tres"): -0.055,
	preload("res://Assets/Fonts/m5x7/m5x7_ui.tres"): 0.026,
}


static func is_readable() -> bool:
	var wrapper: FontVariation = _SWAPS.keys()[0]
	return wrapper.base_font == _SWAPS[wrapper][1]


static func set_readable(readable: bool) -> void:
	for wrapper: FontVariation in _SWAPS:
		var font: Font = _SWAPS[wrapper][1 if readable else 0]
		if wrapper.base_font != font:
			wrapper.base_font = font
		var offset: float = baseline_offset_for(wrapper, readable)
		if not is_equal_approx(wrapper.baseline_offset, offset):
			wrapper.baseline_offset = offset


## The wrappers the game's text goes through, for tests.
static func wrappers() -> Array[FontVariation]:
	return _SWAPS.keys()


## The baseline offset [param wrapper] wears with Readable Font off or on,
## for tests.
static func baseline_offset_for(wrapper: FontVariation, readable: bool) -> float:
	return _CAP_CENTRE_OFFSETS[wrapper] if readable else 0.0


## The font [param wrapper] shows with Readable Font off or on, for tests.
static func font_for(wrapper: FontVariation, readable: bool) -> Font:
	return _SWAPS[wrapper][1 if readable else 0]
