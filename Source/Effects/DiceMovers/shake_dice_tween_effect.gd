extends Effect

var tween_time: float = 0.4

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no die to move
	if not effect_variables.activator_die:
		return
	var die: Dice = effect_variables.activator_die
	
	
	var tween = get_tree().create_tween()
	tween.tween_property(die, 'global_position', die.global_position + Vector2(2,0), tween_time/6)
	tween.tween_property(die, 'global_position', die.global_position + Vector2(-2,0), tween_time/6)
	tween.tween_property(die, 'global_position', die.global_position, tween_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await tween.finished
