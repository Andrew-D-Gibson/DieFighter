class_name ReckoningDirector
extends Node
## The Reckoning (LORE.md §7): the secret fight against Fate itself, behind the
## last boss for a player who knows the secret and has carved every face of
## Fate's Die. Fate can't be killed. The player wins by filling an escape-
## velocity meter (the Vanguard Drive turns dice into it) while:
##   - Fate throws the die they carved at the start of every round, and the
##     face that comes up bends the round (FateFaceResource.reckoning_chain);
##   - the hole spits back every ship they destroyed, in the reverse order of
##     their deaths, the very first kill last (the Tally), then its own;
##   - the event horizon eats the grid a column at a time;
##   - the ships they saved fly into the gaps as ally tiles.
##
## Lives beside the other run systems in main.tscn and wakes only while the
## loaded scenario is [member scenario].

## Every Fate-rolled round, and the escape: what the Reckoning's UI watches.
signal horizon_changed()

@export var scenario: ScenarioResource
## The state every echo of the Tally and every Spilled ship fights in.
@export var echo_state: ScenarioShipState
## What the hole sends once the Tally is spent, a wave at a time, round robin.
@export var spilled_pool: Array[EnemyResource] = []
## Ships per Spilled wave.
@export var spilled_wave_size: int = 3
## The tile a saved ship flies in as, and the one a spared ship's Debt is.
@export var ally_tile: TileResource
@export var debt_tile: TileResource
## Stands in for the engine charger for the length of the fight.
@export var vanguard_drive: TileResource

@export_category('Tuning')
## The escape takes this many full drives (LORE.md §7: "around 3x").
@export var escape_goal_multiplier: float = 3.0
## The horizon eats a column every this many steps. One step a round, more
## when Fate rolls Hunger.
@export var horizon_steps_per_column: int = 3
## Columns the horizon leaves, however long the fight runs.
@export var columns_kept: int = 2
## How echoes of the Tally look: stretched through the hole, gone purple.
@export var echo_tint: Color = Color("#c552f1")
## How far toward echo_tint an echo is washed, 0 to 1.
@export_range(0.0, 1.0) var echo_cloak: float = 0.35

const _CARVE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _SWALLOW_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")

static var _instance: ReckoningDirector = null

var _running: bool = false
var _escaping: bool = false
var _waves: Array[Array] = []
var _wave_index: int = 0
var _spilled_index: int = 0
var _escape: int = 0
var _goal: int = 1
var _horizon_steps: int = 0
var _columns_eaten: Array[int] = []
var _allies_waiting: Array[Dictionary] = []
var _round: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _engine_tile: Tile = null
var _engine_tile_resource: TileResource = null
## The face the last throw showed, for the UI.
var last_face: FateDie.Face = FateDie.Face.BLANK


## The director while the Reckoning is being fought, else null.
static func active() -> ReckoningDirector:
	if is_instance_valid(_instance) and _instance._running:
		return _instance
	return null


## Whether [param candidate] is the Reckoning's scenario.
static func is_reckoning(candidate: ScenarioResource) -> bool:
	return is_instance_valid(_instance) and _instance.scenario != null and candidate != null \
		and candidate.resource_path == _instance.scenario.resource_path


func _ready() -> void:
	_instance = self
	add_to_group(&"reckoning_director")
	Events.load_scenario.connect(_on_load_scenario)
	Events.first_turn_start.connect(_on_round_start)
	Events.player_turn_start.connect(_on_round_start)
	Events.player_turn_over.connect(_bank_engine_charge)
	Events.enemy_turn_over.connect(_on_round_over)
	Events.enemy_left.connect(_on_enemy_left)
	Events.player_destroyed.connect(_on_player_destroyed)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# ── Public: read by the UI and by the Reckoning's effects ───────────────────

func escape_velocity() -> int:
	return _escape


func escape_goal() -> int:
	return _goal


## Rounds until the horizon next takes a column, or -1 when it has taken all
## it will.
func rounds_until_swallow() -> int:
	if _eatable_columns().size() <= _columns_eaten.size():
		return -1
	var next_at: int = horizon_steps_per_column * (_columns_eaten.size() + 1)
	return maxi(1, next_at - _horizon_steps)


