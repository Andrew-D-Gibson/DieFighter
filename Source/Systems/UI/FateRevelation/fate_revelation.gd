class_name FateRevelation
extends Node2D
## The forbidden knowledge (LORE.md §4), confessed by the Bastion, the
## Rearguard's leader, as it dies at the run's last gate: there's a black hole
## ahead too, the fleet is being herded, and the tithe was the Bastion's price
## for its own life. Its death breaks that deal, so Fate comes to collect.
##
## The last ship to fall at the last gate (on the Bastion, whichever of its
## three parts went last) is held whole on screen while the rest of the wreck
## blows apart. Then the screen dims around it, and it speaks a line at a time
## in its own speech box, each line closed with a green Close. Its kill plays
## once the last line is closed.
##
## Hearing it is Gate 1 of the secret fight: it outlives the run
## (CollectionManager.learn_fate_knowledge()), so the way back toward Fate can
## open on a later run. A player who has heard it before gets the short form.

const _LINES: Array[String] = [
	"FATE_REVEAL_1", "FATE_REVEAL_2", "FATE_REVEAL_3", "FATE_REVEAL_4",
	"FATE_REVEAL_5", "FATE_REVEAL_6", "FATE_REVEAL_7", "FATE_REVEAL_8",
]
const _LINES_AGAIN: Array[String] = ["FATE_REVEAL_AGAIN_1", "FATE_REVEAL_AGAIN_2"]
const _TYPE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/text_blip.tres")
const _CLOSE_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_green_button.tscn")
## The boss's own speech box (EnemyDialogueManager), stretched to hold the
## longer lines.
const _BOX_TEXTURE: Texture2D = preload("res://Assets/Textures/Enemies/Dialogue/red_dialogue_box.png")
const _DIM_COLOR: Color = Color(0.027451, 0.0117647, 0.054902, 0.88)
## Over the other cards (z 40), so nothing pops up through the dim.
const _Z: int = 45
const _CHARS_PER_SECOND: float = 38.0
## Seconds after the fight ends before the screen dims: long enough for the
## hull's breakup (ShipHull.break_up()) to play out around the held ship.
const _DELAY: float = 1.6
const _FADE_IN: float = 0.4
const _FADE_OUT: float = 0.5

## The speech box's size, with room for the longest line and the button.
## Narrow enough to fit beside a ship in the middle of the screen (the
## Bastion Core) on either side.
const _BOX_WIDTH: float = 132.0
const _TEXT_HEIGHT: float = 55.0
## How far the tip of the box's tail sits from the ship's middle, beyond its
## authored dialogue_offset, so it clears the hull.
const _TAIL_GAP: float = 16.0
const _SCREEN_MARGIN: float = 4.0

var _held: Enemy = null
var _root: Control
var _box: _SpeechBox
var _text: RichTextLabel
var _close: Button
var _lines: Array[String] = []
var _index: int = -1
var _typing: Tween
var _playing: bool = false


func _ready() -> void:
	z_index = _Z
	hide()
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.combat_finished.connect(_on_combat_finished)


## The last hostile ship down at the last gate stays on screen to speak.
## Decided here, as it dies, before its kill and wreck play.
func _on_enemy_destroyed(ship: Enemy) -> void:
	if _held or not CollectionManager.is_recording() or not _is_last_gate():
		return
	if _any_hostile_left():
		return
	_held = ship
	ship.hold_death()


func _on_combat_finished() -> void:
	if not _is_last_gate():
		_let_go()
		return
	var heard_before: bool = CollectionManager.has_fate_knowledge()
	CollectionManager.learn_fate_knowledge()
	if not CollectionManager.is_recording():
		_let_go()
		return
	await get_tree().create_timer(_DELAY).timeout
	play(_LINES_AGAIN if heard_before else _LINES)


## Whether the fight just won was the run's last gate.
static func _is_last_gate() -> bool:
	var manager: ScenarioManager = Globals.scenario_manager
	var state: GameStateManager = Globals.state_manager
	if not manager or not state or not manager.current_scenario:
		return false
	return manager.current_scenario.sector_gate_scenario \
		and state.current_game_save.sector_index + 1 >= state.demo_sector_count


static func _any_hostile_left() -> bool:
	if not Globals.enemy_manager:
		return false
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if ship.is_hostile():
			return true
	return false


func play(lines: Array[String]) -> void:
	_lines = lines
	_index = -1
	_playing = true
	_build()
	show()
	if is_instance_valid(_held):
		# One above the dim, so it's the only thing left lit.
		_held.graphics_manager.set_spotlit(_Z + 1)
	Events.glitch_burst.emit(240)
	_lay_out.call_deferred()


func _build() -> void:
	for child: Node in get_children():
		child.queue_free()
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

	var points_left: bool = is_instance_valid(_held) \
		and _held.global_position.x > Globals.SCREEN_SIZE.x / 2.0
	_box = _SpeechBox.new(_BOX_TEXTURE, points_left, is_instance_valid(_held))
	# Over the lit ship, in case the box has to tuck in against it.
	_box.z_index = 2
	_root.add_child(_box)

	var speaker: Label = Label.new()
	speaker.text = tr("FATE_REVEAL_SPEAKER")
	speaker.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 1.0)
	speaker.add_theme_color_override("font_color", Globals.red)
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.column.add_child(speaker)

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
	_close.set_button_text("FATE_REVEAL_CLOSE")
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


## Beside the held ship, its tail on the ship, kept on screen. With no ship
## to speak for (the last one fled rather than died), centred.
func _place_box() -> void:
	var size: Vector2 = _box.box_size
	var at: Vector2
	if is_instance_valid(_held):
		var reach: float = absf(_held.enemy_resource.dialogue_offset.x) + _TAIL_GAP
		var tip: Vector2 = _held.global_position + Vector2(-reach if _box.points_left else reach,
			_held.enemy_resource.dialogue_offset.y)
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
	if not visible or not (event is InputEventKey):
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
	_text.text = tr(_lines[_index])
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
		hide()
		for child: Node in get_children():
			child.queue_free()
		_box = null
		_let_go()
	)


## The held ship's kill and wreck play now.
func _let_go() -> void:
	if is_instance_valid(_held):
		_held.graphics_manager.set_spotlit(-1)
		_held.release_death()
	_held = null


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
	## The transparent strip left of the box that the tail sticks out into.
	const _TAIL_WIDTH: float = 8.0
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
		var below: float = _BAND
		var above: float = floorf((height - _BAND) / 2.0) if _has_tail else height - below
		below = height - above - (_BAND if _has_tail else 0.0)
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
