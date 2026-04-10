class_name GiveDieToPlayerEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(Globals.player):
		return
	Globals.player.dice_manager.add(activator_die, true, false)
