class_name ReckoningCredits
extends RefCounted
## The credits the Reckoning's real endings roll (RECKONING_ENDINGS.md §7).
## Short on purpose: each ending rolls them its own way (silent over the
## empty sky, beside the convoy, over the formation with its gap, falling),
## but they all read these lines, so there's one list to keep.
##
## PLACEHOLDER: who and what is listed is an open question in
## RECKONING_ENDINGS.md §10. Headings are translated; names are not.

## One line of the credits. HEADING lines are translated keys; NAME lines are
## shown as written; GAP is a blank beat between blocks.
enum Style { TITLE, HEADING, NAME, GAP }


## Every line, top to bottom: {"style": Style, "text": String}.
static func lines() -> Array[Dictionary]:
	return [
		{"style": Style.TITLE, "text": "DIE FIGHTER"},
		{"style": Style.GAP, "text": ""},
		{"style": Style.HEADING, "text": "CREDITS_HEADING_MADE_BY"},
		{"style": Style.NAME, "text": "Andrew Gibson"},
		{"style": Style.GAP, "text": ""},
		{"style": Style.HEADING, "text": "CREDITS_HEADING_FONTS"},
		{"style": Style.NAME, "text": "monogram by datagoblin"},
		{"style": Style.NAME, "text": "Fusion Pixel 12 / Galmuri"},
		{"style": Style.NAME, "text": "Atkinson Hyperlegible"},
		{"style": Style.GAP, "text": ""},
		{"style": Style.HEADING, "text": "CREDITS_HEADING_BUILT_WITH"},
		{"style": Style.NAME, "text": "Godot Engine"},
		{"style": Style.NAME, "text": "GUT"},
		{"style": Style.GAP, "text": ""},
		{"style": Style.HEADING, "text": "CREDITS_THANKS"},
	]
