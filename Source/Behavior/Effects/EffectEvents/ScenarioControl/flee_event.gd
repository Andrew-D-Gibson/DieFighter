class_name FleeEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor) or actor is not Enemy:
		return
	
	var enemy: Enemy = actor as Enemy
	enemy.dice_manager.give_away_dice()
		
	Events.enemy_left.emit(actor, actor.scenario_state.faction)
	actor.queue_free()
