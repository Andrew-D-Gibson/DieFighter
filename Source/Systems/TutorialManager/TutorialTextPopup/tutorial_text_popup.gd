class_name TutorialTextPopup
extends Node2D

const _TEXT_BLIP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/text_blip.tres")

@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.2

@export var character_reveal_time: float = 0.025
@export var max_reveal_time: float = 5

var time_to_wait_after_text_shown: float = 0

var tween: Tween
var delay_positions: Dictionary = {}
var current_character: int = 0
var target_character: int = 0

var popup_completed: bool = false
var _source_text: String = ""

## Set while the Close button waits on something besides the text (see
## hold_close_button()).
var _close_held: bool = false

var time_between_blip_sounds: float = 0.1
var last_blip_time: int = 0

## The hologram's head drifts up and down inside its bezel this many pixels,
## smoothly rather than a pixel at a time, over one bob period.
const _HEAD_BOB_PIXELS: float = 1.0
const _HEAD_BOB_SECONDS: float = 1.6
var _head_rest: Vector2
var _bob_time: float = 0.0

signal all_text_displayed()
signal popup_closed()

## Highlight masks draw just under the cards (z 12 in tutorial_text_popup.tscn)
## and over everything else, wherever in the tree they hang.
const _HIGHLIGHT_Z_INDEX: int = 11
## Where something shown through a card's dim draws: over the mask, and level
## with the card, which hangs later in the tree and so still covers it.
const SHOWN_THROUGH_DIM_Z_INDEX: int = _HIGHLIGHT_Z_INDEX + 1

## What show_through_dim() lifted, and the z each had before, put back as the
## card leaves. Keyed by instance id rather than the item itself: the item
## (a die) can be freed before the card, and walking a typed dictionary that
## holds a freed key is an engine error.
var _shown_through: Dictionary[int, Vector2i] = {}


## A full-screen highlight mask: dims the screen except for its cutouts. A card
## brings its step's own; the TutorialManager can also put one up ahead of a card.
static func make_highlight(texture: Texture2D) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.z_as_relative = false
	sprite.z_index = _HIGHLIGHT_Z_INDEX
	return sprite


func _ready() -> void:
	_head_rest = %ComputerTalking.position
	InputManager.prompts_changed.connect(_refresh_input_prompts)


## The card is gone, and its dim with it: everything lifted through the dim
## goes back to its own place in the draw order.
func _exit_tree() -> void:
	for id: int in _shown_through:
		var item: CanvasItem = instance_from_id(id) as CanvasItem
		if item:
			var was: Vector2i = _shown_through[id]
			item.z_index = was.x
			item.z_as_relative = was.y != 0
	_shown_through.clear()


## Lifts [param item] over this card's dim for as long as the card is up, so
## the player can watch something move through a dimmed part of the screen
## (the opening shot's die, flying from the raider to the hand). It stays
## under the card itself.
func show_through_dim(item: CanvasItem) -> void:
	if not is_instance_valid(item) or _shown_through.has(item.get_instance_id()):
		return
	_shown_through[item.get_instance_id()] = Vector2i(item.z_index, 1 if item.z_as_relative else 0)
	item.z_as_relative = false
	item.z_index = SHOWN_THROUGH_DIM_Z_INDEX


func _process(delta: float) -> void:
	_bob_time += delta
	%ComputerTalking.position = _head_rest + Vector2(
		0.0, sin(_bob_time * TAU / _HEAD_BOB_SECONDS) * _HEAD_BOB_PIXELS
	)


func setup(text: String, global_pos: Vector2, highlight_texture: Texture2D = null, close_button: bool = true, auto_close_time: float = 0) -> void:
	global_position = global_pos
	time_to_wait_after_text_shown = auto_close_time
	
	# Handle highlighting
	if highlight_texture:
		var highlight_sprite: Sprite2D = make_highlight(highlight_texture)
		add_child(highlight_sprite)
		highlight_sprite.global_position = Vector2(160, 90)

	
	if close_button:		
		%CloseButton.disabled = true
		%CloseButton.update_ui()
		%CloseButton.show()
	else:
		%CloseButton.hide()

	_fade_in()
	
	_source_text = text
	var formatted: Dictionary = Utils.format_with_delays(text)
	delay_positions = formatted["delays"]
	%RichTextLabel.text = formatted["text"]
	%RichTextLabel.visible_characters = 0

	target_character = formatted["length"]
	current_character = 0

	# Start the custom character reveal
	_reveal_next_character()
		
		
## Types the text in a character at a time. The player can finish it at any
## moment (a click anywhere), including while this waits out a pause, so every
## wait is followed by a check: carrying on would cut the finished text back
## to the characters typed so far and leave it there.
func _reveal_next_character() -> void:
	while current_character < target_character:
		if delay_positions.has(current_character):
			var delay_time: float = delay_positions[current_character]
			await get_tree().create_timer(delay_time).timeout
			if popup_completed:
				return

		current_character += 1
		%RichTextLabel.visible_characters = -1 if popup_completed else current_character

		var current_time: int = Time.get_ticks_msec()
		if (current_time - last_blip_time) > time_between_blip_sounds * 1000:
			Events.play_sound.emit(_TEXT_BLIP_SFX)
			last_blip_time = current_time

		var time_to_next: float = min(character_reveal_time, max_reveal_time / target_character)
		await get_tree().create_timer(time_to_next).timeout
		if popup_completed:
			return

	_finish_showing_text()
	

func _fade_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), fade_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), fade_out_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	queue_free()
	
	popup_closed.emit()
	

func when_text_shown() -> void:
	popup_completed = true
	
	%ComputerTalking.stop()
	all_text_displayed.emit()

	if not _close_held:
		_enable_close_button()

	# Auto-close if delay is set
	if time_to_wait_after_text_shown > 0:
		await get_tree().create_timer(time_to_wait_after_text_shown).timeout
		close()
	
	
## Keeps the Close button disabled, even once the text is all in, until
## release_close_button(): for a card that mustn't be closed before something
## on screen has played out.
func hold_close_button() -> void:
	_close_held = true


func release_close_button() -> void:
	_close_held = false
	if popup_completed:
		_enable_close_button()


func _enable_close_button() -> void:
	%CloseButton.disabled = false
	%CloseButton.update_ui()
	%CloseButton.soft_highlight()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
		event.button_index == MOUSE_BUTTON_LEFT and \
		event.pressed and \
		not popup_completed:
			_finish_showing_text()
			
			
## Safe to call more than once: all_text_displayed runs the step's function,
## which must happen only once.
func _finish_showing_text() -> void:
	if popup_completed:
		return
	%CompleteTextButton.hide()
	%RichTextLabel.visible_characters = -1
	when_text_shown()
			


## Rebuild only the formatted controls, keeping the current reveal and timers.
func _refresh_input_prompts() -> void:
	if _source_text.is_empty():
		return
	var formatted: Dictionary = Utils.format_with_delays(_source_text)
	delay_positions = formatted["delays"]
	target_character = formatted["length"]
	current_character = target_character if popup_completed else mini(current_character, target_character)
	%RichTextLabel.text = formatted["text"]
	%RichTextLabel.visible_characters = -1 if popup_completed else current_character
