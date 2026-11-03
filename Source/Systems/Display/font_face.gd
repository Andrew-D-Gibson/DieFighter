class_name FontFace
extends Resource
## How one font role (see FontRoles) looks in one locale: the font, the size
## a x1 slot of the role is drawn at, and fallbacks for what the font lacks.
##
## Faces live in res://Assets/Fonts/Faces/ and are shared: every Latin-script
## locale's body text is the same m5x7 face. A locale that needs a different
## look points its FontProfile at a different face (or its own copy).

## The primary font. Godot draws every character it has with it.
@export var font: Font

## The role's unit: what a x1 slot is drawn at, and what a xN slot multiplies.
## Keep it the font's native pixel size (m3x6 and m5x7 16, Tiny5 8, Fusion
## Pixel 12) so every slot lands on the font's pixel grid. A size that isn't
## one says why in [member note].
@export var size: int = 16

## Fonts for characters [member font] lacks, tried in order. Godot draws a
## fallback at the primary's size, so each must be pixel-exact at [member size]
## (monogram is, behind m3x6 and m5x7 at 16; Tiny5 at 16 would draw doubled).
@export var fallbacks: Array[Font] = []

## Extra pixels above and below each line at x1 (negative trims), so the
## role's line box is English's whatever the font: m3x6 and m5x7 lines are
## 13 px, 11 above the baseline and 2 below, and every box and gap in the game
## was sized to that. A xN slot gets N times as much (FontRoles), so the box
## scales with the text. Line boxes that match keep text on the same
## baseline in its box, so a smaller font sits where English's did.
@export var spacing_top: int = 0
@export var spacing_bottom: int = 0

## Moves the text up (negative) or down, as a fraction of the line height,
## so a font whose capitals sit higher or lower centres them where the role's
## boxes expect.
@export var baseline_offset: float = 0.0

## Why this face departs from its role's usual look (an off-grid size, a known
## misfit), for whoever tunes the profile next.
@export_multiline var note: String = ""


## The line height of a x1 slot: the font's own plus the spacing.
func line_height() -> float:
	return font.get_height(size) + spacing_top + spacing_bottom


## The fonts that can draw a character for this face, in the order Godot tries
## them. Godot's own system-font fallback isn't counted: a character only it
## can draw shows in a font the game didn't choose.
func chain() -> Array[Font]:
	var fonts: Array[Font] = [font]
	fonts.append_array(fallbacks)
	return fonts


## Whether this face draws [param character] in one of its own fonts.
func has_char(character: int) -> bool:
	for candidate: Font in chain():
		if candidate != null and candidate.has_char(character):
			return true
	return false
