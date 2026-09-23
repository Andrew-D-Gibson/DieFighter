class_name GameStateManager
extends Node2D

@export var current_game_save: GameSaveResource

## Minimum of 3 (?)
@export var sector_size: int = 18

@export_category('Scenario Resources')
@export var empty_scenario: ScenarioResource
@export var shop_scenario: ScenarioResource
@export var combat_scenarios: Array[ScenarioResource]
@export var question_scenarios: Array[ScenarioResource]
## One boss encounter per sector, in order. The last entry is reused if a run
## outlasts the list, so this can be shorter than demo_sector_count.
@export var boss_combat_scenarios: Array[ScenarioResource]
@export var fate_scenarios: Array[ScenarioResource]

## Where the player arrives in the very first sector. Authored rather than
## random, so a new run always opens on the same deliberate first impression.
@export var starting_scenario: ScenarioResource

## Guards the exit of every sector. Cleared -> the sector is over.
@export var jump_gate_scenario: ScenarioResource

@export_category('Run Difficulty')
## How many sectors a full run lasts. Clearing the last sector's jump gate wins.
@export var demo_sector_count: int = 3

## Added to the enemy health/shield multiplier for each sector past the first.
@export var difficulty_scale_per_sector: float = 0.35

## Hull repaired on clearing a sector's jump gate.
##
## Nothing else in the game reliably heals — only two of 26 tiles do, and the
## player may never be offered either. That was survivable when a run was one
## sector; across three it makes attrition, not skill, the thing that ends most
## runs. Clearing a gate is the hardest milestone in a sector, so it's the right
## place to pay hull back.
@export var sector_clear_repair: int = 12

## Added to the enemy damage multiplier for each sector past the first. Kept
## lower than the health scale on purpose: tankier enemies just lengthen a
## fight, but harder-hitting ones can invalidate a defensive build outright, and
## the player's own damage grows faster than their max health does.
@export var damage_scale_per_sector: float = 0.2

@export_category('Cold Open')
## How long the arrival klaxon and red vignette run. Long enough to register as
## an emergency, short enough to be over before the player's first die lands.
@export var cold_open_alert_time: float = 2.2

## Beat between the final kill and the victory screen taking over.
const _VICTORY_DELAY_SECONDS: float = 1.5

const _ALARM_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/alarm_klaxon.tres")

var main_menu_file: String = "uid://ccvtlre5vhj7d"

## True when this is a brand new run rather than a loaded save. Only a new run
## gets the alarm: a continued save is resuming a fight it already knows about.
var _is_fresh_run: bool = true

## True while an EndCombatEvent is queued but has not resolved yet. Several
## enemies can die inside one chain and each death re-checks combat state;
## without this the queue collects a redundant event per corpse.
var _end_combat_queued: bool = false

## The saved scenario_progress being rebuilt, while a Continue is still
## standing the checkpointed scenario back up. Empty otherwise — including for
## an arrival checkpoint, which rebuilds from the seed like any arrival. Kept
## until the player leaves the scenario, since some of it (the shop's stock) is
## only asked for once the scenario is already running.
var _restore: Dictionary = {}

## True once the current scenario's fight has been won. Its enemies, hazard and
## salvage must not come back on a reload, even for a boss tile, whose map
## slot is never overwritten with an empty one.
var _scenario_cleared: bool = false

## Set while a won jump gate hands over to the next sector, so the after-combat
## checkpoint doesn't snapshot a map that already shows the new sector.
var _sector_advancing: bool = false

## Set between leaving a scenario and arriving at the next. Nothing is stable
## enough to checkpoint mid-jump.
var _in_transit: bool = false


## True for a brand new run, false when continuing a save.
func is_fresh_run() -> bool:
	return _is_fresh_run


## See _restore.
func get_restore() -> Dictionary:
	return _restore


func is_scenario_cleared() -> bool:
	return _scenario_cleared


enum GameState {
	IN_COMBAT,
	OUT_OF_COMBAT,
	GAME_OVER,
	VICTORY
}

var state: GameState = GameState.OUT_OF_COMBAT:
	set(new_state):
		if state == GameState.OUT_OF_COMBAT\
		and new_state == GameState.IN_COMBAT:
			state = new_state
			Events.start_combat.emit()
			
		elif state == GameState.IN_COMBAT\
		and new_state == GameState.OUT_OF_COMBAT:
			state = new_state
			Events.combat_finished.emit()
			
		else:
			state = new_state


