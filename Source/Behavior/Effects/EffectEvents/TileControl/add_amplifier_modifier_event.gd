class_name AddAmplifierModifierEvent
extends EffectEvent


func resolve(engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		var amplifier: AmplifierModifier = AmplifierModifier.new(target, amount)
		amplifier.source = effect_source as Node2D
		engine.add_modifier(amplifier)