## The face Fate will throw at the start of next round, rolled a round
## ahead so "You"'s die can drift toward it (RECKONING_ENDINGS.md §4).
## BLANK until the first throw.
func upcoming_face() -> FateDie.Face:
	return FateDie.Face.BLANK


func waves_left() -> int:
	return maxi(0, _waves.size() - _wave_index)


func allies_waiting() -> int:
	return _allies_waiting.size()


## Charge for the escape. [param from] is where the motes fly from.
func add_escape_velocity(amount: int, from: Node2D = null) -> void:
	if not _running or _escaping or amount == 0:
		return
	_escape = clampi(_escape + amount, 0, _goal)
	Events.escape_velocity_changed.emit(_escape, _goal)
	if from and is_instance_valid(from):
		Juice.sparkle(from, from.global_position, Globals.purple, 6, 30.0, true)
	if _escape >= _goal:
		_escape_the_hole()


## The horizon comes [param steps] closer, eating a column each time it has
## come horizon_steps_per_column closer.
func advance_horizon(steps: int) -> void:
	if not _running or _escaping:
		return
	_horizon_steps += steps
	while _running and not _escaping and _horizon_steps >= horizon_steps_per_column * (_columns_eaten.size() + 1):
		var eatable: Array[int] = _eatable_columns()
		if _columns_eaten.size() >= eatable.size():
			break
		await _swallow_column(eatable[_columns_eaten.size()])
	horizon_changed.emit()


## Mercy: the next ship the player saved flies in, into a cell the horizon ate
## if there is one, else any free cell.
func summon_ally() -> void:
	if not _running or _escaping:
		return
	if _allies_waiting.is_empty():
		Juice.callout_at(Globals.tile_grid, Globals.tile_grid.global_position + Vector2(60, 0),
			tr("FATE_CALLOUT_NO_ONE_CAME"), Globals.green.darkened(0.3))
		return
	var cell: Vector2i = _free_cell_for_ally()
	if cell == Vector2i(-1, -1):
		return
	await _place_ally(cell, _allies_waiting.pop_front())


# ── The fight's life ────────────────────────────────────────────────────────

func _on_load_scenario(loaded: ScenarioResource) -> void:
	if not is_reckoning(loaded):
		if _running:
			_stop()
		return
	_begin(loaded)


func _begin(loaded: ScenarioResource) -> void:
	_running = true
	_escaping = false
	_wave_index = 0
	_spilled_index = 0
	_escape = 0
	_horizon_steps = 0
	_columns_eaten.clear()
	_round = 0
	last_face = FateDie.Face.BLANK
	_rng.seed = hash([loaded.scenario_seed, "reckoning"])

	var ledger: FateLedger = Globals.fate_ledger
	ledger.in_reckoning = true
	# A player who never paid the tithe never paid into the deal: the
	# Rearguard they killed stay dead.
	var skip: Array[String] = []
	if ledger.refused_every_tithe():
		skip.append("rearguard")
	_waves = FateLedger.tally_waves(ledger.kills, skip)
	_allies_waiting = ledger.allies.duplicate(true)

	_goal = maxi(1, roundi(Globals.player.max_engine_charge * escape_goal_multiplier))
	Events.escape_velocity_changed.emit(_escape, _goal)

	# The engine is the same one the fight runs on, made fresh for this
	# scenario just before this listener.
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		engine.add_modifier(HorizonModifier.new())

	_swap_in_vanguard_drive()
	_spawn_wave(_next_wave(), false)
	horizon_changed.emit()


func _stop() -> void:
	_running = false
	_escaping = false
	_restore_engine_tile()
	if Globals.tile_grid:
		Globals.tile_grid.clear_swallowed_cells()


## The dying Vanguard's drive (LORE.md §4) takes the engine charger's place.
func _swap_in_vanguard_drive() -> void:
	if not vanguard_drive:
		return
	_engine_tile = get_tree().get_first_node_in_group(&"engine_charger").get_node_or_null(^"EngineChargerTile") as Tile \
		if get_tree().get_first_node_in_group(&"engine_charger") else null
	if not _engine_tile:
		return
	if _engine_tile.tile_resource != vanguard_drive:
		_engine_tile_resource = _engine_tile.tile_resource
		_engine_tile.tile_resource = vanguard_drive


