class_name TutorialTextPopup
extends Node2D

@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.2

@export var character_reveal_time: float = 0.025
@export var max_reveal_time: float = 5

var display_close_button: bool = true
var time_to_wait_after_text_shown: float = 0

var tween: Tween
var delay_positions: Dictionary = {}
var current_character: int = 0
var target_character: int = 0

var popup_completed: bool = false

var time_between_blip_sounds: float = 0.1
var last_blip_time: int = 0

signal all_text_displayed()
signal popup_closed()


func setup(text: String, global_pos: Vector2, highlight_texture: Texture2D = null, time_delay: float = 0, close_button: bool = true, auto_close_time: float = 0) -> void:
	Events.close_tutorial_text_popup.connect(close)

	global_position = global_pos
	display_close_button = close_button
	time_to_wait_after_text_shown = auto_close_time
	
	# Handle highlighting
	if highlight_texture:
		var highlight_sprite: Sprite2D = Sprite2D.new()
		highlight_sprite.texture = highlight_texture
		highlight_sprite.z_index = -1
		add_child(highlight_sprite)
		highlight_sprite.global_position = Vector2(160, 90)

	
	if close_button:		
		%CloseButton.disabled = true
		%CloseButton.update_ui()
		%CloseButton.show()
	else:
		%CloseButton.hide()

	_fade_in()
	
	## Bob the computer head
	#var _bob_tween: Tween = get_tree().create_tween()
	#var tween_time: float = 2
	#_bob_tween.tween_property(%ComputerTalking, 'position', position + Vector2(0, 2), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#_bob_tween.tween_property(%ComputerTalking, 'position', position - Vector2(0, 2), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#_bob_tween.set_loops()
	
	# Parse delay tags before formatting
	delay_positions = Utils.parse_delay_tags(text)
	var text_without_delays: String = Utils.remove_delay_tags(text)
	var bb_code_text: String = Utils.format_text(text_without_delays, 9)
	var raw_text: String = Utils.strip_bbcode_tags(bb_code_text)
	
	print(raw_text)
	
	%RichTextLabel.text = bb_code_text
	%RichTextLabel.visible_characters = 0
	
	target_character = len(raw_text)
	current_character = 0
	
	# Start the custom character reveal
	_reveal_next_character()
		
		
func _reveal_next_character() -> void:
	if current_character >= target_character:
		_finish_showing_text()
		return
	
	if popup_completed:
		return
	
	# Check if there's a delay at this position
	if delay_positions.has(current_character):
		var delay_time: float = delay_positions[current_character]
		await get_tree().create_timer(delay_time).timeout
	
	# Reveal the next character
	current_character += 1
	%RichTextLabel.visible_characters = current_character
	
	# Play sound effect
	var current_time: int = Time.get_ticks_msec()
	if (current_time - last_blip_time) > time_between_blip_sounds * 1000:
		Events.play_sound.emit("text_blip")
		last_blip_time = current_time
	
	# Schedule next character reveal
	var time_to_next: float = min(character_reveal_time, max_reveal_time / target_character)
	await get_tree().create_timer(time_to_next).timeout
	_reveal_next_character()
	

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

	%CloseButton.disabled = false
	%CloseButton.update_ui()
	%CloseButton.soft_highlight()
		
		# Auto-close if delay is set
	if time_to_wait_after_text_shown > 0:
		await get_tree().create_timer(time_to_wait_after_text_shown).timeout
		close()
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
		event.button_index == MOUSE_BUTTON_LEFT and \
		event.pressed and \
		not popup_completed:
			_finish_showing_text()
			
			
func _finish_showing_text() -> void:
	%CompleteTextButton.hide()
	%RichTextLabel.visible_characters = -1
	when_text_shown()
			
