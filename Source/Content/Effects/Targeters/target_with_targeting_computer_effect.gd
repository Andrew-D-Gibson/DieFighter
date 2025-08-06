class_name TargetWithTargetingComputerEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.targets.clear()
	
	var targeted_enemy: Enemy = Globals.targeting_computer.targeted_enemy
	if targeted_enemy:
		effect_variables.targets = Array([targeted_enemy], TYPE_OBJECT, "Node", null)
