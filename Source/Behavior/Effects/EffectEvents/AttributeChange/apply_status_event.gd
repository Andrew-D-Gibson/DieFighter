class_name ApplyStatusEvent
extends EffectEvent
## Puts a status on each target, or adds to one it already has.
##
## amount is the stacks. It stays amplifiable on purpose: an Amplifier or
## Booster Stage beside a status tile applies more of it.
##
## Going through an event (rather than a handler adding the modifier itself)
## means a modifier can cancel it — an immunity rule needs nothing new.

var status_id: StringName


## A status a tile puts on its own ship is a cost (Blowtorch's Burn), and a
## boost never grows a cost.
func is_amplifiable() -> bool:
	return actor == null or not targets.has(actor)


func resolve(engine: ScenarioEngine) -> void:
	if amount <= 0:
		return

	for target: Node in targets:
		# Ships carry statuses; tiles and dice don't.
		if not is_instance_valid(target) or not (target is Enemy or target is Player):
			continue
		if target.health.health <= 0:
			continue

		var incoming: StatusModifier = StatusCatalog.create(status_id, target as Node2D, amount)
		if incoming == null:
			return
		provoke(target)
		# An enemy putting a status on the player is as hostile as a hit.
		if actor is Enemy and target is Player and Globals.state_manager:
			Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT

		var existing: StatusModifier = engine.find_status(target, status_id)
		if existing:
			existing.merge(incoming)
			existing.play_applied_feedback(amount)
		else:
			engine.add_modifier(incoming)
			incoming.play_applied_feedback(amount)
