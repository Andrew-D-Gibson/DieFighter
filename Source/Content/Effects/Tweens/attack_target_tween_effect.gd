class_name AttackTargetTweenEffect
extends Effect

var tween_time: float = 1.5

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0:
		return
	var target_pos = effect_variables.targets[0].global_position
		
	# Don't do anything if there's no die to move
	if not effect_variables.activator_die:
		return
	var die: Dice = effect_variables.activator_die
	
	var adjusted_tween_time: float = tween_time / Globals.animation_speed
	
	var tween = effect_variables.actor.create_tween().set_parallel(true)
	tween.tween_property(die, 'global_position', target_pos, adjusted_tween_time).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_IN)
	tween.tween_property(die, 'rotation_degrees', 360 * 6, adjusted_tween_time).from(0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween.finished
