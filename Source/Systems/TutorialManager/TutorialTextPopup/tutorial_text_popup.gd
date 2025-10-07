class_name TutorialTextPopup
extends Node2D

@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.2

@export var character_reveal_time: float = 0.05
@export var max_reveal_time: float = 5

var display_close_button: bool = true
var time_to_wait_after_text_shown: float = 0

var character_reveal_tween: Tween
var tween: Tween

signal all_text_displayed()
signal popup_closed()


func setup(text: String, global_pos: Vector2, close_button: bool = true, auto_close_time: float = 0) -> void:
	Events.close_tutorial_text_popup.connect(close)
	
	global_position = global_pos
	display_close_button = close_button
	time_to_wait_after_text_shown = auto_close_time
	
	if close_button:
		%CloseButton.show()
	else:
		%CloseButton.hide()

	await _fade_in()
	
	## Bob the computer head
	#var _bob_tween: Tween = get_tree().create_tween()
	#var tween_time: float = 2
	#_bob_tween.tween_property(%ComputerTalking, 'position', position + Vector2(0, 2), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#_bob_tween.tween_property(%ComputerTalking, 'position', position - Vector2(0, 2), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#_bob_tween.set_loops()
	
	%RichTextLabel.text = Utils.format_text(text, 9)
	%RichTextLabel.visible_characters = 0
	
	var raw_text: String = Utils.strip_bbcode_tags(text)
	
	var time_to_reveal: float = min(
		character_reveal_time * len(raw_text),
		max_reveal_time
	)
	
	character_reveal_tween = get_tree().create_tween()
	character_reveal_tween.set_parallel(false)
	character_reveal_tween.tween_method(
		_show_characters, 
		0, 
		len(raw_text), 
		time_to_reveal
	).set_trans(Tween.TRANS_LINEAR)
	character_reveal_tween.tween_callback(when_text_shown)
		
		
func _show_characters(num: int) -> void:
	if %RichTextLabel.visible_characters != num and num%2 == 0:
		Events.play_sound.emit("text_blip")
		
	%RichTextLabel.visible_characters = num
	

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
	%ComputerTalking.stop()
	all_text_displayed.emit()
	if display_close_button:
		%CloseButton.show()
		
		# Auto-close if delay is set
	if time_to_wait_after_text_shown > 0:
		await get_tree().create_timer(time_to_wait_after_text_shown).timeout
		close()
	
	
#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and \
		#event.button_index == MOUSE_BUTTON_LEFT and \
		#event.pressed and \
		#character_reveal_tween:
			#character_reveal_tween.kill()
			#%RichTextLabel.visible_characters = -1
			#when_text_shown()
			
