class_name TargetTriggeringShipHandler
extends EffectHandler
## Targets the ship the tile event behind this chain was about
## (EffectContext.trigger_ship): the attacker, for an ON_PLAYER_ATTACKED
## response.
##
## The response is queued behind the rest of the attacker's chain, so by the
## time it plays the ship may have died to something else, or fled. Then there
## is no target and the chain hits nothing.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var targets: Array[Node] = []
	if still_here(context.trigger_ship):
		targets.append(context.trigger_ship)
	context.targets = targets


## Whether [param ship] is still in the fight to be hit.
static func still_here(ship: Node) -> bool:
	if not is_instance_valid(ship) or ship.is_queued_for_deletion():
		return false
	var health: Health = ship.get("health") as Health
	if health == null or health.is_dead or health.health <= 0:
		return false
	if ship is Enemy and is_instance_valid(Globals.enemy_manager):
		return ship in Globals.enemy_manager.get_alive_enemies()
	return true
