class_name MapHint
extends Control
## The caption strip above the map: a location icon that pops in, then its
## name typed out beside it. Map decides what to say; this only presents it.

@export var icon: Sprite2D
@export var label: Label

## Gap between the icon and the text, in map pixels.
@export var spacing: int = 3
@export var pop_time: float = 0.15
## Seconds per typed character.
@export var type_time: float = 0.03

var _tween: Tween


func show_hint(texture: Texture2D, text: String, color: Color) -> void:
	icon.texture = texture
	label.text = text
	label.add_theme_color_override("font_color", color)
	_layout()
	_animate_in()


## Centres icon and text as one unit. The label is sized to the full text up
## front so typing reveals it in place instead of re-centring every letter.
func _layout() -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var text_width: int = ceili(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var icon_size: Vector2i = Vector2i(icon.texture.get_size()) if icon.texture else Vector2i.ZERO

	var left: int = floori((size.x - (icon_size.x + spacing + text_width)) / 2.0)
	# Whole-pixel positions keep the pixel art on the grid.
	icon.position = Vector2(left + icon_size.x / 2.0, floori(size.y / 2.0) + (icon_size.y % 2) / 2.0)
	label.position = Vector2(left + icon_size.x + spacing, 0)
	label.size = Vector2(text_width, size.y)


func _animate_in() -> void:
	if _tween:
		_tween.kill()
	icon.scale = Vector2.ZERO
	label.visible_characters = 0

	_tween = create_tween()
	_tween.tween_property(icon, "scale", Vector2.ONE, pop_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	# Start typing as the icon settles, so the two read as one motion.
	_tween.parallel().tween_property(label, "visible_characters", label.text.length(), label.text.length() * type_time)\
		.set_delay(pop_time * 0.5)
