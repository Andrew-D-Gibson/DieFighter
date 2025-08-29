class_name AmplifierStatus
extends GridStatusEffect

## The amount modifier function
var amplifier_amount_modifier: Callable


func manipulate_effect_variables(effect_variables: EffectVariables) -> EffectVariables:
	effect_variables.amount_modifiers.push_front(amplifier_amount_modifier)
	return effect_variables


func _ready() -> void:
	var tween_time: float = 1
	var tween: Tween = get_tree().create_tween()
	tween.set_loops()
	
	tween.tween_property(
		self,
		"modulate:a",
		0.4,
		tween_time
	).set_trans(Tween.TRANS_SINE)\
	.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(
		self,
		"modulate:a",
		0.1,
		tween_time
	).set_trans(Tween.TRANS_SINE)\
	.set_ease(Tween.EASE_IN_OUT)
	
