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


static func is_readable() -> bool:
	var wrapper: FontVariation = _SWAPS.keys()[0]
	return wrapper.base_font == _SWAPS[wrapper][1]


static func set_readable(readable: bool) -> void:
	for wrapper: FontVariation in _SWAPS:
		var font: Font = _SWAPS[wrapper][1 if readable else 0]
		if wrapper.base_font != font:
			wrapper.base_font = font


## The wrappers the game's text goes through, for tests.
static func wrappers() -> Array[FontVariation]:
	return _SWAPS.keys()


## The font [param wrapper] shows with Readable Font off or on, for tests.
static func font_for(wrapper: FontVariation, readable: bool) -> Font:
	return _SWAPS[wrapper][1 if readable else 0]
