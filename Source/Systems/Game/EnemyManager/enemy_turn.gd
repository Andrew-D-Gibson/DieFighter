class_name EnemyTurn
extends RefCounted
## Rolling the ships' intent tables, and playing out the enemy turn.
##
## EnemyManager decides when; this decides how. Both read the roster as the
## manager has it at that moment, so a ship that dies partway (a Burn tick)
## drops out of what follows.


## Rolls each of [param ships]' tables, then binds the slots that act on
## another ship. Binding waits until every table is in, because who a slot can
## pick depends on the rest of [param roster].
static func roll_tables(ships: Array[Enemy], roster: Array[Enemy], take_forced: bool = true) -> void:
	for enemy: Enemy in ships:
		if is_instance_valid(enemy):
			enemy.generate_turn_actions(EnemyActionSituation.for_ship(enemy, roster), take_forced)
	EnemyTargetBinder.bind(ships, roster)


## How many times one enemy turn may go round the ships. Relays can't loop
## (EnemyTargetBinder), so a chain is at most one hop per ship; this is only
## the backstop that keeps a turn from never ending.
const MAX_PASSES: int = 8


## Plays one enemy turn and announces its end. [param roster] returns the
## ships still in the fight; it's asked again after statuses tick.
static func play(roster: Callable, tree: SceneTree) -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine:
		return

	# The player can end their turn while the dice they just spent are still
	# being dragged across the screen. Nothing acts until they've landed.
	await TractorBeam.wait_for_landings(tree)
	if not _engine_alive(engine):
		return

	# Turn-end hazards go off now, with the player's dice in the ships' hands
	# and before any ship reads them. They queue onto the engine, so the wait
	# below lets them resolve fully first.
	Events.enemy_turn_starting.emit()

	# Statuses tick first, and resolve completely before any ship acts, so a
	# ship that burns to death here never takes its turn.
	engine.tick_statuses()
	if engine.currently_processing_queue:
		await engine.finished_processing_queue
	if not _engine_alive(engine):
		return

	# Ships go left to right, each spending everything it holds before the
	# next starts. A die relayed to a ship whose turn has already gone waits
	# in its hold, so the round comes back for it once everyone has gone, and
	# keeps going round until no ship has a die left to spend.
	var taken_turn: Array[Enemy] = []
	for _pass: int in range(MAX_PASSES):
		var acted: bool = false
		# A copy: ships leave the roster while the turn resolves.
		var ships: Array[Enemy] = (roster.call() as Array[Enemy]).duplicate()
		for enemy: Enemy in ships:
			if not is_instance_valid(enemy) or enemy.health.health <= 0:
				continue
			if enemy in taken_turn:
				if not enemy.has_dice_to_spend():
					continue
				enemy.run_relayed_dice()
			else:
				if not enemy.holds_dice():
					continue
				taken_turn.append(enemy)
				enemy.run_turn()
			acted = true
			await _drain(engine, tree)
			if not _engine_alive(engine):
				return
		if not acted:
			break

	# A jump resolved inside the turn shuts the engine down, which releases
	# the await above. That turn belongs to a scenario already left; announcing
	# its end would start a player turn in the new one.
	if not _engine_alive(engine):
		return

	Events.enemy_turn_over.emit()


## Waits for whatever a ship just queued to resolve.
##
## finished_processing_queue only fires if there was a queue to finish. A ship
## whose actions resolve without yielding is already done by now; awaiting
## the signal then would hang the game, because the player's next turn waits
## on enemy_turn_over.
static func _drain(engine: ScenarioEngine, tree: SceneTree) -> void:
	if engine.currently_processing_queue:
		await engine.finished_processing_queue
	else:
		await tree.process_frame


## Untyped: by the time a turn checks, a jump may have freed the engine, and
## a freed object can't be passed as a ScenarioEngine.
static func _engine_alive(engine: Variant) -> bool:
	return is_instance_valid(engine) and not (engine as ScenarioEngine).is_shut_down()
