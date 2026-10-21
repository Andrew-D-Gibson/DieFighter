class_name AutoPilotTelemetry
extends RefCounted
## Tallies what happened in a run, for balance: what each tile did, what each
## enemy did, and how each scenario visit went. tools/autoplay_report.py reads
## the totals across a batch.
##
## Read off the scenario engine as events resolve (the same feed DebugLogger
## logs), so a new tile or enemy action is counted without this learning
## about it. Amounts are what resolved, after modifiers: damage is what was
## dealt before shields, not hull lost.
##
## Everything is keyed by name, not by node, so the totals are plain data and
## two runs of one seed tally identically.

## Tile name → {activations, damage, shields, heal, charge, statuses}.
var tiles: Dictionary = {}
## Enemy name → {actions: {action: uses}, damage_to_player, destroyed, escaped}.
var enemies: Dictionary = {}
## What dealt the last damage to the player: "Ship: Action", or "environment".
var last_hit: String = ""

var _engine: ScenarioEngine
## The action each ship is in the middle of, by instance id. An enemy action
## resolves before the effects in its chain, so those effects are its.
var _acting: Dictionary[int, String] = {}
var _visit: Dictionary = {}


## Follows [param engine], the current scenario's. Safe to call every frame.
func follow(engine: ScenarioEngine) -> void:
	if engine == null or engine == _engine:
		return
	_engine = engine
	_acting.clear()
	engine.event_resolved.connect(_on_event_resolved)


## A scenario has started: the visit starts counting.
func begin_visit(scenario: String, sector: int, map_index: int, turn: int) -> void:
	var player: Player = Globals.player
	_visit = {
		"scenario": scenario,
		"sector": sector,
		"map_index": map_index,
		"arrived_turn": turn,
		"fought": false,
		"won": false,
		"offers": 0,
		"claimed": 0,
		"bought": 0,
		"repairs": 0,
		"sold": 0,
		"hull_start": player.health.health,
		"money_start": AutoPilotSnapshot.credits(),
		"dice_start": player.num_of_dice,
		"damage_taken": {},
	}


## A fight's first turn. Every fight has one, including a fight fled into,
## which never leaves combat and so never starts it.
func on_fight_started() -> void:
	if not _visit.is_empty():
		_visit["fought"] = true


## A salvage offer came on show.
func on_salvage_offered() -> void:
	if not _visit.is_empty():
		_visit["offers"] += 1


## The player took a salvage choice ([param bought] false) or bought from
## the shop.
func on_item_taken(bought: bool) -> void:
	if not _visit.is_empty():
		_visit["bought" if bought else "claimed"] += 1


## The player bought a repair, or sold a tile ([param sold]), at a repair
## station.
func on_station_used(sold: bool) -> void:
	if not _visit.is_empty():
		_visit["sold" if sold else "repairs"] += 1


func on_combat_won() -> void:
	if not _visit.is_empty():
		_visit["won"] = true


## The visit is over, as [param how]: "left" (by jumping), "died" or
## "run_over" (the bot gave up). Returns its transcript entry, or an empty
## dictionary if no visit was under way.
func end_visit(how: String, turn: int) -> Dictionary:
	if _visit.is_empty():
		return {}
	var visit: Dictionary = _visit
	_visit = {}
	var player: Player = Globals.player
	var result: String = how
	if how == "left":
		var in_combat: bool = Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT
		result = "fled" if in_combat else ("won" if visit["won"] else "passed")
	visit["type"] = "visit"
	visit["result"] = result
	visit["turns"] = turn - int(visit["arrived_turn"])
	visit["hull_lost"] = int(visit["hull_start"]) - player.health.health
	visit["money_gained"] = AutoPilotSnapshot.credits() - int(visit["money_start"])
	visit["dice_lost"] = int(visit["dice_start"]) - player.num_of_dice
	for key: String in ["hull_start", "money_start", "dice_start", "arrived_turn"]:
		visit.erase(key)
	return visit


