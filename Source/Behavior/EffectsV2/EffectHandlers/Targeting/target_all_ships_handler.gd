class_name TargetAllShipsHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.targets = Globals.enemy_manager.get_alive_enemies() as Array[Node]
	if is_instance_valid(Globals.player):
		context.targets.append(Globals.player)
