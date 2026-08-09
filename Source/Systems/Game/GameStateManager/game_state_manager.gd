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
@export var boss_combat_scenarios: Array[ScenarioResource]
@export var fate_scenarios: Array[ScenarioResource]

@export var starting_scenario: ScenarioResource

var main_menu_file: String = "uid://ccvtlre5vhj7d"

enum GameState {
	IN_COMBAT,
	OUT_OF_COMBAT,
	GAME_OVER
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

	if len(current_game_save.sector_scenarios) == 0:
		if Globals.tutorial_manager.auto_start:
			current_game_save = Globals.tutorial_manager.tutorial_game_save
		else:
			RNGManager.start_new_run()
			_randomize_sector_scenarios()

	Events.start_scenario.connect(_check_combat_state)
	Events.start_scenario.connect(_checkpoint_game_save)
	Events.combat_finished.connect(_checkpoint_after_combat)
	Events.reward_picked.connect(_checkpoint_game_save)
	Events.enemy_turn_over.connect(_check_combat_state)
	Events.enemy_left.connect(func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		_check_combat_state()
	)
	Events.game_over.connect(func() -> void:
		state = GameState.GAME_OVER
	)

	Events.load_game_save.emit(current_game_save)
	Events.load_scenario.emit(
		current_game_save.sector_scenarios[
			current_game_save.current_scenario_index
		] 
	)

	
func trigger_startup_sequence() -> void:
	if Globals.tutorial_manager.auto_start:
		return
		
	Events.health_bar_startup.emit()
	Events.systems_startup.emit()
	Events.map_startup.emit()
	Events.targeting_computer_startup.emit()
	
	Events.start_scenario.emit()
	
	
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

	# Add the boss scenario
	current_game_save.sector_scenarios.append(
		RNGManager.pick_random(RNGManager.Bucket.RUN, boss_combat_scenarios)
	)

	# Add a leading "corrupted" scenario
	current_game_save.sector_scenarios.insert(
		0, RNGManager.pick_random(RNGManager.Bucket.RUN, fate_scenarios)
	)

	# Place the player's starting scenario somewhere in the beginning third
	var sector_length: int = len(current_game_save.sector_scenarios)
	var starting_scenario_index: int = RNGManager.randi_range(
		RNGManager.Bucket.RUN, 2, ceil(0.33 * sector_length)
	)

	current_game_save.current_scenario_index = starting_scenario_index
	current_game_save.sector_scenarios.insert(
		current_game_save.current_scenario_index,
		starting_scenario
	)

	# Seed all the scenarios
	for scenario: ScenarioResource in current_game_save.sector_scenarios:
		scenario.scenario_seed = RNGManager.randi(RNGManager.Bucket.RUN)
	
	
	
## Snapshots live run state into current_game_save and writes it to disk.
## Runs on scenario start (new run / after a jump), right after combat ends
## (via _checkpoint_after_combat), and whenever a dice/tile reward is claimed
## (Events.reward_picked, also emitted by shop purchases) so those aren't
## lost if the player quits before their next jump.
func _checkpoint_game_save() -> void:
	if Globals.tutorial_manager.auto_start:
		return

	# Let other start_scenario listeners (e.g. Player resetting shields to 0)
	# finish first, so we snapshot settled state rather than racing them.
	await get_tree().process_frame

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

	var tile_locations: Dictionary[Vector2i, TileResource] = {}
	for pos: Vector2i in Globals.tile_grid.tile_locations:
		tile_locations[pos] = Globals.tile_grid.tile_locations[pos].tile_resource
	current_game_save.tile_locations = tile_locations

	SaveManager.write_save(current_game_save)


## Checkpoints right after a won fight, so "I won this scenario" is a valid
## stopping point rather than only "I just started the next one". Clears the
## just-fought tile first (same as jump() does when leaving it) so a reload
## doesn't re-spawn the enemies. Skipped for sector-gate scenarios (boss
## fights, jump gates), which are never safe to clear early — those keep
## checkpointing only at the next start_scenario/jump.
func _checkpoint_after_combat() -> void:
	if Globals.tutorial_manager.auto_start:
		return

	if Globals.map.scenario_list[Globals.map.current_scenario_index].sector_gate_scenario:
		return

	Globals.map.clear_current_scenario_slot()
	_checkpoint_game_save()


func _check_combat_state() -> void:
	if _in_combat():
		state = GameState.IN_COMBAT
	else:
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
