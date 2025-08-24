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
	
	seed('Die Fighter'.hash())
	
	if len(current_game_save.sector_scenarios) == 0:
		_randomize_sector_scenarios()

	Events.start_scenario.connect(_check_combat_state)
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
	
	
func start_game() -> void:
	Events.start_scenario.emit()
	
	
func trigger_startup_sequence() -> void:
	#await get_tree().create_timer(2).timeout
	Events.health_bar_startup.emit()
	start_game()
	
	
func get_current_scenario() -> ScenarioResource:
	return current_game_save.sector_scenarios[current_game_save.current_scenario_index]
	
	
func _randomize_sector_scenarios() -> void:
	## THESE COMMENTS ARE OLD, BUT MAYBE I'LL GO BACK LATER
	# A sector has 19 scenarios, including:
	# 1 empty scenario at the middle where the player starts
	# 1 Boss scenario that teleports the player to the next sector
	# 1 or 2 shop scenarios
	# and a blend of combat and question scenarios
	
	current_game_save.sector_scenarios = []
	
	# Add the shop(s)
	for i in range(randi_range(2,3)):
		current_game_save.sector_scenarios.append(shop_scenario)
		
	# Add the blend of combat and question scenarios
	for i in range(sector_size - len(current_game_save.sector_scenarios)):
		var question_scenario_options = Utils.array_while_excluding(
			question_scenarios, 
			current_game_save.sector_scenarios
		)
			
		var combat_scenario_options = Utils.array_while_excluding(
			combat_scenarios,
			current_game_save.sector_scenarios
		)
		
		# 30% chance of a new question scenario
		if len(question_scenario_options) > 0 and randf() <= 0.3:
			current_game_save.sector_scenarios.append(question_scenario_options.pick_random())
			
		# Otherwise pick a combat scenario
		elif len(combat_scenario_options) > 0:
			current_game_save.sector_scenarios.append(combat_scenario_options.pick_random())
			
		# If we ever make it here (we really shouldn't but still), 
		# just add a random question or combat scenario
		else:
			var combat_and_question_scenarios: Array[ScenarioResource] = combat_scenarios + question_scenarios
			current_game_save.sector_scenarios.append(combat_and_question_scenarios.pick_random())
			

	# Now we have an array of 18 scenarios, with 1 boss and either 1 or 2 shops
	# Shuffle the array, then place 5the player's starting scenario in the middle
	current_game_save.sector_scenarios.shuffle()
	
	# Add the boss scenario
	current_game_save.sector_scenarios.append(boss_combat_scenarios.pick_random())
		
	current_game_save.current_scenario_index = 0 #floor(sector_size / 2.0)
	current_game_save.sector_scenarios.insert(current_game_save.current_scenario_index, empty_scenario)
	
	
	
func _check_combat_state() -> void:
	if _in_combat():
		state = GameState.IN_COMBAT
	else:
		state = GameState.OUT_OF_COMBAT
	
	
func _in_combat() -> bool:
	for enemy in Globals.enemy_manager.get_alive_enemies():
		if enemy.scenario_state\
		and enemy.scenario_state.attitude\
		and enemy.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE:
			return true
	return false