func _restore_engine_tile() -> void:
	if is_instance_valid(_engine_tile) and _engine_tile_resource:
		_engine_tile.tile_resource = _engine_tile_resource
	_engine_tile = null
	_engine_tile_resource = null


# ── Rounds: Fate throws the die ─────────────────────────────────────────────

func _on_round_start() -> void:
	if not _running or _escaping or Globals.state_manager.state != GameStateManager.GameState.IN_COMBAT:
		return
	_round += 1
	var die: FateDie = Globals.fate_ledger.die
	var slot: int = die.roll(_rng)
	var face: FateDie.Face = die.face_at(slot)
	last_face = face
	Events.fate_die_rolled.emit(slot, face)

	var res: FateFaceResource = FateFaceCatalog.get_face(face)
	var engine: ScenarioEngine = ScenarioEngine.current()
	if res == null or engine == null:
		return
	var chain: EffectChain = res.chain_for(Globals.fate_ledger)
	if chain == null:
		return
	var event: FateRollEvent = FateRollEvent.new()
	event.chain = chain
	event.actor = Globals.player
	event.effect_source = Globals.player
	engine.queue_event(event)


## Charge the drive built up this turn is banked toward the escape, so every
## purple tile on the grid helps.
func _bank_engine_charge() -> void:
	if not _running or _escaping or not is_instance_valid(Globals.player):
		return
	var charge: int = Globals.player.engine_charge
	if charge <= 0:
		return
	Globals.player.engine_charge = 0
	var gauge: Node2D = get_tree().get_first_node_in_group(&"engine_charger") as Node2D
	add_escape_velocity(charge, gauge)


func _on_round_over() -> void:
	if not _running or _escaping:
		return
	await advance_horizon(1)


# ── The Tally ───────────────────────────────────────────────────────────────

## The next wave's enemy ids: the Tally's, then the hole's own.
func _next_wave() -> Array:
	if _wave_index < _waves.size():
		_wave_index += 1
		return _waves[_wave_index - 1]
	var wave: Array = []
	if spilled_pool.is_empty():
		return wave
	for i: int in spilled_wave_size:
		var res: EnemyResource = spilled_pool[_spilled_index % spilled_pool.size()]
		_spilled_index += 1
		wave.append(ContentRegistry.get_enemy_id(res.resource_path))
	return wave