# This node has to be the last thing loaded in our game
func _ready() -> void:
	assert(current_game_save)
	
	Globals.state_manager = self

	if Globals.pending_load_save:
		current_game_save = Globals.pending_load_save
		Globals.pending_load_save = null
		_is_fresh_run = false
		_restore = current_game_save.scenario_progress
		_scenario_cleared = bool(_restore.get("cleared", false))
	else:
		# The exported run_start.tres is a cached resource, and checkpoints
		# write into current_game_save. Without a copy, a second New Game in
		# the same session would open on the last run's final checkpoint.
		current_game_save = current_game_save.duplicate()

	if len(current_game_save.sector_scenarios) == 0:
		RNGManager.start_new_run()
		_randomize_sector_scenarios()

	Events.start_scenario.connect(_check_combat_state)
	Events.start_scenario.connect(_checkpoint_on_arrival)
	Events.combat_finished.connect(_check_sector_cleared)
	Events.combat_finished.connect(_checkpoint_after_combat)
	Events.reward_picked.connect(_checkpoint_mid_scenario)
	Events.jump.connect(func() -> void:
		_restore = {}
		_scenario_cleared = false
		_in_transit = true
	)
	Events.enemy_turn_over.connect(_check_combat_state)
	Events.enemy_left.connect(func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		_check_combat_state()
	)
	Events.game_over.connect(func() -> void:
		state = GameState.GAME_OVER
	)
	Events.victory.connect(func() -> void:
		state = GameState.VICTORY
	)

	Events.load_game_save.emit(current_game_save)
	Events.load_scenario.emit(_scenario_to_load())


## The scenario a (re)started game scene opens in: the map slot, unless the
## save was taken partway through a scenario. A won fight overwrites its slot
## with an empty or Fate tile, but the player is still standing in the
## original — its background and rules — just with the enemies gone.
func _scenario_to_load() -> ScenarioResource:
	var slot: ScenarioResource = current_game_save.sector_scenarios[
		current_game_save.current_scenario_index
	]
	if not _restore.has("scenario"):
		return slot

	var path: String = ContentRegistry.get_scenario_path(_restore["scenario"])
	if path == "":
		return slot
	var scenario: ScenarioResource = ResourceLoader.load(path)
	scenario.scenario_seed = int(_restore.get("seed", scenario.scenario_seed))
	return scenario

	
## Called one frame into the game_start animation, once every system's _ready()
## has run. There is no fade and no boot sequence: a run opens in the middle of
## an ambush, so the cockpit snaps on already lit and already screaming.
func trigger_startup_sequence() -> void:
	Events.cockpit_snap_online.emit()
	_sound_the_alarm()
	Events.start_scenario.emit()


## The cold open's whole job: tell the player they are in trouble before any
## text does. Skipped when continuing a save — re-alarming every load would
## teach the player that the alarm means nothing.
func _sound_the_alarm() -> void:
	if not _is_fresh_run:
		return

	Events.play_sound.emit(_ALARM_SFX)
	Events.red_alert.emit(cold_open_alert_time)
	Events.camera_shake_large.emit(true)
	
	
