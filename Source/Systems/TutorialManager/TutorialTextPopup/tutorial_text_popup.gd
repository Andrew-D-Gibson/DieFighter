class_name TutorialTextPopup
extends Node2D

@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.2
@export var auto_close_delay: float = 0.0 # 0 means don't auto-close

@export var character_reveal_time: float = 0.08

var character_reveal_tween: Tween
var tween: Tween

func setup(text: String, global_pos: Vector2) -> void:
	print('popup setup function called')
	global_position = global_pos
	
	await _fade_in()
	
	## Bob the computer head
	#var _bob_tween: Tween = get_tree().create_tween()
	#var tween_time: float = 2
	#_bob_tween.tween_property(%ComputerTalking, 'position', position + Vector2(0, 2), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#_bob_tween.tween_property(%ComputerTalking, 'position', position - Vector2(0, 2), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#_bob_tween.set_loops()
	
	%RichTextLabel.text = text
	%RichTextLabel.visible_characters = 0
	
	character_reveal_tween = get_tree().create_tween()
	character_reveal_tween.set_parallel(false)
	character_reveal_tween.tween_method(
		_show_characters, 
		0, 
		len(text), 
		character_reveal_time * len(text)
	).set_trans(Tween.TRANS_LINEAR)
	character_reveal_tween.tween_callback(stop_talking_animation)
	
	# Auto-close if delay is set
	if auto_close_delay > 0:
		await get_tree().create_timer(auto_close_delay).timeout
		close()
		
		
func _show_characters(num: int) -> void:
	if %RichTextLabel.visible_characters != num and randi_range(1,5) == 1:
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


func stop_talking_animation() -> void:
	%ComputerTalking.stop()
