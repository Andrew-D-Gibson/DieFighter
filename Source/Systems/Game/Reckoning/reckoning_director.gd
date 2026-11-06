class_name ReckoningDirector
extends Node
## The Reckoning (RECKONING_ENDINGS.md): the secret last fight, behind the last
## boss for a player who knows the secret and has carved every face of Fate's
## Die. Fate can't be killed. The run deals three hands, and where the player
## sends their dice decides which they play:
##   - Save Yourself: the engine charger is the escape. Its limit is fixed at
##     three drives' worth as the fight begins, charge never banks away, and
##     a full bank lights the map's arrow: jump, Alone or with a Convoy.
##   - Save Others: the ships they saved jump in one at a time beside them
##     (ReckoningAllyWing) and leave carrying a die. The last die going that
##     way, before the bank is full, is the Last Die.
##   - Become Fate: once the Tally is spent the hole sends "You" (FateSelf),
##     and destroying it with an aimed die is Become Fate.
## Meanwhile Fate throws the carved die every round (FateFaceResource.
## reckoning_chain), the hole plays the run back an encounter at a time
## (ReckoningQueue), then sends its own Spilled. Hull gone, or an echo
## leaving with the last die, is Fell In.
##
## The ending is decided by ReckoningRules and played by ReckoningEndingPlayer,
## which ends the run itself.
##
## Lives beside the other run systems in main.tscn and wakes only while the
## loaded scenario is [member scenario].

@export var scenario: ScenarioResource
## The state every echo of the Tally, every Spilled ship and "You" fight in.
@export var echo_state: ScenarioShipState
## What the hole sends once the Tally is spent, a wave at a time, round robin.
@export var spilled_pool: Array[EnemyResource] = []
## Ships per Spilled wave.
@export var spilled_wave_size: int = 3
## Stands in for the engine charger for the length of the fight.
@export var vanguard_drive: TileResource
## "You": the player's own hull, sent once the Tally is spent. Its fire (the
## die's face times the Your Own Fire action's multiplier) is tuned there.
@export var self_resource: EnemyResource
## The table every saved ship flies with here, and the side it flies on.
@export var ally_table: EnemyTurnActionList
@export var ally_state: ScenarioShipState

@export_category('Tuning')
## The escape takes this many full drives, as the drive stood at the turn.
@export var escape_goal_multiplier: float = 3.0
## Echoes are memories: they come back with this share of their hull.
@export_range(0.1, 1.0, 0.05) var echo_hull_fraction: float = 0.5
## The bank's share past which an ally aboard tells the player not to wait.
@export_range(0.5, 1.0, 0.05) var nearly_full_fraction: float = 0.8
## A spared ship's strafing pass deals this many times a d6 to every hostile
## (the retired Old Debt tile's 3x die).
@export var debt_strafe_multiplier: int = 3
## Hunger brings no early wave while this many hostiles are already on the
## board, so a Hunger-heavy die can't stack waves without end.
@export var hunger_board_cap: int = 6
## Seconds the fight holds once its ending is decided before the film takes
## over, so the last thing that happened can be seen (an ally jumping out
## with the last die, "You" coming apart).
@export var ending_beat_seconds: float = 2.4
## How echoes of the Tally look: stretched through the hole, gone purple.
@export var echo_tint: Color = Color("#c552f1")
## How far toward echo_tint an echo is washed, 0 to 1.
@export_range(0.0, 1.0) var echo_cloak: float = 0.35

## What a saved ship that rode along as the escort says as it comes back, by
## FateLedger.ESCORT_*.
const ESCORT_LINES: Dictionary[String, String] = {
	FateLedger.ESCORT_DELIVERED: "RECKONING_ESCORT_DELIVERED",
	FateLedger.ESCORT_LOST: "RECKONING_ESCORT_LOST",
}

## Where echoes rise from, relative to their slots: out of the hole on the
## left. Allies jump in from the fleet on the right (ReckoningAllyWing).
const _ECHO_RISE: Vector2 = Vector2(-150.0, 30.0)
## The beat after the first kill's last words before the hole sends "You".
const _SELF_ENTRY_DELAY: float = 1.8
## The escape's sting, borrowed until it has its own cue (SOUND_EFFECTS_TODO).
const _ESCAPE_STING_TRACK: StringName = &"game_start_theme"

static var _instance: ReckoningDirector = null

