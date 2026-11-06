class_name FateRevelation
extends Node2D
## The forbidden knowledge (LORE.md §4), passed on as the run's last boss
## dies: there's a black hole ahead too, the fleet is being herded, and the
## tithe was a sacrifice. Typed out a line at a time over a dimmed screen;
## a click hurries a line, then moves to the next.
##
## Hearing it is Gate 1 of the secret fight: it outlives the run
## (CollectionManager.learn_fate_knowledge()), so the way back toward Fate can
## open on a later run. A player who has heard it before gets the short form.
##
## Until the Front and the Vanguard exist (LORE.md §3), the dying Marshal, who
## commands the last gate, is the one who knows.

const _LINES: Array[String] = [
	"FATE_REVEAL_1", "FATE_REVEAL_2", "FATE_REVEAL_3", "FATE_REVEAL_4",
	"FATE_REVEAL_5", "FATE_REVEAL_6", "FATE_REVEAL_7",
]
const _LINES_AGAIN: Array[String] = ["FATE_REVEAL_AGAIN_1", "FATE_REVEAL_AGAIN_2"]
const _TYPE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/text_blip.tres")
const _DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.9)
const _WIDTH: int = 240
const _CHARS_PER_SECOND: float = 38.0
## Seconds after the boss falls before the voice comes through, so the
## kill lands first.
const _DELAY: float = 1.6
## Seconds after the voice goes before the drive lands in the engine charger.
const _DRIVE_DELAY: float = 0.35

var _root: Control
var _speaker: Label
var _text: RichTextLabel
var _hint: Label
var _lines: Array[String] = []
var _index: int = -1
var _typing: Tween
var _playing: bool = false


func _ready() -> void:
	z_index = 45
	hide()
	Events.combat_finished.connect(_on_combat_finished)


func _on_combat_finished() -> void:
	if not Globals.state_manager or not Globals.state_manager.is_at_last_gate():
		return
	var heard_before: bool = CollectionManager.has_fate_knowledge()
	CollectionManager.learn_fate_knowledge()
	await get_tree().create_timer(_DELAY).timeout
	if not CollectionManager.is_recording():
		# Nothing to tell a run that isn't the player's own, but the drive
		# is still theirs.
		_hand_over_drive()
		return
	play(_LINES_AGAIN if heard_before else _LINES)


## The Marshal's last act (FATE_REVEAL_6): the drive goes into the engine
## charger once the dim lifts, so the player sees it land.
func _hand_over_drive() -> void:
	if Globals.fate_ledger:
		Globals.fate_ledger.take_drive()


func play(lines: Array[String]) -> void:
	_lines = lines
	_index = -1
	_playing = true
	_build()
	show()
	Events.glitch_burst.emit(240)
	var fade: Tween = create_tween()
	fade.tween_property(_root, "modulate:a", 1.0, 0.4)
	fade.tween_callback(_next)


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
	dim.gui_input.connect(_on_input)
	_root.add_child(dim)

	_speaker = Label.new()
	_speaker.text = tr("FATE_REVEAL_SPEAKER")
	_speaker.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 1.0)
	_speaker.add_theme_color_override("font_color", Globals.blue)
	_speaker.position = Vector2((Globals.SCREEN_SIZE.x - _WIDTH) / 2.0, 62)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(_WIDTH, 40)
	_text.size = Vector2(_WIDTH, 40)
	_text.position = Vector2((Globals.SCREEN_SIZE.x - _WIDTH) / 2.0, 74)
	_text.add_theme_color_override("default_color", Globals.white)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_text)

	_hint = Label.new()
	_hint.text = tr("FATE_REVEAL_CONTINUE")
	_hint.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 1.0)
	_hint.add_theme_color_override("font_color", Globals.purple)
	_hint.position = Vector2((Globals.SCREEN_SIZE.x - _WIDTH) / 2.0, 124)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)


func _on_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed or not _playing:
		return
	if _typing and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		_hint.modulate.a = 1.0
		return
	_next()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		_on_input(event)
		get_viewport().set_input_as_handled()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	_text.text = tr(_lines[_index])
	_text.visible_ratio = 0.0
	_hint.modulate.a = 0.0
	var chars: int = _text.get_total_character_count()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.2, chars / _CHARS_PER_SECOND))
	_typing.tween_callback(func() -> void: _hint.modulate.a = 1.0)
	Events.play_sound.emit(_TYPE_SFX)


func _finish() -> void:
	_playing = false
	var fade: Tween = create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func() -> void:
		hide()
		for child: Node in get_children():
			child.queue_free()
	)
	fade.tween_interval(_DRIVE_DELAY)
	fade.tween_callback(_hand_over_drive)
