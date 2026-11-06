class_name ArrivalCredits
extends Node2D
## The credits as the arrival rolls them (RECKONING_ENDINGS.md §7): the lines
## ReckoningCredits keeps, then the ending's own last card, in one column
## that scrolls up through the frame a whole art pixel at a time, so it keeps
## step with the ships beside it.
##
## Drawn on the 1080p layer, as Become Fate's falling credits are, not inside
## the 320x180 PixelWorld: world fonts are rasterized at 6x for the game's
## 6x cameras (FontRoles._prepare_world), so inside a viewport drawn at 1x
## they'd be sampled down and come out ragged and soft. Here every font pixel
## is a crisp 6x6 block, on the same grid as the art. The API is still in art
## pixels: [param center_x], [param width], [member scroll].
##
## Tween [member scroll] from 0 to [method rest_scroll] to roll them. The last
## card stops on the middle of the frame; with no last card, everything rolls
## off the top.

## Screen pixels per art pixel: the 6x the cutscene blows the art up by.
const _ART: float = 6.0
## Below the bottom of the frame, so the roll starts from nothing. Art pixels.
const _START_Y: float = Globals.SCREEN_SIZE.y + 4.0
## Screen pixels: the extra a GAP line leaves, and between lines.
const _GAP_HEIGHT: float = 9.0 * _ART
const _LINE_SPACING: float = 2.0 * _ART
## Before the ending's last card: the credits are done; this is the ending.
## Long enough that they've left the frame by the time it comes to rest.
const _CARD_GAP: float = 84.0 * _ART

const _TITLE_COLOR: Color = Color("#cef0f1")
const _HEADING_COLOR: Color = Color("#8e8b85")
const _NAME_COLOR: Color = Color("#c4c1bc")

## How far the column has rolled up, in art pixels.
var scroll: float = 0.0:
	set(value):
		scroll = value
		# Whole art pixels, so the text steps on the art's grid.
		position.y = roundf(_START_Y - scroll) * _ART

## The column's height and where the last card's middle is, from its top, in
## screen pixels; the middle is negative with no last card.
var _height: float = 0.0
var _card_middle: float = -1.0


## Lays out the credits in a column [param width] art pixels wide centred on
## [param center_x], then [param last_card] (ReckoningCredits-style lines,
## each with an optional "color"). Call once it's in the tree.
func build(center_x: float, width: float, last_card: Array[Dictionary]) -> void:
	var column: float = roundf(width) * _ART
	position = Vector2(roundf(center_x - width / 2.0) * _ART, _START_Y * _ART)
	var y: float = 0.0
	for line: Dictionary in ReckoningCredits.lines():
		y = _add_line(line, y, column)
	if not last_card.is_empty():
		y += _CARD_GAP
		var card_top: float = y
		for line: Dictionary in last_card:
			y = _add_line(line, y, column)
		# To a whole art pixel, so the card lands on the art's grid.
		_card_middle = roundf((card_top + y) / 2.0 / _ART) * _ART
	_height = y


## The [member scroll] to roll to: the last card held on the middle of the
## frame, or the whole column gone off the top.
func rest_scroll() -> float:
	if _card_middle >= 0.0:
		return _START_Y + (_card_middle - Globals.SCREEN_SIZE.y * _ART / 2.0) / _ART
	return _START_Y + _height / _ART + 2.0


func _add_line(line: Dictionary, y: float, column: float) -> float:
	var style: ReckoningCredits.Style = line["style"]
	if style == ReckoningCredits.Style.GAP:
		return y + _GAP_HEIGHT
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", FateDieArt.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", int(_ART))
	var color: Color = _NAME_COLOR
	match style:
		ReckoningCredits.Style.TITLE:
			label.text = str(line["text"])
			label.theme_type_variation = FontRoles.slot(FontRoles.BODY, _ART * 2.0)
			color = _TITLE_COLOR
		ReckoningCredits.Style.HEADING:
			label.text = tr(str(line["text"]))
			label.theme_type_variation = FontRoles.slot(FontRoles.SMALL, _ART)
			color = _HEADING_COLOR
		_:
			label.text = str(line["text"])
			label.theme_type_variation = FontRoles.slot(FontRoles.BODY, _ART)
	label.add_theme_color_override("font_color", line.get("color", color))
	add_child(label)
	label.size = Vector2(column, 0.0)
	label.position = Vector2(0.0, y)
	return y + ceilf(label.get_combined_minimum_size().y) + _LINE_SPACING
