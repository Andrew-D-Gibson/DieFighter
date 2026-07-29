class_name TargetAllShipsHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var enemies := Globals.enemy_manager.get_alive_enemies()
	
	context.targets = Array(enemies, TYPE_OBJECT, "Node", null) as Array[Node]
	if is_instance_valid(Globals.player):
		context.targets.append(Globals.player)
