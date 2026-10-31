class_name TransferStatusesEvent
extends EffectEvent
## Moves every harmful status on the actor onto the first target: the same
## stacks, now working on the other ship, merged into any of the same status it
## has. Phased stays put: handing a cloak to the other side would only help it.
##
## Each status is rebuilt for its new host rather than re-pointed, because a
## status hooks things about its host when it's registered (a badge on that
## ship's bar, Scrambled's dice intake).


## No amount: it moves whatever stacks there are.
func is_amplifiable() -> bool:
	return false


## Whether the actor has anything to move. An enemy's vent with nothing on it
## does nothing, which EnemyActionResource treats like a blocked action, and
## Countermeasures refuses the die (PLAYER_HAS_HARMFUL_STATUS).
static func has_any(engine: ScenarioEngine, source: Node) -> bool:
	return engine != null and is_instance_valid(source) and not movable(engine, source).is_empty()


static func movable(engine: ScenarioEngine, source: Node) -> Array[StatusModifier]:
	var result: Array[StatusModifier] = []
	for status: StatusModifier in engine.statuses_on(source):
		if status.is_harmful():
			result.append(status)
	return result


func resolve(engine: ScenarioEngine) -> void:
	if targets.is_empty() or not is_instance_valid(actor):
		return
	var target: Node = targets[0]
	if not is_instance_valid(target) or not (target is Enemy or target is Player) or target == actor:
		return
	if target.health.health <= 0:
		return

	var moving: Array[StatusModifier] = movable(engine, actor)
	if moving.is_empty():
		return
	# Moving a debuff onto a ship is as hostile as applying one.
	provoke(target)
	if actor is Enemy and target is Player and Globals.state_manager:
		Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT

	for status: StatusModifier in moving:
		var incoming: StatusModifier = StatusCatalog.create(status.status_id, target as Node2D, status.stacks)
		engine.remove_modifier(status)
		if incoming == null:
			continue

		var existing: StatusModifier = engine.find_status(target, incoming.status_id)
		if existing:
			existing.merge(incoming)
			existing.play_applied_feedback(incoming.stacks)
		else:
			engine.add_modifier(incoming)
			incoming.play_applied_feedback(incoming.stacks)
		announce_status_applied(target, incoming.status_id, incoming.stacks)
