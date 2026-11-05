class_name OutriggerSync
extends Node
## The Outrigger's drive: its two pods each run off their own engine nacelle,
## and burning them evenly spools the jump drive.
##
## During a fight, every die that activates a tile (placed from the hand or
## Fed, a hologram as much as a real die) adds its face to that tile's pod's
## thrust for the turn. When the player's turn ends, the drive charges by the
## lower pod's thrust: what the two burned in step. Both pods exactly level
## (and above 0) also sets off ON_PODS_LEVEL on every tile, behind the charge.
##
## The rules at the edges:
## - A pod is a side of the grid's mirror line (TileGrid.mirror_of): port is
##   the cells left of it, starboard the cells right of it. A centre column,
##   on a grid that has one, belongs to neither.
## - The charge fills the drive to the jump gate and no further, so syncing
##   never redlines the player (the redline stays the business of
##   ADD_OVERCHARGE tiles). It goes through SyncChargeEvent and then a
##   ChangeEngineChargeEvent, so an engine blackout still blocks it.
## - Thrust is this turn's: it starts at 0 with each player turn
##   (player_turn_refresh) and each fight, not when the turn ends, so the
##   ON_PODS_LEVEL responses queued then still read it (pod_level). It's
##   cleared when a fight ends too: out of a fight there's no thrust and no
##   charge to earn (the drive is full on arrival and after a win).
##
## Tiles read it through two ship readings (SET_TO_SHIP_READING, ShipRules):
## - pod_lead: how many pips the source tile's pod is ahead of the other, not
##   counting the die activating it, so it's what the gauge showed as the die
##   was placed. Never below 0.
## - pod_level: the lower pod's thrust this turn.

## Thrust went up or was reset; the gauge redraws from thrust().
signal thrust_changed()

enum Pod { NONE = -1, PORT = 0, STARBOARD = 1 }

const READING_LEAD: StringName = &"pod_lead"
const READING_LEVEL: StringName = &"pod_level"

## This turn's thrust, by Pod.
var _thrust: Array[int] = [0, 0]
## The tile a die activated last, and what that die added to which pod, until
## the activation completes. A tile's chain plays (and reads pod_lead) inside
## its own activation, before any Feed it sets off starts the next, so this is
## always the die activating the tile reading it: pod_lead takes it back off,
## so the activating die doesn't count towards its own tile's lead.
var _crediting_tile: Tile = null
var _credited: int = 0
var _credited_pod: Pod = Pod.NONE


func _ready() -> void:
	add_to_group(ShipRules.READINGS_GROUP)
	Events.tile_activated_by_die.connect(_on_tile_activated_by_die)
	Events.tile_activation_complete.connect(_forget_credit)
	Events.player_turn_refresh.connect(reset)
	Events.start_combat.connect(reset)
	Events.combat_finished.connect(reset)
	Events.player_turn_over.connect(_on_player_turn_over)


## The active Outrigger rules in the scene, or null when another ship flies.
static func active(tree: SceneTree) -> OutriggerSync:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(ShipRules.READINGS_GROUP):
		if node is OutriggerSync and not node.is_queued_for_deletion():
			return node as OutriggerSync
	return null


## Which pod [param cell] is in, on a grid [param grid_width] cells wide.
static func pod_of(cell: Vector2i, grid_width: int) -> Pod:
	var mirrored_x: int = grid_width - 1 - cell.x
	if cell.x < mirrored_x:
		return Pod.PORT
	if cell.x > mirrored_x:
		return Pod.STARBOARD
	return Pod.NONE


## What ending the turn on [param port] and [param starboard] thrust adds to a
## drive at [param charge] whose gate is [param gate]: the lower thrust, as
## far as the gate.
static func charge_gain(port: int, starboard: int, charge: int, gate: int) -> int:
	return clampi(mini(port, starboard), 0, maxi(0, gate - charge))


## Whether [param port] and [param starboard] thrust count as level: equal,
## and above 0.
static func is_level(port: int, starboard: int) -> bool:
	return port == starboard and port > 0


## This turn's thrust in [param pod].
func thrust(pod: Pod) -> int:
	return _thrust[pod] if pod != Pod.NONE else 0


