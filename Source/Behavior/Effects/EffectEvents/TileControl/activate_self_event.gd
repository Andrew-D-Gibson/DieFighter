class_name ActivateSelfEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(effect_source):
		return
	if effect_source is not Tile:
		return
	await effect_source.try_to_activate()