## A ship left the fight: shot down, or got away.
func on_enemy_left(ship: Enemy) -> void:
	var stats: Dictionary = _enemy(ship)
	if ship.health.health <= 0:
		stats["destroyed"] += 1
	else:
		stats["escaped"] += 1


## The tiles on the grid, by name, for the run's result.
static func build() -> Array[String]:
	var names: Array[String] = []
	var cells: Array[Vector2i] = Globals.tile_grid.tile_locations.keys()
	cells.sort()
	for cell: Vector2i in cells:
		names.append(_name_of(Globals.tile_grid.tile_locations[cell]))
	return names


func _on_event_resolved(event: EffectEvent) -> void:
	if event is TileActivationEvent:
		var activation: TileActivationEvent = event as TileActivationEvent
		if is_instance_valid(activation.tile):
			_tile(activation.tile)["activations"] += 1
		return
	if event is EnemyActionEvent:
		var action_event: EnemyActionEvent = event as EnemyActionEvent
		if is_instance_valid(action_event.enemy) and action_event.action:
			var action_name: String = action_event.action.name
			_acting[action_event.enemy.get_instance_id()] = action_name
			var actions: Dictionary = _enemy(action_event.enemy)["actions"]
			actions[action_name] = actions.get(action_name, 0) + 1
		return

	var source: Node = event.effect_source if is_instance_valid(event.effect_source) else null
	var from_tile: Tile = source as Tile
	if event is DamageEvent:
		_count_damage(event, from_tile)
	elif from_tile and event.amount > 0:
		if event is ShieldEvent:
			_tile(from_tile)["shields"] += event.amount
		elif event is HealEvent:
			_tile(from_tile)["heal"] += event.amount
		elif event is ChangeEngineChargeEvent:
			_tile(from_tile)["charge"] += event.amount
		elif event is ApplyStatusEvent:
			_tile(from_tile)["statuses"] += event.amount * _live_targets(event)


func _count_damage(event: EffectEvent, from_tile: Tile) -> void:
	for target: Node in event.targets:
		if not is_instance_valid(target):
			continue
		if target is Player:
			var source: String = _hit_source(event)
			last_hit = source
			if not _visit.is_empty():
				var taken: Dictionary = _visit["damage_taken"]
				taken[source] = taken.get(source, 0) + event.amount
			if is_instance_valid(event.actor) and event.actor is Enemy:
				_enemy(event.actor as Enemy)["damage_to_player"] += event.amount
		elif from_tile:
			_tile(from_tile)["damage"] += event.amount


## Who hurt the player: the ship and the action it was spending, or the
## environment (a hazard, the redline) when the player's own side did.
func _hit_source(event: EffectEvent) -> String:
	var actor: Node = event.actor if is_instance_valid(event.actor) else null
	if actor is Enemy:
		var ship: Enemy = actor as Enemy
		var action: String = _acting.get(ship.get_instance_id(), "")
		var ship_name: String = ship.enemy_resource.enemy_name
		return "%s: %s" % [ship_name, action] if action != "" else ship_name
	return "environment"


func _tile(tile: Tile) -> Dictionary:
	var tile_name: String = _name_of(tile)
	if not tiles.has(tile_name):
		tiles[tile_name] = {"activations": 0, "damage": 0, "shields": 0, "heal": 0, "charge": 0, "statuses": 0}
	return tiles[tile_name]


func _enemy(ship: Enemy) -> Dictionary:
	var ship_name: String = ship.enemy_resource.enemy_name
	if not enemies.has(ship_name):
		enemies[ship_name] = {"actions": {}, "damage_to_player": 0, "destroyed": 0, "escaped": 0}
	return enemies[ship_name]


static func _name_of(tile: Tile) -> String:
	return DebugLogFormat.label(tile).trim_prefix("[").trim_suffix("]")


static func _live_targets(event: EffectEvent) -> int:
	var count: int = 0
	for target: Node in event.targets:
		if is_instance_valid(target):
			count += 1
	return count
