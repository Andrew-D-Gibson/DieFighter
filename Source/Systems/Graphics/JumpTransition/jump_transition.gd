@tool
extends Control

@export var fade_in_time: float = 2
@export var fade_out_time: float = 2

var fade_tween: Tween

## The hyperspace colour of an ordinary jump, read off the material so the
## scene stays where it's authored. A gate jump tints over it; see set_tint().
var _default_tint: Color
## Multiplied into the particle streaks. White leaves the sheet as drawn.
var _particle_tint: Color = Color.WHITE

func set_background_transparency(alpha: float) -> void:
	%JumpTexture.material.set_shader_parameter("alpha", alpha)
	
	
func set_particles_transparency(alpha: float) -> void:
	%ParticleSheet.modulate = Color(_particle_tint, alpha)


## Recolours the next jump. Used by a jump gate, so leaving a sector doesn't
## look like any other hop between tiles.
func set_tint(background: Color, particles: Color) -> void:
	%JumpTexture.material.set_shader_parameter("tint_color", background)
	_particle_tint = particles
	set_particles_transparency(%ParticleSheet.modulate.a)


func reset_tint() -> void:
	set_tint(_default_tint, Color.WHITE)
	
	
func _ready() -> void:
	_default_tint = %JumpTexture.material.get_shader_parameter("tint_color")
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