var _running: bool = false
## An ending has been decided: nothing more happens in the fight.
var _ending: bool = false
## Fell In through the hull: the cockpit's death plays, and this ends the run.
var _death_claimed: bool = false
## Charge only counts once the fight's first turn starts: the arrival fills
## the drive for a moment before the fight empties it.
var _fight_started: bool = false
var _waves: Array[Dictionary] = []
var _wave_index: int = 0
var _spilled_index: int = 0
var _self_ship: Enemy = null
## Whether "You" has been sent: once, whatever became of it.
var _self_sent: bool = false
var _first_kill_ship: Enemy = null
var _goal: int = 1
var _bank_full: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The die's slot Fate will throw next round, rolled a round ahead.
var _next_slot: int = -1
var _round: int = 0
var _engine_tile: Tile = null
var _engine_tile_resource: TileResource = null
var _wing: ReckoningAllyWing = ReckoningAllyWing.new()
## The face the last throw showed, for the UI.
var last_face: FateDie.Face = FateDie.Face.BLANK
## The ending the last Reckoning came to, for the end screen.
static var last_ending: ReckoningEnding = null


## The director while the Reckoning is being fought, else null.
static func active() -> ReckoningDirector:
	if is_instance_valid(_instance) and _instance._running:
		return _instance
	return null


## Whether [param candidate] is the Reckoning's scenario.
static func is_reckoning(candidate: ScenarioResource) -> bool:
	return is_instance_valid(_instance) and _instance.scenario != null and candidate != null \
		and candidate.resource_path == _instance.scenario.resource_path


## Whether the player's death is the Reckoning's to end the run with (Fell
## In), so the cockpit's own destruction mustn't end it (CockpitDestruction).
static func owns_death() -> bool:
	return is_instance_valid(_instance) and _instance._death_claimed


func _ready() -> void:
	_instance = self
	add_to_group(&"reckoning_director")
	_wing.name = &"AllyWing"
	add_child(_wing)
	_wing.upcoming = _queued_allies
	_wing.take_upcoming = _take_queued_ally
	Events.load_scenario.connect(_on_load_scenario)
	Events.first_turn_start.connect(_on_round_start)
	Events.player_turn_start.connect(_on_round_start)
	Events.enemy_left.connect(_on_enemy_left)
	Events.player_destroyed.connect(_on_player_destroyed)
	Events.engine_charge_changed.connect(_on_charge_changed)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# ── Public: read by the UI and by the Reckoning's effects ───────────────────

## The charge the escape needs: the engine's limit for the fight.
func escape_goal() -> int:
	return _goal


## The face Fate will throw at the start of next round, rolled a round
## ahead from the same seeded generator, so "You"'s die can drift toward it
## (RECKONING_ENDINGS.md §4) and the throws stay the same on a replay.
## BLANK outside the fight.
func upcoming_face() -> FateDie.Face:
	if not _running or _next_slot < 0 or Globals.fate_ledger == null:
		return FateDie.Face.BLANK
	return Globals.fate_ledger.die.face_at(_next_slot)


## Saved ships still to come: waiting at the edge of the fleet, or in waves
## the hole hasn't sent yet.
func allies_waiting() -> int:
	return _wing.left_behind().size() - (0 if _wing.aboard_id().is_empty() else 1)


## Charge for the escape, straight onto the engine charger (the dev console's
## `fate escape`, ADD_ESCAPE_VELOCITY). Stops at the bank: overcharge is the
## redline's, and only ADD_OVERCHARGE goes there.
func add_escape_velocity(amount: int, from: Node2D = null) -> void:
	if not _running or _ending or amount == 0 or not is_instance_valid(Globals.player):
		return
	var player: Player = Globals.player
	player.engine_charge = clampi(player.engine_charge + amount, 0, maxi(player.engine_charge, player.max_engine_charge))
	if from and is_instance_valid(from):
		Juice.sparkle(from, from.global_position, EngineCharger.DRIVE_COLOR, 6, 30.0, true)


## Mercy: the next ship the player saved jumps in now, or the one aboard is
## healed and shielded for [param amount].
func call_ally(amount: int) -> void:
	if _running and not _ending:
		_wing.mercy(amount)


## Hunger: the hole's next wave comes now, even if the one on the board isn't
## cleared, unless the board is already full (hunger_board_cap).
func hurry_next_wave() -> void:
	if _running and not _ending and _hostiles_left().size() < hunger_board_cap:
		_advance_waves(true)


