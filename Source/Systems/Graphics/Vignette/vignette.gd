extends ColorRect

@export var vignette_flash_time: float = 0.75
@export var vignette_alpha: float = 0.35

## A shield break lingers and burns brighter than a chip hit — it's the
## transition from protected to exposed, and it should read as one.
@export var break_flash_time: float = 1.4
@export var break_alpha: float = 0.6


func _ready() -> void:
	visible = true
	Events.player_health_hit.connect(_health_hit_vignette)
	Events.player_shields_hit.connect(_shield_hit_vignette)
	Events.player_shields_broken.connect(_shield_break_vignette)
	


func _health_hit_vignette() -> void:
	material.set_shader_parameter('color', Globals.red)
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "material:shader_parameter/alpha", vignette_alpha, vignette_flash_time * 0.1).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "material:shader_parameter/alpha", 0, vignette_flash_time * 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	
func _shield_hit_vignette() -> void:
	material.set_shader_parameter('color', Globals.blue)
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "material:shader_parameter/alpha", vignette_alpha, vignette_flash_time * 0.1).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "material:shader_parameter/alpha", 0, vignette_flash_time * 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Cyan rather than blue, brighter, and slow to fade: the hull is bare now.
func _shield_break_vignette() -> void:
	material.set_shader_parameter('color', Color.html('#8df1f4'))

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "material:shader_parameter/alpha", break_alpha, break_flash_time * 0.06).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "material:shader_parameter/alpha", 0, break_flash_time * 0.94).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