func _randomize_sector_scenarios() -> void:
	current_game_save.sector_scenarios = []
	
	# Add the shop(s)
	for i: int in range(RNGManager.randi_range(RNGManager.Bucket.RUN, 2, 3)):
		current_game_save.sector_scenarios.append(shop_scenario)
		
	# Add the blend of combat and question scenarios
	for i: int in range(sector_size - len(current_game_save.sector_scenarios)):
		var question_scenario_options: Array[ScenarioResource] = Utils.array_while_excluding(
			question_scenarios, 
			current_game_save.sector_scenarios
		)
			
		var combat_scenario_options: Array[ScenarioResource] = Utils.array_while_excluding(
			combat_scenarios,
			current_game_save.sector_scenarios
		)
		
		# 30% chance of a new question scenario
		if len(question_scenario_options) > 0 and RNGManager.randf(RNGManager.Bucket.RUN) <= 0.3:
			current_game_save.sector_scenarios.append(
				RNGManager.pick_random(RNGManager.Bucket.RUN, question_scenario_options)
			)

		# Otherwise pick a combat scenario
		elif len(combat_scenario_options) > 0:
			current_game_save.sector_scenarios.append(
				RNGManager.pick_random(RNGManager.Bucket.RUN, combat_scenario_options)
			)

		# If we ever make it here (we really shouldn't but still),
		# just add a random question or combat scenario
		else:
			var all_scenarios: Array[ScenarioResource] = []
			all_scenarios.append_array(combat_scenarios)
			all_scenarios.append_array(question_scenarios)
			if all_scenarios.size() > 0:
				current_game_save.sector_scenarios.append(
					RNGManager.pick_random(RNGManager.Bucket.RUN, all_scenarios)
				)
			else:
				current_game_save.sector_scenarios.append(empty_scenario)

	RNGManager.shuffle_array(RNGManager.Bucket.RUN, current_game_save.sector_scenarios)

	# Add this sector's boss. Indexed rather than random: the boss is the one
	# encounter the player is guaranteed to meet once per sector, so it's the
	# clearest place to show a run getting harder.
	if not boss_combat_scenarios.is_empty():
		var boss_index: int = clampi(
			current_game_save.sector_index, 0, len(boss_combat_scenarios) - 1
		)
		current_game_save.sector_scenarios.append(boss_combat_scenarios[boss_index])

	# The gate, not the boss, is the last tile — clearing it ends the sector.
	if jump_gate_scenario:
		current_game_save.sector_scenarios.append(jump_gate_scenario)

	# Add a leading "corrupted" scenario
	current_game_save.sector_scenarios.insert(
		0, RNGManager.pick_random(RNGManager.Bucket.RUN, fate_scenarios)
	)

	# Place the player's arrival scenario somewhere in the beginning third
	var sector_length: int = len(current_game_save.sector_scenarios)
	var starting_scenario_index: int = RNGManager.randi_range(
		RNGManager.Bucket.RUN, 2, ceil(0.33 * sector_length)
	)

	current_game_save.current_scenario_index = starting_scenario_index
	current_game_save.sector_scenarios.insert(
		current_game_save.current_scenario_index,
		_pick_arrival_scenario()
	)

	# Seed all the scenarios
	for scenario: ScenarioResource in current_game_save.sector_scenarios:
		scenario.scenario_seed = RNGManager.randi(RNGManager.Bucket.RUN)
	
	
	
## Patches the hull for surviving a sector. Health.change_health() clamps to
## max_health, so this is safe to call at any damage level.
func _repair_after_sector() -> void:
	if sector_clear_repair <= 0 or not is_instance_valid(Globals.player):
		return

	Globals.player.health.change_health(sector_clear_repair)


## Where the player drops out of hyperspace when a sector begins.
##
## Sector 1 always uses the authored starting_scenario so a new run opens the
## same way every time. Later sectors arrive somewhere else entirely — landing
## on the identical encounter three times in one run makes the jump gate feel
## like a reset rather than progress.
func _pick_arrival_scenario() -> ScenarioResource:
	if current_game_save.sector_index == 0 or question_scenarios.is_empty():
		return starting_scenario

	var unused: Array[ScenarioResource] = Utils.array_while_excluding(
		question_scenarios,
		current_game_save.sector_scenarios
	)
	if unused.is_empty():
		unused = question_scenarios

	return RNGManager.pick_random(RNGManager.Bucket.RUN, unused)


## Enemy health and shields are multiplied by this at spawn time
## (see Enemy._update_health_from_resource).
func get_difficulty_multiplier() -> float:
	return 1.0 + current_game_save.sector_index * difficulty_scale_per_sector


## Enemy action amounts are multiplied by this when a turn's actions are rolled
## (see EnemyActionOptionResource.get_action). Without it, later sectors are
## only longer, not harder — the player out-scales flat hand-authored damage.
func get_damage_multiplier() -> float:
	return 1.0 + current_game_save.sector_index * damage_scale_per_sector


## Fires after every won fight. The sector's last tile is always its jump gate,
## so winning there means the sector itself is done.
func _check_sector_cleared() -> void:
	var index: int = Globals.map.current_scenario_index
	if index != len(Globals.map.scenario_list) - 1:
		return
	if not Globals.map.scenario_list[index].sector_gate_scenario:
		return

	_advance_to_next_sector()


