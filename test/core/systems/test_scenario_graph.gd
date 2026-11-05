extends "res://test/helpers/die_fighter_test.gd"
## ScenarioGraph: the states the Scenario Lab expects to see in a scenario.
## A missed state is a branch the Lab never asks anyone to test; a phantom one
## is a checklist that can never be finished.

const Event = ScenarioManager.ScenarioEvent
const SCENARIO_DIR: String = "res://Source/Content/ScenarioResources/Scenarios/"


func _state(attitude: Enemy.Attitude = Enemy.Attitude.NEUTRAL) -> ScenarioShipState:
	var state: ScenarioShipState = ScenarioShipState.new()
	state.attitude = attitude
	return state


func _scenario(starting_states: Array[ScenarioShipState]) -> ScenarioResource:
	var scenario: ScenarioResource = ScenarioResource.new()
	for state: ScenarioShipState in starting_states:
		var spawn: EnemyStateRewardResource = EnemyStateRewardResource.new()
		spawn.starting_state = state
		scenario.starting_enemies.append(spawn)
	return scenario


func test_walks_transitions_and_every_weighted_outcome() -> void:
	var start: ScenarioShipState = _state()
	var hostile: ScenarioShipState = _state(Enemy.Attitude.AGGRESSIVE)
	var grateful: ScenarioShipState = _state()
	var angry: ScenarioShipState = _state(Enemy.Attitude.AGGRESSIVE)
	var roll: ScenarioShipStateProbabilityTransition = ScenarioShipStateProbabilityTransition.new()
	roll.weighted_probabilities = {grateful: 1.0, angry: 3.0}
	start.transitions = {Event.PLAYER_ATTACKED_PIRATE: hostile, Event.CIVILIANS_DEFEATED: roll}

	var graph: ScenarioGraph = ScenarioGraph.build(_scenario([start]))

	assert_eq(graph.states.size(), 4)
	assert_eq(graph.states[0], start, "a ship's opening state leads its branch")
	for state: ScenarioShipState in [hostile, grateful, angry]:
		assert_has(graph.states, state)
	assert_true(graph.has_fight)


func test_a_loop_back_is_listed_once() -> void:
	var calm: ScenarioShipState = _state()
	var alert: ScenarioShipState = _state()
	calm.transitions = {Event.PLAYER_ATTACKED_PIRATE: alert}
	alert.transitions = {Event.COMBAT_ENDED: calm}

	var graph: ScenarioGraph = ScenarioGraph.build(_scenario([calm]))

	assert_eq(graph.states.size(), 2)


func test_a_shared_state_is_listed_once_and_owned_by_every_ship_that_reaches_it() -> void:
	var shared: ScenarioShipState = _state(Enemy.Attitude.AGGRESSIVE)
	var lone: ScenarioShipState = _state()
	lone.transitions = {Event.PLAYER_ATTACKED_CIVILIAN: shared}

	var graph: ScenarioGraph = ScenarioGraph.build(_scenario([shared, lone]))

	assert_eq(graph.states.size(), 2)
	assert_eq(graph.owners[shared], [0, 1])
	assert_eq(graph.owners[lone], [1])


func test_a_peaceful_scenario_has_no_fight_to_finish() -> void:
	var trader: ScenarioShipState = _state(Enemy.Attitude.FRIENDLY)

	assert_false(ScenarioGraph.build(_scenario([trader])).has_fight)


func test_every_authored_scenario_lists_each_ships_opening_state() -> void:
	for path: String in Utils.list_resource_paths(SCENARIO_DIR, true):
		var scenario: ScenarioResource = load(path) as ScenarioResource
		if scenario == null:
			continue
		var graph: ScenarioGraph = ScenarioGraph.build(scenario)
		for spawn: EnemyStateRewardResource in scenario.starting_enemies:
			# A ship opens on a state, or on a standing branch that picks one:
			# every state it could open on is listed. Never on a roll, which
			# EngineCharger would roll a second time before the ships spawn.
			assert_false(spawn.starting_state is ScenarioShipStateProbabilityTransition,
				"%s: a ship opens on a weighted roll" % path)
			var openings: Array[ScenarioShipStateBase] = [spawn.starting_state]
			if spawn.starting_state is ScenarioShipStateStandingBranch:
				openings = spawn.starting_state.next_states()
			for opening: ScenarioShipStateBase in openings:
				assert_true(opening is ScenarioShipState and graph.states.has(opening),
					"%s: %s isn't listed" % [path, ScenarioGraph.label(opening)])
		var unique_keys: Dictionary = {}
		for key: String in graph.keys():
			unique_keys[key] = true
		assert_eq(unique_keys.size(), graph.states.size(), "%s: two states share a key" % path)
