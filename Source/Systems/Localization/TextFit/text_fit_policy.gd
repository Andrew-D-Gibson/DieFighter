class_name TextFitPolicy
extends Resource
## How a piece of text may give way when it doesn't fit its box: how many
## lines it may wrap onto, how far it may shrink, and which it tries first.
## TextFit reads it; a TextFitter or TextFitBox holds one per label.
##
## The box itself (where the text may appear) belongs to whoever frames the
## text, not to the policy: a button knows its face, a menu its hint strip.
## So one policy serves every button, every row label, every paragraph.
##
## Text never breaks inside a word unless nothing else fits: a long German
## compound shrinks rather than splitting as "Bildschirmwack / eln". (Godot
## can break at a soft hyphen, but draws the hyphen in a system font when the
## pixel font lacks U+2010, as Tiny5, monogram and Fusion Pixel do in 4.7.1,
## so translations shouldn't rely on them.)

enum Prefer {
	## Wrap onto more lines (up to max_lines) at full size before shrinking.
	## For labels in a layout that can grow taller.
	WRAP,
	## Shrink on one line (down to min_scale) before wrapping. For short
	## labels where a second line looks broken, like a 4-character Chinese
	## label orphaning its last character.
	SHRINK,
}

## How many lines the text may take. 1 keeps it on one line.
@export_range(1, 12) var max_lines: int = 1
@export var prefer: Prefer = Prefer.WRAP
## Wrapped lines are made as even as the line count allows ("动画 / 速度",
## not "动画速 / 度").
@export var balance_lines: bool = true
## The smallest the text may be drawn, as a fraction of its size. Shrinking
## goes in whole canvas pixels per font pixel (5/6, 4/6 of the 6x world
## grid), so the text stays crisp.
@export_range(0.25, 1.0, 0.01) var min_scale: float = 0.66
## Where the text sits in its box vertically, by its glyphs' ink rather than
## its line box: capitals centre in a button the way Chinese characters do,
## though one sits low in English's line box and the other fills it.
@export var vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
## False aligns the line boxes instead, as Godot's own controls do: for text
## beside a dropdown's or a Button's, so the two share a baseline. Ink still
## stays inside the box either way.
@export var align_by_ink: bool = true
## When nothing fits even at min_scale: break inside words (true) or let the
## text run past its box. Either way the fit is reported as failed.
@export var break_words_last_resort: bool = true


## One line, shrinking as needed: buttons, tabs, short titles.
static func single_line(min_scale_: float = 0.66) -> TextFitPolicy:
	var policy: TextFitPolicy = TextFitPolicy.new()
	policy.max_lines = 1
	policy.prefer = Prefer.SHRINK
	policy.min_scale = min_scale_
	return policy


## A label that may wrap onto a few lines before it shrinks: option rows,
## list entries.
static func wrapping(lines: int = 2, min_scale_: float = 0.66) -> TextFitPolicy:
	var policy: TextFitPolicy = TextFitPolicy.new()
	policy.max_lines = lines
	policy.prefer = Prefer.WRAP
	policy.min_scale = min_scale_
	return policy


## A label in a row beside Godot-drawn widget text (dropdowns, buttons):
## wraps like wrapping(), sits on the same baseline as its neighbours.
static func row_label(lines: int = 2, min_scale_: float = 0.66) -> TextFitPolicy:
	var policy: TextFitPolicy = wrapping(lines, min_scale_)
	policy.align_by_ink = false
	return policy


## Running text in a fixed box: as many lines as the box holds, shrinking
## only once they don't.
static func paragraph(min_scale_: float = 0.66) -> TextFitPolicy:
	var policy: TextFitPolicy = wrapping(12, min_scale_)
	return policy
