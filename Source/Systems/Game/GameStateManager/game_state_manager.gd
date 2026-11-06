class_name GameStateManager
extends Node2D

@export var current_game_save: GameSaveResource

## Deals each sector's map. Its exports are the encounter lists.
@export var sector_generator: SectorGenerator

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
@export var sector_clear_repair: int = 30

## Added to the enemy damage multiplier for each sector past the first. Kept
## lower than the health scale on purpose: tankier enemies just lengthen a
## fight, but harder-hitting ones can invalidate a defensive build outright, and
## the player's own damage grows faster than their max health does.
@export var damage_scale_per_sector: float = 0.2

## What a wreck's credits are multiplied by, by sector: the first entry for the
## first sector, and so on, with the last entry carrying on past the end.
## Later encounters field more ships, each authored with its own payout, so
## without a trim the credits outran the shop's price growth and every later
## shop could be cleared. Applies to payouts and money pickups, never to a
## refund (what the player is owed back stays exact). See Reward.
@export var money_scale_by_sector: Array[float] = [1.0, 0.78, 0.78]

## The most different kinds of action one enemy's table may mix, by sector:
## the first entry for the first sector, and so on, with the last entry
## carrying on past the end. 0 means no limit. Early ships doing one or two
## things lets the player learn each action before tables start mixing them.
## See EnemyActionVariety.
@export var action_kinds_per_sector: Array[int] = [2, 3, 0]
## How many more kinds a boss ship's table may mix wherever there's a cap, so
## a gate fight has more going on than the fights leading up to it. No cap
## stays no cap.
@export var boss_bonus_action_kinds: int = 1

@export_category('Cold Open')
## How long the arrival's red-alert vignette runs. Long enough to register as
## an emergency, short enough to be over before the player's first die lands.
@export var cold_open_alert_time: float = 2.2

## Sounds here rather than at the end of the opening cutscene, which fades
## out: the alarm belongs to the moment the player is dropped into the fight.
const _ALARM_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/alarm_klaxon.tres")

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

## The opening ambusher's first shot of a fresh run, which keeps its own
## books (see OpeningStrike). Null on a Continue, once the player jumps, or
## when there's nothing to fire.
var _opening_strike: OpeningStrike

## Set between leaving a scenario and arriving at the next, including a trip
## through the jump gate (whose map already shows the new sector). Nothing is
## stable enough to checkpoint mid-jump.
var _in_transit: bool = false

## Set when a checkpoint was taken but held off disk for the tutorial
## (Globals.tutorial_holds_saves), so the tutorial finishing writes it.
var _save_held: bool = false


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
		# The ship picked at the menu brings its own starting kit; the scene's
		# run_start.tres is the fallback.
		var ship: ShipResource = Globals.current_ship()
		if ship and ship.starting_save:
			current_game_save = ship.starting_save
		current_game_save = current_game_save.duplicate()
		if ship:
			current_game_save.ship_id = ship.id
		_opening_strike = OpeningStrike.owe(current_game_save)

	if len(current_game_save.sector_scenarios) == 0:
		RNGManager.start_new_run()
		sector_generator.generate(current_game_save)

	Events.start_scenario.connect(_check_combat_state)
	Events.start_scenario.connect(_checkpoint_on_arrival)
	Events.combat_finished.connect(_checkpoint_after_combat)
	Events.reward_picked.connect(_checkpoint_mid_scenario)
	Events.tutorial_finished.connect(_write_held_save)
	Events.jump.connect(func() -> void:
		_opening_strike = null
		_restore = {}
		_scenario_cleared = false
		_in_transit = true
	)
	Events.enemy_turn_over.connect(_check_combat_state)
	# A scenario event can turn a ship hostile without a shot being fired (a
	# toll the player couldn't pay, salvage the escort told them not to take).
	# Deferred so the ships have reacted before the roster is read.
	Events.scenario_event.connect(func(_event: ScenarioManager.ScenarioEvent) -> void:
		_check_combat_state.call_deferred()
	)
	# The Scenario Lab can put a ship in a state with no event behind it.
	Events.ship_scenario_state_changed.connect(func(_ship: Enemy) -> void:
		_check_combat_state.call_deferred()
	)
	Events.enemy_left.connect(func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		_check_combat_state()
	)
	# The fight stops where it is the moment the hull goes, not once the
	# game-over panel is up: shutting the engine down drops every queued
	# effect, and an enemy turn in progress ends without starting another
	# player turn.
	Events.player_destroyed.connect(func() -> void:
		state = GameState.GAME_OVER
		var engine: ScenarioEngine = ScenarioEngine.current()
		if engine:
			engine.shutdown()
	)
	Events.game_over.connect(func() -> void:
		state = GameState.GAME_OVER
	)
	Events.victory.connect(func() -> void:
		state = GameState.VICTORY
	)

	Events.load_game_save.emit(current_game_save)
	Events.load_scenario.emit(_scenario_to_load())
	# The scenario's ships have spawned: the ambusher takes its die now, so it
	# flies in holding it.
	if _opening_strike and not _opening_strike.arm(current_game_save):
		_opening_strike = null


