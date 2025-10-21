@tool
extends Control

@export var fade_in_time: float = 2
@export var fade_out_time: float = 2

var fade_tween: Tween

func set_transparency(alpha: float) -> void:
	%JumpTexture.material.set_shader_parameter("alpha", alpha)
	%ParticleSheet.modulate = Color(1,1,1,alpha)
	
	
func _ready() -> void:
	hide()
	

func fade_in() -> void:
	show()
	return
	
	set_transparency(0)
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = get_tree().create_tween()
	fade_tween.tween_method(
		set_transparency,
		0,
		1,
		fade_in_time
	).set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
	
	await fade_tween.finished


func fade_out() -> void:
	hide()
	return
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = get_tree().create_tween()
	fade_tween.tween_method(
		set_transparency,
		1,
		0,
		fade_out_time
	).set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
	
	await fade_tween.finished
	hide()