func _on_enemy_left(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
	if not _running or _escaping:
		return
	for other: Enemy in Globals.enemy_manager.get_alive_enemies():
		if other != ship and is_instance_valid(other) and other.is_hostile():
			return
	# Spawned before the combat check that follows this signal reads the
	# roster, so the fight never ends between waves.
	_spawn_wave(_next_wave(), true)


func _spawn_wave(ids: Array, fly_in: bool) -> void:
	var spawns: Array[EnemyStateRewardResource] = []
	for id: Variant in ids:
		var path: String = ContentRegistry.get_enemy_path(str(id))
		if path.is_empty():
			continue
		var spawn: EnemyStateRewardResource = EnemyStateRewardResource.new()
		spawn.enemy_resource = load(path) as EnemyResource
		spawn.starting_state = echo_state
		spawns.append(spawn)
	if spawns.is_empty():
		return
	var ships: Array[Enemy] = Globals.enemy_manager.spawn_enemies(spawns, scenario)
	for ship: Enemy in ships:
		# Not one of the scenario's own ships: nothing for a save to restore.
		ship.spawn_index = -1
		_tint_echo(ship)
	_announce_wave(ships, fly_in)


## Gives a ship the look of something that came back through the hole: part
## way to Fate's purple, through its shader's own cloak (which ignores
## modulate). Each ship's material is its own (resource_local_to_scene).
func _tint_echo(ship: Enemy) -> void:
	if not ship.graphics_manager or not is_instance_valid(ship.graphics_manager.ship_graphics):
		return
	var material: ShaderMaterial = ship.graphics_manager.ship_graphics.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(&"cloak_main_color", echo_tint)
	material.set_shader_parameter(&"cloak_bg_color", Color(echo_tint.darkened(0.45), 1.0))
	material.set_shader_parameter(&"cloak_amount", echo_cloak)


## The wave's first ship speaks once it's on screen: after the arrival for the
## first wave, after its own fly-in for the rest.
func _announce_wave(ships: Array[Enemy], fly_in: bool) -> void:
	if ships.is_empty():
		return
	var key: String = _wave_line_key()
	if fly_in:
		await Globals.enemy_manager.fly_in_reinforcements(ships)
	else:
		await Events.enemies_arrived
	if not _running:
		return
	var speaker: Enemy = ships[0]
	if is_instance_valid(speaker) and speaker.health.health > 0:
		speaker.dialogue_manager.show_dialogue(tr(key), echo_state.faction)


## The line the wave just spawned speaks: the Tally's echoes in turn, the
## very first kill's own, then the hole's.
func _wave_line_key() -> String:
	if _wave_index <= _waves.size() and _spilled_index == 0 and not _waves.is_empty():
		if _wave_index == _waves.size():
			return "FATE_ECHO_LINE_FIRST"
		return "FATE_ECHO_LINE_%d" % ((_wave_index - 1) % 4 + 1)
	return "FATE_SPILLED_LINE_%d" % ((_spilled_index / maxi(1, spilled_wave_size) - 1) % 3 + 1)


# ── The horizon ─────────────────────────────────────────────────────────────

## The grid's columns the horizon may take, left (Fate's side) first.
func _eatable_columns() -> Array[int]:
	var columns: Array[int] = []
	if not Globals.tile_grid:
		return columns
	for cell: Vector2i in Globals.tile_grid.get_cells():
		if cell.x not in columns:
			columns.append(cell.x)
	columns.sort()
	return columns.slice(0, maxi(0, columns.size() - columns_kept))


func _swallow_column(column: int) -> void:
	_columns_eaten.append(column)
	var grid: TileGrid = Globals.tile_grid
	var cells: Array[Vector2i] = []
	for cell: Vector2i in grid.get_cells():
		if cell.x == column:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)

	Events.play_sound.emit(_SWALLOW_SFX)
	Events.camera_shake_large.emit(false)
	Events.glitch_burst.emit(220)
	for cell: Vector2i in cells:
		grid.swallow_cell(cell)
		var tile: Tile = grid.tile_locations.get(cell)
		if is_instance_valid(tile):
			_tile_falls_in(tile)
	Events.horizon_swallowed_column.emit(column)
	Juice.callout_at(grid, grid.grid_to_global_pos(cells[0]) + Vector2(0, -16) if not cells.is_empty() else grid.global_position,
		tr("FATE_CALLOUT_HORIZON"), Globals.purple, true)
	await get_tree().create_timer(0.9).timeout

	# The ships the player saved fly into the hole the horizon left.
	for cell: Vector2i in cells:
		if _allies_waiting.is_empty() or not _running:
			break
		if grid.is_grid_pos_open(cell):
			await _place_ally(cell, _allies_waiting.pop_front())


## A tile the horizon takes: it stops taking dice at once, spins down into the
## dark and is gone for the rest of the fight.
func _tile_falls_in(tile: Tile) -> void:
	tile.can_accept_dice.enabled = false
	Juice.sparkle(tile, tile.global_position, Globals.purple, 10, 30.0)
	var tween: Tween = tile.create_tween().set_parallel(true)
	tween.tween_property(tile, "scale", Vector2.ZERO, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(tile, "rotation", TAU * 0.5, 0.8)
	tween.tween_property(tile, "modulate", Color(0.6, 0.2, 0.9, 0.0), 0.8)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(tile) and Globals.tile_grid:
			Globals.tile_grid.remove_tile(tile)
	)


func _free_cell_for_ally() -> Vector2i:
	var grid: TileGrid = Globals.tile_grid
	for cell: Vector2i in grid.get_swallowed_cells():
		if grid.is_grid_pos_open(cell):
			return cell
	for cell: Vector2i in grid.get_cells():
		if grid.is_grid_pos_open(cell) and not grid.is_cell_locked(cell):
			return cell
	return Vector2i(-1, -1)


