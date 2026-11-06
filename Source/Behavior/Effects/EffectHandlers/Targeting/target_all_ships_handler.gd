class_name TargetAllShipsHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# "You" is never hit by everything at once (FateSelf).
	var enemies: Array[Enemy] = FateSelf.by_chance(Globals.enemy_manager.get_alive_enemies())
	
	context.targets = Array(enemies, TYPE_OBJECT, "Node", null) as Array[Node]
	if is_instance_valid(Globals.player):
		context.targets.append(Globals.player)
