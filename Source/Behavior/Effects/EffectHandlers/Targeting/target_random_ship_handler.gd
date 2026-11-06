class_name TargetRandomShipHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# "You" is never picked by chance (FateSelf).
	var all_ships: Array[Node] = []
	all_ships.assign(FateSelf.by_chance(Globals.enemy_manager.get_alive_enemies()))
	
	if is_instance_valid(Globals.player):
		all_ships.append(Globals.player)
		
	if all_ships.is_empty():
		context.targets = []
		return
		
	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, all_ships)]
