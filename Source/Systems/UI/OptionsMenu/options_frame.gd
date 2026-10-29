class_name OptionsFrame
extends Control
## The options menu's panel: a dark body with a row of tabs along its top,
## outlined one pixel wide with the corners knocked off, like the rest of the
## game's pixel UI. The open tab joins the body and lends it its colour; the
## others sit on the body's top edge in their own.
##
## Drawn rather than a sprite sheet so the menu can have any number of tabs,
## each as wide as its (translated) title.

const FILL: Color = Color("#040217")

## Each tab's rect, in this Control's coordinates, ending just above the
## body's top edge.
var tab_rects: Array[Rect2] = []:
	set(value):
		tab_rects = value
		queue_redraw()
var tab_colors: Array[Color] = []:
	set(value):
		tab_colors = value
		queue_redraw()
var active_tab: int = 0:
	set(value):
		active_tab = value
		queue_redraw()
## The body, below the tabs.
var body_rect: Rect2:
	set(value):
		body_rect = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var active_color: Color = tab_colors[active_tab] if active_tab < tab_colors.size() else Color.WHITE
	_draw_box(body_rect, active_color)
	for i: int in range(tab_rects.size()):
		var tab: Rect2 = tab_rects[i]
		if i == active_tab:
			# Open into the body: its sides run down through the body's top
			# edge, and there's no line between them.
			var joined: Rect2 = tab.grow_side(SIDE_BOTTOM, 1)
			_fill_box(joined)
			_draw_outline(joined, active_color, false)
		else:
			# Sits on the body's top edge, which stays the open tab's colour.
			_fill_box(tab)
			_draw_outline(tab, tab_colors[i], false)


func _draw_box(rect: Rect2, color: Color) -> void:
	_fill_box(rect)
	_draw_outline(rect, color, true)


## Fills [param rect] less its four corner pixels.
func _fill_box(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(1, 0), rect.size - Vector2(2, 0)), FILL)
	draw_rect(Rect2(rect.position + Vector2(0, 1), rect.size - Vector2(0, 2)), FILL)


func _draw_outline(rect: Rect2, color: Color, with_bottom: bool) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var p: Vector2 = rect.position
	draw_rect(Rect2(p + Vector2(1, 0), Vector2(w - 2, 1)), color)
	draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, h - 1 if not with_bottom else h - 2)), color)
	draw_rect(Rect2(p + Vector2(w - 1, 1), Vector2(1, h - 1 if not with_bottom else h - 2)), color)
	if with_bottom:
		draw_rect(Rect2(p + Vector2(1, h - 1), Vector2(w - 2, 1)), color)
