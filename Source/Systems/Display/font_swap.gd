class_name FontSwap
extends RefCounted
## The Readable Font option: swaps the game's pixel fonts for Atkinson
## Hyperlegible Next, a sans designed for low-vision readers, everywhere at
## once and while the game runs.
##
## Nothing in the game uses a font file directly: text draws through one
## FontVariation wrapper per font role (see FontRoles), and swapping is
## FontRoles setting each wrapper's base font. Every holder sees the change,
## and Controls re-lay out because the wrapper emits `changed`. Swapping back
## restores the very same FontFile, so the pixel look returns exactly. New text
## must use a role too: test_font_swap.gd fails on a direct reference to a
## pixel font file.
##
## The readable faces live in res://Assets/Fonts/Profiles/readable.tres and
## lead the language's own fonts, which follow as fallbacks for scripts
## Atkinson lacks (CJK, Cyrillic).
##
## Font sizes stay as they are. Each readable font was rescaled once by
## tools/fit_readable_font.py to cover its pixel font's footprint at the same
## size (same line height and baseline, same width of mixed-case text), so the
## sizes chosen for the pixel fonts all still fit. All-caps text runs about a
## fifth wider than in the narrow pixel fonts.
##
## Each readable font also rides a little higher or lower than its pixel
## font, so its capitals centre where the pixel font's do (each readable
## face's baseline_offset): every label box laid out for the pixel fonts then
## frames the readable text just as squarely.
##
## The readable fonts import as MSDF at msdf_size 192. The game samples every
## texture with nearest filtering, and at the stock 64 a glyph's field texels
## came out bigger than a screen pixel (a size-16 em is 96 screen pixels
## through the 6x camera), which left stair-stepped, uneven strokes.

static func is_readable() -> bool:
	return FontRoles.is_readable()


static func set_readable(readable: bool) -> void:
	FontRoles.set_readable(readable)


## The wrappers the game's text goes through, one per role, for tests.
static func wrappers() -> Array[FontVariation]:
	var result: Array[FontVariation] = []
	for role: StringName in FontRoles.ROLES:
		result.append(FontRoles.font(role) as FontVariation)
	return result


## The baseline offset [param wrapper] wears with Readable Font off or on,
## for tests.
static func baseline_offset_for(wrapper: FontVariation, readable: bool) -> float:
	return _face_for(wrapper, readable).baseline_offset


## The font [param wrapper] shows with Readable Font off or on, in the current
## language, for tests.
static func font_for(wrapper: FontVariation, readable: bool) -> Font:
	return _face_for(wrapper, readable).font


static func _face_for(wrapper: FontVariation, readable: bool) -> FontFace:
	var role: StringName = FontRoles.ROLES[wrappers().find(wrapper)]
	var profile: FontProfile = FontRoles.readable_profile() if readable else FontRoles.current_profile()
	return profile.face(role)
