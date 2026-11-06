class_name TargetAllOtherShipsHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# Get all the ships. "You" is never hit by everything at once (FateSelf).
	var targets: Array[Node] = []
	targets.assign(FateSelf.by_chance(Globals.enemy_manager.get_alive_enemies()))
	context.targets = targets
	if is_instance_valid(Globals.player):
		context.targets.append(Globals.player)
	
	# Remove the actor
	if context.actor in context.targets:
		context.targets.erase(context.actor)