## The scenario a (re)started game scene opens in: the map slot, unless the
## save was taken partway through a scenario. A won fight overwrites its slot
## with an empty or Fate tile, but the player is still standing in the
## original — its background and rules — just with the enemies gone.
func _scenario_to_load() -> ScenarioResource:
	# A run saved inside the Reckoning goes back into it, from the top.
	var reckoning: ScenarioResource = _reckoning_scenario()
	if reckoning and bool(current_game_save.fate_state.get("in_reckoning", false)):
		reckoning.scenario_seed = int(current_game_save.fate_state.get("reckoning_seed", 0))
		return reckoning

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

	
## Plays the opening shot, the one time there is one, and returns once it
## has landed. The hull is the save's after it. The tutorial can hold it
## until its first card has been read.
func play_opening_strike() -> void:
	if _opening_strike:
		if Globals.tutorial_holds_opening_strike:
			await Events.opening_strike_released
		# The fight can be over by the time a held shot is let go.
		if is_instance_valid(_opening_strike):
			await _opening_strike.play()
		Events.opening_strike_landed.emit()


## True from the start of a new run until its opening shot has landed. False
## for a run with no shot to fire.
func opening_strike_pending() -> bool:
	return _opening_strike != null and _opening_strike.hull_owed() > 0


## The die the opening shot fires, until it's back in the player's hand.
## Null when there's no shot to come.
func opening_strike_die() -> Dice:
	return _opening_strike.die() if _opening_strike else null


## True while the opening ambusher is flying in holding one of the player's
## dice, which the hand being dealt must leave room for.
func opening_strike_holds_die() -> bool:
	return _opening_strike != null and _opening_strike.holds_die()


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

	#Events.play_sound.emit(_ALARM_SFX)
	Events.red_alert.emit(cold_open_alert_time)
	Events.camera_shake_large.emit(true)
	
	
## Patches the hull for surviving a sector. Health.change_health() clamps to
## max_health, so this is safe to call at any damage level.
func _repair_after_sector() -> void:
	if sector_clear_repair <= 0 or not is_instance_valid(Globals.player):
		return

	Globals.player.health.change_health(sector_clear_repair)


## Whether map [param slot] of the current sector must be free of place
## rules and hazards: sector 1, within one jump of where the run began. A new
## player's first jump (the tutorial's included) is the first fight they
## choose, and a rule on top of it is one new thing too many. Worked out from the save, not
## from whether the tutorial is running, so a Continue lands under the same
## sky. See RandomBackgroundResource.get_random_background().
func is_rule_free_slot(slot: int) -> bool:
	if current_game_save == null or current_game_save.sector_index != 0:
		return false
	var start: int = current_game_save.arrival_index
	return start >= 0 and absi(slot - start) <= SectorGenerator.LONGEST_JUMP