## The dev console's `fate you`: the rest of the Tally is skipped and "You"
## comes now. Saved ships in the skipped waves still come.
func skip_to_self() -> void:
	if not _running or _ending or _self_sent:
		return
	while _wave_index < _waves.size():
		_wing.add(_waves[_wave_index]["allies"])
		_wave_index += 1
	_spawn_self()
	_spawn_spilled(true)


## The dev console's `fate allies`: [param entries] join the queue now.
func add_allies(entries: Array[Dictionary]) -> void:
	if _running and not _ending:
		_wing.add(entries)


## The bank was full and the player jumped (JumpEvent, which has already
## committed the hand): the escape plays out, then the ending's film.
func jump_out() -> void:
	if not _running or _ending:
		return
	_ending = true
	_wing.stop()
	_shut_down_engine()
	await _play_escape()
	await _play_ending(ReckoningRules.Trigger.JUMPED)


# ── The fight's life ────────────────────────────────────────────────────────

func _on_load_scenario(loaded: ScenarioResource) -> void:
	if not is_reckoning(loaded):
		if _running:
			_stop()
		return
	_begin(loaded)


func _begin(loaded: ScenarioResource) -> void:
	_running = true
	_ending = false
	_death_claimed = false
	_fight_started = false
	_bank_full = false
	_wave_index = 0
	_spilled_index = 0
	_round = 0
	_self_ship = null
	_self_sent = false
	_first_kill_ship = null
	last_face = FateDie.Face.BLANK
	last_ending = null
	_rng.seed = hash([loaded.scenario_seed, "reckoning"])

	var ledger: FateLedger = Globals.fate_ledger
	ledger.in_reckoning = true
	# A player who never paid the tithe never paid into the deal: the
	# Rearguard they killed stay dead.
	var skip: Array[String] = []
	if ledger.refused_every_tithe():
		skip.append("rearguard")
	_waves = ReckoningQueue.build(ledger.kills, ledger.allies, skip)

	# The goal is set by the dice held as the player turns Back, and holds:
	# giving dice away mustn't lower it (RECKONING_ENDINGS.md §1).
	var player: Player = Globals.player
	_goal = ReckoningRules.escape_goal(player.max_engine_charge, escape_goal_multiplier)
	player.freeze_engine_max(_goal)
	player.fleet_floor = 0
	player.engine_charge = 0
	if not player.dice_lost.is_connected(_on_dice_lost):
		player.dice_lost.connect(_on_dice_lost)

	# The engine is the same one the fight runs on, made fresh for this
	# scenario just before this listener.
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		engine.add_modifier(FateSelfWard.new())

	_wing.ally_table = ally_table
	_wing.ally_state = ally_state
	_wing.nearly_full_fraction = nearly_full_fraction
	_wing.debt_strafe_multiplier = debt_strafe_multiplier
	_wing.begin(hash([loaded.scenario_seed, "debts"]))
	# Saved ships wait for the arrival to finish: the first wave's allies
	# jump in once there's a fight on screen to jump into.
	_wing.hold_until(Events.enemies_arrived)

	_dress_charger(true)
	_swap_in_vanguard_drive()
	_next_slot = Globals.fate_ledger.die.roll(_rng)
	_advance_waves(false)


func _stop() -> void:
	_running = false
	_ending = false
	_wing.stop()
	_restore_engine_tile()
	_dress_charger(false)
	if is_instance_valid(Globals.player):
		Globals.player.release_engine_max()
		Globals.player.fleet_floor = 1
		if Globals.player.dice_lost.is_connected(_on_dice_lost):
			Globals.player.dice_lost.disconnect(_on_dice_lost)


## The engine charger wears the Vanguard Drive's gold as the escape.
func _dress_charger(on: bool) -> void:
	var charger: EngineCharger = get_tree().get_first_node_in_group(&"engine_charger") as EngineCharger
	if charger:
		charger.set_escape_dress(on)


## The dying Vanguard's drive (LORE.md §4) takes the engine charger's place.
func _swap_in_vanguard_drive() -> void:
	if not vanguard_drive:
		return
	var charger: Node = get_tree().get_first_node_in_group(&"engine_charger")
	_engine_tile = charger.get_node_or_null(^"EngineChargerTile") as Tile if charger else null
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
	if not _running or _ending or Globals.state_manager.state != GameStateManager.GameState.IN_COMBAT:
		return
	_fight_started = true
	_round += 1
	var die: FateDie = Globals.fate_ledger.die
	# The throw was rolled last round; the next one is rolled now, from the
	# same generator in the same order, so the throws are the ones they
	# always were.
	var slot: int = _next_slot if _next_slot >= 0 else die.roll(_rng)
	_next_slot = die.roll(_rng)
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


