class_name TargetRandomShipHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var all_ships: Array[Node] = Globals.enemy_manager.get_alive_enemies() as Array[Node]
	
	if is_instance_valid(Globals.player):
		all_ships.append(Globals.player)
		
	if all_ships.is_empty():
		context.targets = []
		return
		
	context.targets = [all_ships.pick_random()]