## Enemy health and shields are multiplied by this at spawn time
## (see Enemy._update_health_from_resource).
func get_difficulty_multiplier() -> float:
	return 1.0 + current_game_save.sector_index * difficulty_scale_per_sector


## Reward credits are multiplied by this; see [member money_scale_by_sector].
func get_money_multiplier() -> float:
	if money_scale_by_sector.is_empty() or current_game_save == null:
		return 1.0
	var index: int = clampi(current_game_save.sector_index, 0, money_scale_by_sector.size() - 1)
	return money_scale_by_sector[index]


## Enemy action amounts are multiplied by this when a turn's actions are rolled
## (see EnemyActionOptionResource.get_action). Without it, later sectors are
## only longer, not harder — the player out-scales flat hand-authored damage.
func get_damage_multiplier() -> float:
	return 1.0 + current_game_save.sector_index * damage_scale_per_sector


## The cap on kinds of action per enemy table this sector, or 0 for none,
## raised for a boss. See [member action_kinds_per_sector] and
## [member boss_bonus_action_kinds].
func get_action_kinds_cap(is_boss: bool = false) -> int:
	if action_kinds_per_sector.is_empty() or current_game_save == null:
		return 0
	var index: int = clampi(current_game_save.sector_index, 0, action_kinds_per_sector.size() - 1)
	var cap: int = action_kinds_per_sector[index]
	if cap > 0 and is_boss:
		cap += boss_bonus_action_kinds
	return cap


## Leaves the sector through its jump gate: the next, harder sector, or the
## end of the run if that was the last. Only valid once the gate is open (its
## boss beaten), which JumpEvent checks before calling this.
func go_through_gate() -> void:
	if _in_transit:
		return
	_in_transit = true
	# Before load_sector(): the map holds on the old sector's gate for the
	# trip, rather than redrawing the next sector the moment it's generated.
	Globals.map.show_gate_jump()

	if current_game_save.sector_index + 1 >= demo_sector_count:
		# The last gate. For a player who knows the secret and carved every
		# face, Fate's Die starts rattling: forward to the front, or back
		# toward Fate (LORE.md §6, Gate 3).
		if Globals.fate_ledger and Globals.fate_ledger.fate_route_open() and _reckoning_scenario():
			var choice: FateVectorChoice = FateVectorChoice.open_in(Globals.jump_manager)
			var vector: FateVectorChoice.Vector = await choice.chosen
			if vector == FateVectorChoice.Vector.BACK:
				await enter_reckoning()
				return
		# Through the last gate and out: the run is won.
		current_game_save.sector_index += 1
		await Globals.jump_manager.leave_through_final_gate()
		Events.victory.emit()
		Globals.jump_gate.fade_flash(1.0)
		return

	current_game_save.sector_index += 1

	_repair_after_sector()

	sector_generator.generate(current_game_save)
	Globals.map.load_sector(
		current_game_save.sector_scenarios,
		current_game_save.current_scenario_index
	)
	Events.sector_advanced.emit(current_game_save.sector_index)

	await Globals.jump_manager.jump_through_gate(
		current_game_save.sector_scenarios[current_game_save.current_scenario_index],
		current_game_save.sector_index + 1,
		demo_sector_count
	)


## The Reckoning's scenario, or null when the scene has no ReckoningDirector.
func _reckoning_scenario() -> ScenarioResource:
	var director: ReckoningDirector = get_tree().get_first_node_in_group(&"reckoning_director") as ReckoningDirector
	return director.scenario if director else null


## Turns back at the last gate and dives toward Fate. The sector stays the
## last one, so the fight scales like it.
func enter_reckoning() -> void:
	var scenario: ScenarioResource = _reckoning_scenario()
	# Kept to 31 bits: the save is JSON, which rounds big integers.
	scenario.scenario_seed = hash([RNGManager.current_run_seed, "reckoning"]) & 0x7FFFFFFF
	Globals.fate_ledger.in_reckoning = true
	Globals.fate_ledger.reckoning_seed = scenario.scenario_seed
	await Globals.jump_manager.jump_into_fate(scenario)


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
	if not _restore.is_empty():
		return
	_checkpoint_game_save(false)


