class_name StoryBox
extends Node2D
## A character speaking while the game holds its breath (STORY_BOXES_PLAN.md):
## the screen dims, the speaking ship stays lit above the dim, and its lines
## appear one at a time in its own speech box (EnemyDialogueManager's art,
## stretched to fit), each closed with a green Close. Clicking the dim
## finishes a line that's still typing; only Close moves on.
##
## The box colour is the speaker's faction's where there's art for it, the
## boss red otherwise. A box with no ship to speak for sits in the middle of
## the screen, tailless.
##
## Open one with open_in() and await finished. It frees itself.

signal finished()

const _TYPE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/text_blip.tres")
const _CLOSE_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_green_button.tscn")
const _RED_BOX: Texture2D = preload("res://Assets/Textures/Enemies/Dialogue/red_dialogue_box.png")
## The speech boxes there's art for, by faction id (FactionIdentity.id). Any
## other faction speaks in red, as every boss's bark does.
const _FACTION_BOXES: Dictionary[StringName, Texture2D] = {
	&"caravan": preload("res://Assets/Textures/Enemies/Dialogue/green_dialogue_box.png"),
	&"inbound": preload("res://Assets/Textures/Enemies/Dialogue/yellow_dialogue_box.png"),
}
const _DIM_COLOR: Color = Color(0.027451, 0.0117647, 0.054902, 0.88)
## Over the other cards (z 40), so nothing pops up through the dim.
const _Z: int = 45
const _CHARS_PER_SECOND: float = 38.0
const _FADE_IN: float = 0.4
const _FADE_OUT: float = 0.5

## The box's size, with room for the longest line and the button. Narrow
## enough to fit beside a ship in the middle of the screen on either side.
const _BOX_WIDTH: float = 132.0
const _TEXT_HEIGHT: float = 55.0
## How far the tip of the box's tail sits from the ship's middle, beyond its
## authored dialogue_offset, so it clears the hull.
const _TAIL_GAP: float = 16.0
const _SCREEN_MARGIN: float = 4.0

var _speaker: Enemy = null
var _root: Control
var _box: _SpeechBox
var _text: RichTextLabel
var _close: Button
var _lines: Array[String] = []
var _index: int = -1
var _typing: Tween
var _playing: bool = false


## Opens a box over everything, under [param parent], for [param speaker]
## (null for nobody on screen) saying [param lines] under the heading
## [param speaker_name]. Lines are shown as given: translate them first.
static func open_in(parent: Node, speaker_name: String, lines: Array[String], speaker: Enemy) -> StoryBox:
	var box: StoryBox = StoryBox.new()
	parent.add_child(box)
	box.global_position = Vector2.ZERO
	box._open(speaker_name, lines, speaker)
	return box


func _open(speaker_name: String, lines: Array[String], speaker: Enemy) -> void:
	z_index = _Z
	z_as_relative = false
	_speaker = speaker
	_lines = lines
	_index = -1
	_playing = true
	_build(speaker_name)
	if is_instance_valid(_speaker):
		# One above the dim, so it's the only thing left lit.
		_speaker.graphics_manager.set_spotlit(_Z + 1)
	Events.glitch_burst.emit(240)
	_lay_out.call_deferred()


func _build(speaker_name: String) -> void:
	_root = Control.new()
	_root.size = Globals.SCREEN_SIZE
	_root.modulate.a = 0.0
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = _DIM_COLOR
	dim.size = Globals.SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)

	var has_speaker: bool = is_instance_valid(_speaker)
	var points_left: bool = has_speaker and _speaker.global_position.x > Globals.SCREEN_SIZE.x / 2.0
	var faction: FactionIdentity = _speaker.enemy_resource.faction if has_speaker else null
	var texture: Texture2D = _RED_BOX
	var heading_color: Color = Globals.red
	if faction and _FACTION_BOXES.has(faction.id):
		texture = _FACTION_BOXES[faction.id]
		heading_color = faction.color
	_box = _SpeechBox.new(texture, points_left, has_speaker)
	# Over the lit ship, in case the box has to tuck in against it.
	_box.z_index = 2
	_root.add_child(_box)

	var heading: Label = Label.new()
	heading.text = speaker_name
	heading.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 1.0)
	heading.add_theme_color_override("font_color", heading_color)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.column.add_child(heading)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(_BOX_WIDTH - _SpeechBox.INSET_TOTAL, _TEXT_HEIGHT)
	_text.add_theme_color_override("default_color", Globals.white)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.column.add_child(_text)

	var row: CenterContainer = CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.column.add_child(row)
	_close = _CLOSE_BUTTON.instantiate()
	row.add_child(_close)
	_close.set_button_text("STORY_BOX_CLOSE")
	_close.pressed_within_window.connect(_on_close)


## Sizes the box once its contents have laid themselves out, then fades in.
func _lay_out() -> void:
	_box.fit(_BOX_WIDTH)
	_place_box()
	var fade: Tween = create_tween()
	fade.tween_property(_root, "modulate:a", 1.0, _FADE_IN)
	fade.tween_callback(_next)


func _process(_delta: float) -> void:
	if _playing and _box:
		_place_box()