## The bank moved. Filling it flares the gold charger and calls the drive
## (the map's arrow lights on its own: max_engine_charge is the goal).
func _on_charge_changed() -> void:
	if not _running or _ending or not _fight_started or not is_instance_valid(Globals.player):
		return
	var player: Player = Globals.player
	var full: bool = player.engine_charge >= _goal
	if full and not _bank_full:
		var charger: EngineCharger = get_tree().get_first_node_in_group(&"engine_charger") as EngineCharger
		if charger:
			charger.flare_full()
	_bank_full = full
	_wing.on_bank(player.engine_charge / float(maxi(1, _goal)))


# ── The queue ───────────────────────────────────────────────────────────────

## Brings the next wave on, and keeps going while a wave brings no hostile (an
## encounter where the player only saved someone), so the fight never stalls
## between waves.
func _advance_waves(fly_in: bool) -> void:
	for guard: int in 64:
		if not _running or _ending:
			return
		_spawn_next(fly_in)
		if not _hostiles_left().is_empty():
			return


func _spawn_next(fly_in: bool) -> void:
	if _wave_index < _waves.size():
		_wave_index += 1
		_spawn_tally_wave(_waves[_wave_index - 1], fly_in)
		return
	if not _self_sent:
		_spawn_self()
	_spawn_spilled(fly_in)


## Hostile ships still fighting, "You" aside (it never holds a wave back), and
## [param leaving] aside (the ship whose loss is being counted).
func _hostiles_left(leaving: Enemy = null) -> Array[Enemy]:
	var hostiles: Array[Enemy] = []
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if ship != leaving and is_instance_valid(ship) and ship.is_hostile() and not FateSelf.is_self(ship):
			hostiles.append(ship)
	return hostiles


## Saved ships in waves still to come, in the order they'll come up.
func _queued_allies() -> Array[Dictionary]:
	var queued: Array[Dictionary] = []
	for i: int in range(_wave_index, _waves.size()):
		queued.append_array(_waves[i]["allies"])
	return queued


## Takes the next saved ship out of the waves still to come (Mercy).
func _take_queued_ally() -> Dictionary:
	for i: int in range(_wave_index, _waves.size()):
		var allies: Array = _waves[i]["allies"]
		if not allies.is_empty():
			return allies.pop_front()
	return {}


func _spawn_tally_wave(wave: Dictionary, fly_in: bool) -> void:
	var ids: Array = wave["echoes"]
	var ships: Array[Enemy] = _spawn_echoes(ids, echo_hull_fraction)
	if bool(wave.get("first", false)) and not ships.is_empty():
		_first_kill_ship = ships[0]
	_announce_wave(ships, fly_in, _tally_line_key(wave))
	_wing.add(wave["allies"])
	for debt: Dictionary in wave["debts"]:
		_pay_debt(debt, ships, fly_in)


func _spawn_spilled(fly_in: bool) -> void:
	if spilled_pool.is_empty():
		return
	var ids: Array = []
	for i: int in spilled_wave_size:
		var res: EnemyResource = spilled_pool[_spilled_index % spilled_pool.size()]
		_spilled_index += 1
		ids.append(ContentRegistry.get_enemy_id(res.resource_path))
	var line: String = "FATE_SPILLED_LINE_%d" % ((_spilled_index / maxi(1, spilled_wave_size) - 1) % 3 + 1)
	_announce_wave(_spawn_echoes(ids, 1.0), fly_in, line)