## Checkpoint partway through a scenario (a reward or shop item taken). Never
## during a fight: a fight is replayed from the last checkpoint instead, so
## this waits for the after-combat checkpoint to record a mid-fight pickup.
func _checkpoint_mid_scenario() -> void:
	if state == GameState.IN_COMBAT or _in_transit:
		return
	await _checkpoint_game_save(true)


## Checkpoints right after a won fight, so "I won this scenario" is a valid
## stopping point rather than only "I just started the next one". Marks the
## scenario cleared and empties its map slot (same as jump() does when leaving
## it), and records anything still on offer. A won jump gate isn't emptied: it
## opens, so the way out of the sector is still there to come back to.
func _checkpoint_after_combat() -> void:
	if _in_transit:
		return

	_scenario_cleared = true
	if Globals.map.scenario_list[Globals.map.current_scenario_index].sector_gate_scenario:
		Globals.map.open_current_gate()
	else:
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

	# Until the opening shot lands, the hull it's about to take isn't the run's.
	var owed: int = _opening_strike.hull_owed() if _opening_strike else 0
	current_game_save.player_health = Globals.player.health.health - owed
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
	if Globals.faction_standing:
		current_game_save.faction_standing = Globals.faction_standing.get_state()
	if Globals.fate_ledger:
		current_game_save.fate_state = Globals.fate_ledger.get_state()
	if Globals.escort_keeper:
		current_game_save.escort_state = Globals.escort_keeper.get_state()
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
	current_game_save.unlocked_cells = Globals.tile_grid.get_cells()

	# Captured after the settling frame, not before: the pickup that triggered
	# this checkpoint frees its offer at the end of the frame it happened in.
	current_game_save.scenario_progress = _capture_scenario_progress() if mid_scenario else {}

	if Globals.tutorial_holds_saves:
		_save_held = true
		return
	SaveManager.write_save(current_game_save)


## Writes the newest checkpoint the tutorial held back, so a player who quits
## straight after it hands over has a run to Continue.
func _write_held_save() -> void:
	if not _save_held:
		return
	_save_held = false
	SaveManager.write_save(current_game_save)


## Everything about the current scenario a Continue needs to stand it back up
## as it is now, rather than as it was on arrival. Plain JSON-able data:
##   scenario, seed   — which scenario, even if its map slot has been emptied
##   cleared          — the fight here is won; nothing hostile comes back
##   enemies          — per starting_enemies index: alive, state, health, shields
##   offers           — reward offers still floating, item by item
##   shop             — unsold stock and prices, when the shop is open
##   repair_station   — repairs bought here (they set the price), when open
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
		"dice": Globals.player.capture_hand(),
		"tile_uses": Globals.tile_grid.capture_tile_uses(),
		"rng": RNGManager.capture_scenario_states(),
	}
	if is_instance_valid(Globals.shop) and Globals.shop.is_open():
		progress["shop"] = Globals.shop.capture_stock()
	if is_instance_valid(Globals.repair_station) and Globals.repair_station.visible:
		progress["repair_station"] = Globals.repair_station.capture_state()
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
	
	
## Whether the player can read enemy intents. The targeting computer shows "?"
## otherwise, and enemies roll their tables against the same rule, so nothing
## the player can't see is able to take a ship off the board.
##
## Read off the roster rather than [member state], which is what state is
## derived from anyway: state can still say IN_COMBAT from the fight before
## while a new scenario's ships are rolled on load_scenario, and it only
## catches up on start_scenario.
func enemy_intents_visible() -> bool:
	return _in_combat()


func _in_combat() -> bool:
	for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
		if enemy.scenario_state\
		and enemy.scenario_state.attitude\
		and enemy.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE:
			return true
	return false


func load_main_menu() -> void:
	get_tree().change_scene_to_file(SceneLoader.MAIN_MENU)
	
	
func fade_out_to_main_menu() -> void:
	%GameAnimationPlayer.play("fade_out_to_main_menu")
