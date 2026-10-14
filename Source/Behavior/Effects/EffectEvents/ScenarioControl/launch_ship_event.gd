class_name LaunchShipEvent
extends EffectEvent
## A ship brings another into the fight beside it, on its own side.

var ship_resource: EnemyResource


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor) or actor is not Enemy or ship_resource == null:
		return
	var manager: EnemyManager = Globals.enemy_manager
	if manager == null:
		return

	# The option rolling it is gated on the board having room, but two dice
	# on the same face can still ask twice.
	if not manager.has_room_to_launch():
		Juice.callout(actor as Node2D, "HANGAR JAMMED", Globals.white)
		return

	await manager.launch_ship(ship_resource, actor as Enemy)
