class_name TargetAllOtherShipsHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# Get all the ships
	context.targets = Globals.enemy_manager.get_alive_enemies() as Array[Node]
	if is_instance_valid(Globals.player):
		context.targets.append(Globals.player)
	
	# Remove the actor
	if context.actor in context.targets:
		context.targets.erase(context.actor)