## What a saved ship that rode along as the escort says as it comes back,
## by FateLedger.ESCORT_*.
const _ESCORT_LINE_DELAY_SECONDS: float = 0.5
const _ESCORT_LINE_OFFSET: Vector2 = Vector2(0, -12)
const _ESCORT_LINES: Dictionary[String, String] = {
	FateLedger.ESCORT_DELIVERED: "RECKONING_ESCORT_DELIVERED",
	FateLedger.ESCORT_LOST: "RECKONING_ESCORT_LOST",
}


func _place_ally(cell: Vector2i, entry: Dictionary) -> void:
	var kind: String = str(entry.get("kind", FateLedger.KIND_ALLY))
	var resource: TileResource = debt_tile if kind == FateLedger.KIND_DEBT else ally_tile
	if resource == null:
		return
	var tile: Tile = Globals.tile_grid.place_temporary_tile(resource, cell)
	if tile == null:
		return
	var ship_name: String = ""
	var path: String = ContentRegistry.get_enemy_path(str(entry.get("enemy", "")))
	if not path.is_empty():
		var ship: EnemyResource = load(path) as EnemyResource
		if ship:
			ship_name = ship.display_name()
	Events.play_sound.emit(_CARVE_SFX)
	Juice.ring(tile, tile.global_position, Globals.green if kind != FateLedger.KIND_DEBT else Globals.red, 20.0)
	if not ship_name.is_empty():
		Juice.callout(tile, ship_name, Globals.green if kind != FateLedger.KIND_DEBT else Globals.red)
	# A ship that rode along as the escort says how that went (EscortKeeper):
	# home safe, or lost on the way and back to try again.
	var line: String = _ESCORT_LINES.get(str(entry.get("escort", "")), "")
	if not line.is_empty():
		# A beat after the name, a line above it, so the two read in order
		# instead of running into each other.
		await get_tree().create_timer(_ESCORT_LINE_DELAY_SECONDS).timeout
		if is_instance_valid(tile):
			Juice.callout_at(tile, tile.global_position + _ESCORT_LINE_OFFSET, tr(line), Globals.green)
	await get_tree().create_timer(0.35).timeout


# ── Endings ─────────────────────────────────────────────────────────────────

## The meter is full: the ship rolls off the table (LORE.md §8).
func _escape_the_hole() -> void:
	if _escaping:
		return
	_escaping = true
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		engine.shutdown()
	CollectionManager.record_fate_ending(&"escaped")
	Events.fate_ending.emit(&"escaped")
	Events.camera_shake_large.emit(true)
	Events.glitch_burst.emit(400)
	Events.jump.emit()
	if is_instance_valid(Globals.player):
		Globals.player.rattle_dice_for_jump(BackgroundManager.JUMP_RAMP_UP_TIME)
	if Globals.background_manager:
		Globals.background_manager.set_jump_tint(Globals.white, Globals.white)
		await Globals.background_manager.play_jump_intro()
	if is_instance_valid(Globals.player):
		Globals.player.settle_dice_after_jump()
	Juice.screen_flash(self, Globals.white, 1.0, 0.8)
	_running = false
	Events.victory.emit()


## The hull went: the player falls in and becomes one of the Spilled.
func _on_player_destroyed() -> void:
	if not _running or _escaping:
		return
	_running = false
	var ship_id: String = String(Globals.state_manager.current_game_save.ship_id) if Globals.state_manager else ""
	CollectionManager.record_fate_ending(&"fell_in", ship_id, _prized_tile_id())
	Events.fate_ending.emit(&"fell_in")


## The tile a fallen ship carries into the hole: its rarest, first in reading
## order, so the same grid always gives the same tile.
func _prized_tile_id() -> String:
	if not Globals.tile_grid:
		return ""
	var best: Tile = null
	var cells: Array[Vector2i] = Globals.tile_grid.tile_locations.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		var tile: Tile = Globals.tile_grid.tile_locations[cell]
		if not is_instance_valid(tile) or not tile.tile_resource or not tile.tile_resource.offered_as_reward:
			continue
		if best == null or tile.tile_resource.rarity > best.tile_resource.rarity:
			best = tile
	return ContentRegistry.get_tile_id(best.tile_resource.resource_path) if best else ""