## Beside the speaker, its tail on the ship, kept on screen. With no ship to
## speak for, centred.
func _place_box() -> void:
	var size: Vector2 = _box.box_size
	var at: Vector2
	if is_instance_valid(_speaker):
		var offset: Vector2 = _speaker.enemy_resource.dialogue_offset
		var reach: float = absf(offset.x) + _TAIL_GAP
		var tip: Vector2 = _speaker.global_position + Vector2(-reach if _box.points_left else reach, offset.y)
		at = tip - _box.tail_tip()
	else:
		at = (Globals.SCREEN_SIZE - size) / 2.0
	var low: Vector2 = Vector2.ONE * _SCREEN_MARGIN
	var high: Vector2 = Globals.SCREEN_SIZE - size - low
	_box.position = at.clamp(low, high).round()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hurry()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and not _hurry():
		_on_close()


## Finishes typing the line out. False if it already was.
func _hurry() -> bool:
	if not _playing or not _typing or not _typing.is_running():
		return false
	_typing.kill()
	_text.visible_ratio = 1.0
	_show_close(true)
	return true


func _on_close() -> void:
	if not _playing or _hurry():
		return
	_next()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	_text.text = _lines[_index]
	_text.visible_ratio = 0.0
	_show_close(false)
	var chars: int = _text.get_total_character_count()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.2, chars / _CHARS_PER_SECOND))
	_typing.tween_callback(_show_close.bind(true))
	Events.play_sound.emit(_TYPE_SFX)


## The Close button waits for the line it closes, holding its place in the
## box meanwhile so the box doesn't jump.
func _show_close(shown: bool) -> void:
	_close.modulate.a = 1.0 if shown else 0.0
	_close.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE


func _finish() -> void:
	_playing = false
	var fade: Tween = create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, _FADE_OUT)
	fade.tween_callback(func() -> void:
		if is_instance_valid(_speaker):
			_speaker.graphics_manager.set_spotlit(-1)
		finished.emit()
		queue_free()
	)


## A ship's speech box (EnemyDialogueManager's art) stretched to any size:
## sliced into a top band, the tail's band at its original height, and a
## bottom band, each stretched across. Mirrored to point left. Its contents
## go in [member column].
class _SpeechBox:
	extends Control

	## The art's bands: rows 0-15 above the tail, 16-31 the tail, 32-47 below.
	const _BAND: float = 16.0
	## Where the art's straight edges start: the tail and rounded corners on
	## the left, the corners on the right, top and bottom.
	const _EDGE_LEFT: int = 13
	const _EDGE_RIGHT: int = 5
	const _EDGE_ROUND: int = 5
	## Space between the box's outline and its contents, on the tail side
	## (past the tail) and the far side.
	const _INSET_TAIL: float = 14.0
	const _INSET_FAR: float = 7.0
	const INSET_TOTAL: float = _INSET_TAIL + _INSET_FAR
	const _INSET_Y: float = 6.0
	## The tip of the tail, down from the top of its band.
	const _TIP_Y: float = 7.5

	var points_left: bool
	var column: VBoxContainer
	var box_size: Vector2 = Vector2.ZERO
	var _has_tail: bool
	var _frame: Control
	var _top: NinePatchRect
	var _tail: NinePatchRect
	var _bottom: NinePatchRect

	func _init(texture: Texture2D, left: bool, has_tail: bool) -> void:
		points_left = left
		_has_tail = has_tail
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame = Control.new()
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)
		_top = _band(texture, Rect2(0, 0, 64, _BAND), _EDGE_ROUND, 0)
		_tail = _band(texture, Rect2(0, _BAND, 64, _BAND), 0, 0)
		_bottom = _band(texture, Rect2(0, _BAND * 2.0, 64, _BAND), 0, _EDGE_ROUND)
		_tail.visible = has_tail
		column = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 2)
		add_child(column)

	func _band(texture: Texture2D, region: Rect2, top: int, bottom: int) -> NinePatchRect:
		var band: NinePatchRect = NinePatchRect.new()
		band.texture = texture
		band.region_rect = region
		band.patch_margin_left = _EDGE_LEFT
		band.patch_margin_right = _EDGE_RIGHT
		band.patch_margin_top = top
		band.patch_margin_bottom = bottom
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(band)
		return band

	## Sizes the box [param width] wide (tail included) and tall enough for
	## its contents, the tail halfway down.
	func fit(width: float) -> void:
		var inner: Vector2 = column.get_combined_minimum_size()
		var height: float = maxf(roundf(inner.y + _INSET_Y * 2.0), _BAND * 3.0)
		box_size = Vector2(width, height)
		size = box_size
		var tail_height: float = _BAND if _has_tail else 0.0
		var above: float = floorf((height - _BAND) / 2.0) if _has_tail else height - _BAND
		var below: float = height - above - tail_height
		_top.position = Vector2.ZERO
		_top.size = Vector2(width, above)
		_tail.position = Vector2(0, above)
		_tail.size = Vector2(width, _BAND)
		_bottom.position = Vector2(0, height - below)
		_bottom.size = Vector2(width, below)
		# Mirrored about its middle, so the tail points left.
		_frame.size = box_size
		_frame.pivot_offset = box_size / 2.0
		_frame.scale = Vector2(-1.0 if points_left else 1.0, 1.0)
		column.position = Vector2(_INSET_FAR if points_left else _INSET_TAIL, _INSET_Y)
		column.size = Vector2(width - INSET_TOTAL, inner.y)

	## Where the tail's tip is, from the box's top left.
	func tail_tip() -> Vector2:
		var y: float = _tail.position.y + _TIP_Y
		return Vector2(box_size.x if points_left else 0.0, y)
