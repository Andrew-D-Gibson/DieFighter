class_name AutoPilotSnapshot
extends RefCounted
## Plain-data pictures of the game for the AutoPilot's transcript.
##
## Everything here is gameplay state, never positions or timings, so two runs
## from the same seed should write identical snapshots. Where they differ is
## where determinism broke.


## The board as the player sees it at the start of their turn.
static func turn(scenario_name: String) -> Dictionary:
	var player: Player = Globals.player
	var hand: Array[int] = []
	for die: Dice in player.dice_manager.queue:
		if is_instance_valid(die):
			hand.append(die.value)

	var ships: Array[Dictionary] = []
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		ships.append(enemy(ship))

	return {
		"sector": Globals.state_manager.current_game_save.sector_index,
		"map_index": Globals.map.current_scenario_index,
		"scenario": scenario_name,
		"hull": player.health.health,
		"shields": player.health.shields,
		"charge": player.engine_charge,
		"money": credits(),
		"dice_owned": player.dice_owned(),
		"hand": hand,
		"tiles": tiles(),
		"ships": ships,
		"target": ship_label(Globals.targeting_computer.targeted_enemy),
	}


static func enemy(ship: Enemy) -> Dictionary:
	var intents: Array[String] = []
	for action: EnemyActionResource in ship.turn_actions:
		intents.append(action.name if action else "")

	var statuses: Dictionary[String, int] = {}
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		for status: StatusModifier in engine.statuses_on(ship):
			statuses[String(status.status_id)] = status.stacks

	return {
		"ship": ship_label(ship),
		"hull": ship.health.health,
		"shields": ship.health.shields,
		"intents": intents,
		"statuses": statuses,
	}


## The player's balance counting coins still flying to the counter. A payout
## only lands on the balance when its coin arrives, and how long a coin
## floats first is cosmetic randomness, so the bare balance at any instant
## isn't reproducible; what the player has earned is.
static func credits() -> int:
	var total: int = Globals.player.money
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for coin: Node in tree.get_nodes_in_group("Money"):
		var particle: MoneyParticle = coin as MoneyParticle
		# A coin that landed this frame has paid out and waits to be freed.
		if particle and particle.is_payout() and not particle.is_queued_for_deletion():
			total += particle.amount
	return total


## Grid tiles by cell, with the uses each has left this turn.
static func tiles() -> Dictionary[String, String]:
	var layout: Dictionary[String, String] = {}
	var cells: Array[Vector2i] = Globals.tile_grid.tile_locations.keys()
	cells.sort()
	for cell: Vector2i in cells:
		var tile: Tile = Globals.tile_grid.tile_locations[cell]
		layout["%d,%d" % [cell.x, cell.y]] = "%s (%d)" % [tile.tile_resource.tile_name, tile.uses_remaining]
	return layout


## A ship's name plus its spawn slot, which tells apart two of the same ship.
static func ship_label(ship: Enemy) -> String:
	if not is_instance_valid(ship):
		return ""
	return "%s#%d" % [ship.enemy_resource.enemy_name, ship.spawn_index]
