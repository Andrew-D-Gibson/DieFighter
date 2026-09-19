class_name GiveDieAwayEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor):
		return
	if actor is not Enemy:
		return
	actor.dice_manager.give_away_dice()