## The lower pod's thrust this turn.
func level() -> int:
	return mini(_thrust[Pod.PORT], _thrust[Pod.STARBOARD])


## The pod [param tile] sits in, or NONE when it's off the grid.
func pod_of_tile(tile: Tile) -> Pod:
	var grid: TileGrid = Globals.tile_grid
	if not is_instance_valid(grid) or not is_instance_valid(tile):
		return Pod.NONE
	var cell: Vector2i = grid.find_tile_pos(tile)
	if not grid.is_grid_pos_valid(cell):
		return Pod.NONE
	return pod_of(cell, grid.grid_width)


## What ending the turn right now would add to the drive: the gauge's "+N".
func projected_gain() -> int:
	if not is_in_play() or not is_instance_valid(Globals.player):
		return 0
	return charge_gain(_thrust[Pod.PORT], _thrust[Pod.STARBOARD],
		Globals.player.engine_charge, Globals.player.max_engine_charge)


## This turn's thrust, by Pod, if [param faces] were also burned on
## [param tiles] (each die, with its face, in the pod of its tile). For the
## AutoPilot's forecast of a move.
func thrust_after(tiles: Array[Tile], faces: Array[int]) -> Array[int]:
	var after: Array[int] = _thrust.duplicate()
	if not is_in_play():
		return after
	for i: int in mini(tiles.size(), faces.size()):
		var pod: Pod = pod_of_tile(tiles[i])
		if pod != Pod.NONE:
			after[pod] += faces[i]
	return after


## What ending the turn would add once [param tiles] had been activated with
## [param faces] (see thrust_after()), less what it would add now.
func gain_from(tiles: Array[Tile], faces: Array[int]) -> int:
	if not is_in_play() or not is_instance_valid(Globals.player):
		return 0
	var after: Array[int] = thrust_after(tiles, faces)
	var gate: int = Globals.player.max_engine_charge
	var charge: int = Globals.player.engine_charge
	return charge_gain(after[Pod.PORT], after[Pod.STARBOARD], charge, gate) - projected_gain()


## Whether thrust counts right now: only in a fight.
static func is_in_play() -> bool:
	return Globals.state_manager != null \
		and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT


func reset() -> void:
	_thrust = [0, 0]
	_forget_credit()
	thrust_changed.emit()


# ── Ship readings (ShipRules) ─────────────────────────────────────────────────

func has_ship_reading(key: StringName) -> bool:
	return key == READING_LEAD or key == READING_LEVEL


func ship_reading(key: StringName, context: EffectContext) -> int:
	match key:
		READING_LEVEL:
			return level()
		READING_LEAD:
			var tile: Tile = context.effect_source as Tile if context else null
			var pod: Pod = pod_of_tile(tile)
			if pod == Pod.NONE:
				return 0
			var mine: int = _thrust[pod]
			if tile == _crediting_tile and pod == _credited_pod:
				mine -= _credited
			return maxi(0, mine - _thrust[1 - pod])
	return 0


# ── The turn ──────────────────────────────────────────────────────────────────

func _on_tile_activated_by_die(tile: Tile, value: int) -> void:
	if not is_in_play():
		return
	var pod: Pod = pod_of_tile(tile)
	if pod == Pod.NONE:
		return
	_thrust[pod] += value
	_crediting_tile = tile
	_credited = value
	_credited_pod = pod
	thrust_changed.emit()


func _forget_credit() -> void:
	_crediting_tile = null
	_credited = 0
	_credited_pod = Pod.NONE


func _on_player_turn_over() -> void:
	if not is_in_play():
		return
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null or not is_instance_valid(Globals.player):
		return
	var port: int = _thrust[Pod.PORT]
	var starboard: int = _thrust[Pod.STARBOARD]
	var synced: int = mini(port, starboard)
	if synced > 0:
		var charge := SyncChargeEvent.new()
		charge.actor = Globals.player
		charge.effect_source = Globals.player
		charge.amount = synced
		charge.level = is_level(port, starboard)
		engine.queue_event(charge)
	if is_level(port, starboard):
		Events.pods_level.emit()