func _spawn_echoes(ids: Array, hull_fraction: float) -> Array[Enemy]:
	var spawns: Array[EnemyStateRewardResource] = []
	for id: Variant in ids:
		var path: String = ContentRegistry.get_enemy_path(str(id))
		if path.is_empty():
			continue
		var spawn: EnemyStateRewardResource = EnemyStateRewardResource.new()
		spawn.enemy_resource = load(path) as EnemyResource
		spawn.starting_state = echo_state
		spawn.starting_health_fraction = hull_fraction
		spawns.append(spawn)
	if spawns.is_empty():
		return [] as Array[Enemy]
	var ships: Array[Enemy] = Globals.enemy_manager.spawn_enemies(spawns, scenario)
	for ship: Enemy in ships:
		# Not one of the scenario's own ships: nothing for a save to restore.
		ship.spawn_index = -1
		_tint_echo(ship)
	return ships


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
## first wave, after its own rise out of the hole for the rest.
func _announce_wave(ships: Array[Enemy], fly_in: bool, line_key: String) -> void:
	if ships.is_empty():
		return
	if fly_in:
		await Globals.enemy_manager.fly_in_reinforcements(ships, _ECHO_RISE)
	else:
		await Events.enemies_arrived
	if not _running or _ending:
		return
	var speaker: Enemy = ships[0]
	if is_instance_valid(speaker) and speaker.health.health > 0:
		speaker.dialogue_manager.show_dialogue(tr(line_key), echo_state.faction)


## What a wave of the Tally says as it comes back: the very first kill's own
## line, a civilian's (the player learns the perfect ending is gone), or one
## of the echoes' in turn.
func _tally_line_key(wave: Dictionary) -> String:
	if bool(wave.get("first", false)):
		return "FATE_ECHO_LINE_FIRST"
	if bool(wave.get("civilian", false)):
		return "RECKONING_ECHO_CIVILIAN"
	return "FATE_ECHO_LINE_%d" % ((_wave_index - 1) % 4 + 1)


## A spared ship's pass waits for the echoes it strafes to be on screen.
func _pay_debt(debt: Dictionary, ships: Array[Enemy], fly_in: bool) -> void:
	if not ships.is_empty():
		if fly_in:
			await get_tree().create_timer(Globals.enemy_manager.fly_in_time).timeout
		elif Globals.enemy_manager.arrival_in_progress:
			await Events.enemies_arrived
	if _running and not _ending:
		await _wing.strafe(debt, _hostiles_left)


# ── "You" ───────────────────────────────────────────────────────────────────

## The Tally is spent: the hole sends what it made of the player, in their own
## hull (RECKONING_ENDINGS.md §4). Its look and the die's shatter are the
## listeners' to Events.fate_self_arrived.
func _spawn_self() -> void:
	_self_sent = true
	if self_resource == null:
		return
	var spawn: EnemyStateRewardResource = EnemyStateRewardResource.new()
	spawn.enemy_resource = self_resource
	spawn.starting_state = echo_state
	# 1 hull is the rule, not a number to scale with the sector.
	spawn.unscaled_hull = true
	var ships: Array[Enemy] = Globals.enemy_manager.spawn_enemies([spawn] as Array[EnemyStateRewardResource], scenario)
	if ships.is_empty():
		return
	var ship: Enemy = ships[0]
	ship.spawn_index = -1
	FateSelf.mark(ship)
	var ship_id: StringName = StringName(Globals.state_manager.current_game_save.ship_id) \
		if Globals.state_manager and Globals.state_manager.current_game_save else &""
	FateLedger._dress_as_fallen(ship, ship_id)
	_self_ship = ship
	_bring_self_in(ship)


func _bring_self_in(ship: Enemy) -> void:
	await get_tree().create_timer(_SELF_ENTRY_DELAY).timeout
	if not _running or _ending or not is_instance_valid(ship):
		return
	await Globals.enemy_manager.fly_in_reinforcements([ship] as Array[Enemy], _ECHO_RISE)
	if _running and is_instance_valid(ship) and ship.health.health > 0:
		Events.fate_self_arrived.emit(ship)


# ── Ships leaving ───────────────────────────────────────────────────────────