## Generates the next, harder sector and jumps the player into it — or ends the
## run in victory if that was the last sector.
func _advance_to_next_sector() -> void:
	_sector_advancing = true
	current_game_save.sector_index += 1

	if current_game_save.sector_index >= demo_sector_count:
		# Let the last kill land before the run's end takes over the screen.
		await get_tree().create_timer(_VICTORY_DELAY_SECONDS).timeout
		Events.victory.emit()
		return

	_repair_after_sector()

	_randomize_sector_scenarios()
	Globals.map.load_sector(
		current_game_save.sector_scenarios,
		current_game_save.current_scenario_index
	)
	Events.sector_advanced.emit(current_game_save.sector_index)

	# Reuse the normal between-tiles jump so a sector change reads as one too.
	await Globals.jump_manager.jump_to_scenario(
		current_game_save.sector_scenarios[current_game_save.current_scenario_index]
	)


## Checkpoint on arriving in a scenario. The scenario itself is saved only as
## its seed: a Continue rebuilds it from scratch, which is exactly the state
## the player arrived to. A Continue that is still standing a mid-scenario save
## back up skips this — the save on disk already describes where they are.
##
## Taken synchronously, before any ship's arrival effects: this listener is
## connected before the ships spawn, so it runs first. A medic that heals on
## arrival must not be in the snapshot, or replaying the arrival heals twice.
func _checkpoint_on_arrival() -> void:
	_in_transit = false
	_sector_advancing = false
	if not _restore.is_empty():
		return
	_checkpoint_game_save(false)


## Checkpoint partway through a scenario (a reward or shop item taken). Never
## during a fight: a fight is replayed from the last checkpoint instead, so
## this waits for the after-combat checkpoint to record a mid-fight pickup.
func _checkpoint_mid_scenario() -> void:
	if state == GameState.IN_COMBAT or _in_transit or _sector_advancing:
		return
	await _checkpoint_game_save(true)


## Checkpoints right after a won fight, so "I won this scenario" is a valid
## stopping point rather than only "I just started the next one". Marks the
## scenario cleared and empties its map slot (same as jump() does when leaving
## it), and records anything still on offer. The jump gate is skipped: winning
## it has already generated the next sector, which checkpoints on arrival.
func _checkpoint_after_combat() -> void:
	if _sector_advancing or _in_transit:
		return

	_scenario_cleared = true
	Globals.map.clear_current_scenario_slot()
	await _checkpoint_game_save(true)


## Snapshots live run state into current_game_save and writes it to disk.
## mid_scenario captures the scenario as it stands; otherwise it's saved as an
## arrival (empty scenario_progress).
func _checkpoint_game_save(mid_scenario: bool) -> void:
	# A mid-scenario checkpoint waits a frame for the pickup or purchase that
	# triggered it to settle (the offer it came from is freed at frame end).
	# An arrival snapshot must not wait — see _checkpoint_on_arrival().
	if mid_scenario:
		await get_tree().process_frame

	# A jump that started during that frame leaves nothing stable to capture.
	if _in_transit and mid_scenario:
		return

	current_game_save.player_health = Globals.player.health.health
	current_game_save.player_max_health = Globals.player.health.max_health
	current_game_save.player_defense = Globals.player.health.shields
	current_game_save.player_engine_charge = Globals.player.engine_charge
	current_game_save.num_of_dice = Globals.player.num_of_dice

	# Check for loose money and make sure it gets saved
	var loose_money: Array[Node] = get_tree().get_nodes_in_group('Money')
	var loose_money_total: int = 0
	for money_particle: Node in loose_money:
		loose_money_total += money_particle.amount

	current_game_save.money = Globals.player.money + loose_money_total

	current_game_save.current_scenario_index = Globals.map.current_scenario_index
	current_game_save.sector_scenarios = Globals.map.scenario_list
	current_game_save.map_state = Globals.map.get_fate_state()
	# Money still in flight is banked above; count it as earned here too, or it
	# never will be — the reload restores it as balance, not as income.
	var run_stats: Dictionary = Globals.run_stats.get_state()
	run_stats["credits_earned"] += loose_money_total
	current_game_save.run_stats = run_stats
	current_game_save.rng_states = RNGManager.capture_run_state()

	var tile_locations: Dictionary[Vector2i, TileResource] = {}
	var tile_effect_data: Dictionary = {}
	for pos: Vector2i in Globals.tile_grid.tile_locations:
		var tile: Tile = Globals.tile_grid.tile_locations[pos]
		tile_locations[pos] = tile.tile_resource
		if not tile.effect_data.is_empty():
			tile_effect_data[pos] = tile.effect_data.duplicate()
	current_game_save.tile_locations = tile_locations
	current_game_save.tile_effect_data = tile_effect_data

	# Captured after the settling frame, not before: the pickup that triggered
	# this checkpoint frees its offer at the end of the frame it happened in.
	current_game_save.scenario_progress = _capture_scenario_progress() if mid_scenario else {}

	SaveManager.write_save(current_game_save)


