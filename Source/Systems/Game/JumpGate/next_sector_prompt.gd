class_name NextSectorPrompt
extends Node2D
## "NEXT SECTOR" and a chevron, floating on the right of the sky while the jump
## gate is open, nudging rightward over and over: the way out is to jump
## right. Clicking it opens the map, where the right arrow does the jumping.
##
## The ring on its own read as scenery. Players stood at the gate unsure
## whether to fly through it, back, or wait for something.

const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7.ttf")
const _CHEVRON: Texture2D = preload("res://Assets/Textures/Map/EncounterIcons/next_sector.png")
const _FONT_SIZE: int = 16
## Where the prompt's right edge sits, on the 320x180 grid: in open sky, clear
## of the canopy struts, the hanging dice and the environment monitor.
const _ANCHOR: Vector2 = Vector2(288, 36)
const _NUDGE_PIXELS: float = 3.0
const _NUDGE_SECONDS: float = 0.9

var _content: Node2D
var _tween: Tween


func _ready() -> void:
	# Over the cockpit frame, whatever the gate itself sits behind.
	z_as_relative = false
	z_index = 50
	top_level = true
	position = _ANCHOR

	_content = Node2D.new()
	add_child(_content)

	var label: Label = Label.new()
	label.text = tr("PROMPT_NEXT_SECTOR")
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", _FONT_SIZE)
	label.add_theme_color_override("font_color", Globals.yellow)
	label.add_theme_color_override("font_outline_color", Color.html("#040217"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(label)
	label.reset_size()

	var chevron: Sprite2D = Sprite2D.new()
	chevron.texture = _CHEVRON
	chevron.position = Vector2(-_CHEVRON.get_width() / 2.0, 0)
	_content.add_child(chevron)
	label.position = Vector2(-_CHEVRON.get_width() - 2 - label.size.x, -label.size.y / 2.0)

	var area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	var width: float = label.size.x + _CHEVRON.get_width() + 4
	rect.size = Vector2(width, 14)
	shape.shape = rect
	shape.position = Vector2(-width / 2.0, 0)
	area.add_child(shape)
	area.input_event.connect(_on_input_event)
	add_child(area)

	modulate.a = 0.0
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.4)
	_nudge()


## Slides right and springs back, again and again: "this way".
func _nudge() -> void:
	_tween = create_tween().set_loops()
	_tween.tween_property(_content, "position:x", _NUDGE_PIXELS, _NUDGE_SECONDS * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_content, "position:x", 0.0, _NUDGE_SECONDS * 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		Events.show_map.emit()


## Fades out and frees itself.
func dismiss() -> void:
	if _tween:
		_tween.kill()
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.25)
	fade.tween_callback(queue_free)
