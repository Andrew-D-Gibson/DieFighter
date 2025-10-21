@tool
extends Control

@export var fade_in_time: float = 2
@export var fade_out_time: float = 2

#var particle_sprites:

var fade_tween: Tween

func set_transparency(alpha: float) -> void:
	set_background_transparency(alpha)
	set_particles_transparency(alpha)
	
	
func set_background_transparency(alpha: float) -> void:
	%JumpTexture.material.set_shader_parameter("alpha", alpha)
	
	
func set_particles_transparency(alpha: float) -> void:
	%ParticleSheet.modulate = Color(1,1,1,alpha)
	
	
func _ready() -> void:
	set_background_transparency(0)
	set_particles_transparency(0)
	hide()


func tween_particles(alpha: float, time: float) -> void:
	var current_alpha: float = %ParticleSheet.modulate.a
	
	var particle_tween: Tween = get_tree().create_tween()
	particle_tween.tween_method(
		set_particles_transparency,
		current_alpha,
		alpha,
		time
	)
	
	
func tween_background(alpha: float, time: float) -> void:
	var current_alpha: float = %JumpTexture.material.get_shader_parameter("alpha")
	
	var background_tween: Tween = get_tree().create_tween()
	background_tween.tween_method(
		set_background_transparency,
		current_alpha,
		alpha,
		time
	)