## Everything about the current scenario a Continue needs to stand it back up
## as it is now, rather than as it was on arrival. Plain JSON-able data:
##   scenario, seed   — which scenario, even if its map slot has been emptied
##   cleared          — the fight here is won; nothing hostile comes back
##   enemies          — per starting_enemies index: alive, state, health, shields
##   offers           — reward offers still floating, item by item
##   shop             — unsold stock and prices, when the shop is open
##   hazard_turns     — the hazard's countdown
##   dice             — the player's hand: value and holographic per die
##   tile_uses        — uses_remaining per grid position ("x,y")
##   rng              — the per-scenario RNG streams, mid-flight
func _capture_scenario_progress() -> Dictionary:
	var scenario: ScenarioResource = Globals.scenario_manager.current_scenario
	var progress: Dictionary = {
		"scenario": ContentRegistry.get_scenario_id(scenario.resource_path),
		"seed": scenario.scenario_seed,
		"cleared": _scenario_cleared,
		"enemies": Globals.enemy_manager.capture_enemies(),
		"offers": Globals.reward_manager.capture_offers(),
		"hazard_turns": Globals.hazard_manager.turns_remaining,
		"dice": Globals.player.capture_hand(),
		"tile_uses": Globals.tile_grid.capture_tile_uses(),
		"rng": RNGManager.capture_scenario_states(),
	}
	if is_instance_valid(Globals.shop) and Globals.shop.visible:
		progress["shop"] = Globals.shop.capture_stock()
	return progress


func _check_combat_state() -> void:
	if _in_combat():
		# Entering combat stays immediate. Nothing downstream of start_combat
		# spends a resource, so there is no cost for an ordering bug to eat,
		# and deferring it would leave a chain briefly acting as though the
		# fight it just started hadn't.
		state = GameState.IN_COMBAT
		return

	if state != GameState.IN_COMBAT:
		# No fight in progress to end. Assign directly, which also keeps
		# GAME_OVER and VICTORY behaving exactly as they did before.
		state = GameState.OUT_OF_COMBAT
		return

	# Leaving combat is deferred through the engine so that everything hanging
	# off combat_finished lands after the chain that won the fight, rather
	# than in the middle of the damage event that landed the last blow.
	# See EndCombatEvent.
	var engine: ScenarioEngine = ScenarioEngine.current()

	if engine == null:
		# Teardown, or a load with no engine standing yet — nothing to order
		# against, so flip directly.
		state = GameState.OUT_OF_COMBAT
		return

	if _end_combat_queued:
		return

	# The drain that picks the event up is the drain that finishes it, one way
	# or another: resolved, canceled by a modifier, dropped by the runaway
	# guard, or thrown away by a jump's shutdown(). Clearing the flag when that
	# drain ends — rather than only in resolve — means none of those can leave
	# it stuck, which would stop every later fight from ever ending. Connected
	# before queueing, because an idle engine drains synchronously.
	_end_combat_queued = true
	engine.finished_processing_queue.connect(
		func() -> void: _end_combat_queued = false,
		CONNECT_ONE_SHOT
	)
	engine.queue_event(EndCombatEvent.new())


## Applies the deferred end-of-combat transition.
##
## Re-checks rather than trusting the check that queued it: an effect later in
## the same chain can spawn or revive an enemy, and a fight that is back on
## shouldn't end just because it was briefly won.
func resolve_end_of_combat() -> void:
	_end_combat_queued = false

	if _in_combat():
		return

	state = GameState.OUT_OF_COMBAT
	
	
func _in_combat() -> bool:
	for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
		if enemy.scenario_state\
		and enemy.scenario_state.attitude\
		and enemy.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE:
			return true
	return false


func load_main_menu() -> void:
	get_tree().change_scene_to_file(main_menu_file)
	
	
func fade_out_to_main_menu() -> void:
	%GameAnimationPlayer.play("fade_out_to_main_menu")
