class_name AutoPilotInvariants
extends RefCounted
## Things that should always hold while the game plays, checked at the
## moments they're meant to hold. A break is a bug the run didn't crash on:
## two turns at once, a die gone missing, a tile that ran out of uses and
## came back unlimited. Memory growth is watched too, but only as a warning:
## node counts wobble by one or two between runs of the same seed, so it
## can't be a violation in a transcript that has to replay identically.
##
## The AutoPilot reports the turn flow here as it happens, and asks for the
## board checks once things have settled. Each check returns violations as
## {check, detail}; an empty array means all is well.
##
## Counted independently of the code under test (the Player's own tallies),
## so a bug in that code can't hide itself.

var _player_turn_open: bool = false
var _enemy_turn_open: bool = false
## Memory at the first arrival, the baseline leak growth is measured from;
## empty until then.
var _baseline: Dictionary = {}
var _leaks_flagged: Dictionary[String, bool] = {}

## How far a count may climb above the first arrival's before the run is
## flagged as leaking. A scenario's own clutter comes and goes, within about
## a hundred nodes; a leak only grows. Something left behind every turn
## (hidden particles that never finish) passes this in a few dozen arrivals.
const _LEAK_LIMITS: Dictionary[String, int] = {"nodes": 250, "orphans": 200}


## A fight starts or ends, or a scenario loads: whose turn it is starts over.
func reset_turns() -> void:
	_player_turn_open = false
	_enemy_turn_open = false


func on_player_turn_start(in_transit: bool) -> Array[Dictionary]:
	var broken: Array[Dictionary] = []
	if _player_turn_open:
		broken.append(_violation("overlapping_player_turns", "a player turn started before the last one ended"))
	if _enemy_turn_open:
		broken.append(_violation("player_turn_during_enemy_turn", "a player turn started while the enemies were acting"))
	if in_transit:
		broken.append(_violation("player_turn_during_jump", "a player turn started mid-jump"))
	_player_turn_open = true

	var in_combat: bool = Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT
	if in_combat and _hand().is_empty():
		broken.append(_violation("empty_hand_at_turn_start", "a fight's turn started with nothing to play"))
	broken.append_array(check_board())
	return broken


func on_player_turn_over() -> void:
	_player_turn_open = false


func on_enemy_turn_starting() -> Array[Dictionary]:
	var broken: Array[Dictionary] = []
	if _enemy_turn_open:
		broken.append(_violation("overlapping_enemy_turns", "an enemy turn started before the last one ended"))
	_enemy_turn_open = true
	return broken


func on_enemy_turn_over() -> void:
	_enemy_turn_open = false


## Once an arrival has settled: the hand is dealt, so every real die the
## Fleet owns is in it (or already played onto a tile).
func on_arrival_settled() -> Array[Dictionary]:
	var broken: Array[Dictionary] = check_board()
	var owned: int = Globals.player.num_of_dice
	var held: int = real_dice_held()
	if held < owned:
		broken.append(_violation("dice_missing", "owns %d dice, holds %d after arriving" % [owned, held]))
	return broken


## What must hold at any settled moment.
func check_board() -> Array[Dictionary]:
	var broken: Array[Dictionary] = []
	var player: Player = Globals.player
	var owned: int = player.num_of_dice
	var held: int = real_dice_held()
	if held > owned:
		broken.append(_violation("dice_duplicated", "owns %d dice, holds %d" % [owned, held]))
	if owned < 1:
		broken.append(_violation("no_dice_owned", "the Fleet owns %d dice" % owned))

	if player.health.health > player.health.max_health:
		broken.append(_violation("hull_over_max", "hull %d of %d" % [player.health.health, player.health.max_health]))
	if player.health.shields < 0:
		broken.append(_violation("negative_shields", "shields %d" % player.health.shields))
	if player.engine_charge < 0 or player.engine_charge > player.charge_ceiling:
		broken.append(_violation("charge_out_of_range", "charge %d, ceiling %d" % [player.engine_charge, player.charge_ceiling]))
	if AutoPilotSnapshot.credits() < 0:
		broken.append(_violation("negative_money", "%d credits" % AutoPilotSnapshot.credits()))

	# A tile reparented onto the grid without a cell (taken from salvage onto
	# a full grid, say) floats there, unplayable and unsaved.
	for child: Node in Globals.tile_grid.get_children():
		var loose: Tile = child as Tile
		if loose and not loose.is_queued_for_deletion() \
		and not Globals.tile_grid.is_grid_pos_valid(Globals.tile_grid.find_tile_pos(loose)):
			broken.append(_violation("tile_without_cell", loose.tile_resource.tile_name))

	for cell: Vector2i in Globals.tile_grid.tile_locations:
		var tile: Tile = Globals.tile_grid.tile_locations[cell]
		# -1 means unlimited: a limited tile spent past zero would read as
		# never running out.
		if tile.tile_resource.uses_per_turn > 0 and tile.uses_remaining == -1:
			broken.append(_violation("limited_tile_unlimited", "%s at %d,%d" % [tile.tile_resource.tile_name, cell.x, cell.y]))
	return broken


## Memory a run is holding: nodes in the tree and nodes out of it. A node out
## of the tree and never freed is a leak, and it adds up over a long run.
static func memory() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}


## Real dice the player still has: in hand, on a tile, in a ship's hands or
## on the way to one. Shop stock has no host queue and isn't theirs; a die a
## ship flew off with has left the Dice group.
static func real_dice_held() -> int:
	var held: int = 0
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for node: Node in tree.get_nodes_in_group("Dice"):
		var die: Dice = node as Dice
		if die and not die.holographic and not die.is_queued_for_deletion() and die.host_queue != null:
			held += 1
	return held


## The counters in [param now] (from memory()) that have grown past their
## limit since the first arrival, each named once per run: "nodes_growing".
func leaks(now: Dictionary) -> Array[String]:
	if _baseline.is_empty():
		_baseline = now
		return []
	var growing: Array[String] = []
	for counter: String in _LEAK_LIMITS:
		if _leaks_flagged.has(counter) or now[counter] - _baseline[counter] <= _LEAK_LIMITS[counter]:
			continue
		_leaks_flagged[counter] = true
		growing.append("%s_growing" % counter)
	return growing


static func _hand() -> Array[Dice]:
	var hand: Array[Dice] = []
	for die: Dice in Globals.player.dice_manager.queue:
		if is_instance_valid(die):
			hand.append(die)
	return hand


static func _violation(check: String, detail: String) -> Dictionary:
	return {"check": check, "detail": detail}