func _on_enemy_left(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
	if not _running or _ending or not is_instance_valid(ship):
		return
	if ship == _self_ship:
		if ship.health.health <= 0:
			Events.fate_self_destroyed.emit(ship)
			_end(ReckoningRules.Trigger.SELF_DESTROYED)
		return
	if _wing.is_aboard(ship):
		_wing.on_ship_left(ship)
		return
	if ship == _first_kill_ship and ship.health.health <= 0:
		ship.dialogue_manager.show_dialogue(tr("RECKONING_FIRST_KILL_FALLS"), echo_state.faction, false)
	if not ship.is_hostile() or not _hostiles_left(ship).is_empty():
		return
	# Spawned before the combat check that follows this signal reads the
	# roster, so the fight never ends between waves.
	_advance_waves(true)


## Dice left the Fleet with a ship. The last one leaving decides the fight:
## with an ally before the bank is full, the Last Die; with an echo, Fell In.
func _on_dice_lost(_count: int, holder: Enemy) -> void:
	if not _running or _ending or not is_instance_valid(Globals.player) or Globals.player.num_of_dice > 0:
		return
	var to_ally: bool = is_instance_valid(holder) and not holder.is_hostile()
	var trigger: ReckoningRules.Trigger = ReckoningRules.Trigger.LAST_DIE_TO_ALLY if to_ally \
		else ReckoningRules.Trigger.LAST_DIE_TO_ECHO
	if not ReckoningRules.ends_fight(trigger, _bank_full):
		return
	_end(trigger, _wing.aboard_id() if to_ally else "")


## The hull went: the cockpit's destruction plays, then the fall.
func _on_player_destroyed() -> void:
	if not _running or _ending:
		return
	_ending = true
	_death_claimed = true
	_wing.stop()
	var wreck: CockpitDestruction = get_tree().get_first_node_in_group(&"cockpit_destruction") as CockpitDestruction
	if wreck and wreck.is_playing():
		await wreck.wreckage_cleared
	await _play_ending(ReckoningRules.Trigger.HULL_ZERO)


# ── Endings ─────────────────────────────────────────────────────────────────

## The fight stops where it is, holds a beat for what just happened to be
## seen, and the ending's film takes over.
func _end(trigger: ReckoningRules.Trigger, last_holder: String = "") -> void:
	if _ending:
		return
	_ending = true
	_wing.stop()
	_shut_down_engine()
	await get_tree().create_timer(ending_beat_seconds).timeout
	await _play_ending(trigger, last_holder)


func _shut_down_engine() -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		engine.shutdown()


## The escape (RECKONING_ENDINGS.md §6.1): the music swells, the dice rattle,
## the drive stretches gold and the white jump-out takes the ship.
func _play_escape() -> void:
	MusicDirector.play_track(_ESCAPE_STING_TRACK, 0.4, true)
	Events.camera_shake_large.emit(true)
	Events.glitch_burst.emit(400)
	Events.jump.emit()
	var player: Player = Globals.player if is_instance_valid(Globals.player) else null
	if player:
		player.rattle_dice_for_jump(BackgroundManager.JUMP_RAMP_UP_TIME)
	Juice.screen_flash(self, EngineCharger.DRIVE_COLOR, 0.35, 0.6)
	if Globals.background_manager:
		Globals.background_manager.set_jump_tint(Globals.white, EngineCharger.DRIVE_COLOR)
		await Globals.background_manager.play_jump_intro()
	if player:
		player.settle_dice_after_jump()
	Juice.screen_flash(self, Globals.white, 1.0, 0.8)


func _play_ending(trigger: ReckoningRules.Trigger, last_holder: String = "") -> void:
	var ending: ReckoningEnding = build_ending(trigger, last_holder)
	last_ending = ending
	var ship_id: String = String(ending.ship_id)
	if ending.kind == ReckoningEnding.Kind.FELL_IN:
		CollectionManager.record_fate_ending(ending.ending_id(), ship_id, _prized_tile_id())
	else:
		CollectionManager.record_fate_ending(ending.ending_id())
	await ReckoningEndingPlayer.play(ending)
	_stop()


## Everything the ending's films need to know (RECKONING_ENDINGS.md §5.2),
## as the fight stands now.
func build_ending(trigger: ReckoningRules.Trigger, last_holder: String = "") -> ReckoningEnding:
	var ledger: FateLedger = Globals.fate_ledger
	var ending: ReckoningEnding = ReckoningRules.resolve(trigger, false, _ids(_wing.saved_out),
		_wing.left_behind(), _ids(_wing.lost), ledger.missed if ledger else [] as Array[Dictionary])
	if Globals.state_manager and Globals.state_manager.current_game_save:
		ending.ship_id = StringName(Globals.state_manager.current_game_save.ship_id)
	if ledger:
		for entry: Dictionary in ledger.allies:
			if str(entry.get("kind", "")) == FateLedger.KIND_ALLY:
				ending.first_saved = str(entry.get("enemy", ""))
				break
	ending.last_die_holder = last_holder
	ending.dice_left = Globals.player.num_of_dice if is_instance_valid(Globals.player) else 0
	if ledger:
		ending.die_faces.assign(ledger.die.faces)
	return ending


static func _ids(entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(str(entry.get("enemy", "")))
	return ids


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
