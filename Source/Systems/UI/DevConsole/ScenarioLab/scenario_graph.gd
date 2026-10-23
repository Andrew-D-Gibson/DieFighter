class_name ScenarioGraph
extends RefCounted
## Every ship state a scenario can reach, walked from its starting ships
## through each transition and each outcome of a weighted one. The Scenario
## Lab checks coverage against this: a scenario is fully inspected once every
## state here has been seen, and its fight seen to an end if it has one.

## Reachable states in the order the walk finds them, starting ships first,
## so the opening state of each ship leads its own branch.
var states: Array[ScenarioShipState] = []
## Whether any ship can turn hostile, so there's a fight here to finish.
var has_fight: bool = false
## For each state, the spawn indices (into starting_enemies) of every ship
## whose branch reaches it.
var owners: Dictionary[ScenarioShipState, Array] = {}


static func build(scenario: ScenarioResource) -> ScenarioGraph:
	var graph := ScenarioGraph.new()
	if scenario == null:
		return graph

	for spawn_index: int in scenario.starting_enemies.size():
		var seen: Dictionary = {}
		# Depth first from each ship, so a branch reads top to bottom in the
		# checklist instead of interleaving with the next ship's.
		var stack: Array[ScenarioShipStateBase] = [scenario.starting_enemies[spawn_index].starting_state]
		while not stack.is_empty():
			var state: ScenarioShipStateBase = stack.pop_back()
			if state == null or seen.has(state):
				continue
			seen[state] = true
			var next_states: Array = []
			if state is ScenarioShipStateProbabilityTransition:
				next_states = (state as ScenarioShipStateProbabilityTransition).weighted_probabilities.keys()
			elif state is ScenarioShipState:
				var ship_state := state as ScenarioShipState
				if not graph.owners.has(ship_state):
					graph.states.append(ship_state)
					graph.owners[ship_state] = []
				graph.owners[ship_state].append(spawn_index)
				if ship_state.attitude == Enemy.Attitude.AGGRESSIVE:
					graph.has_fight = true
				next_states = ship_state.transitions.values()
			# Reversed so the first authored transition is walked first.
			next_states.reverse()
			for next: ScenarioShipStateBase in next_states:
				stack.append(next)
	return graph


func keys() -> Array[String]:
	var result: Array[String] = []
	for state: ScenarioShipState in states:
		result.append(Enemy.state_key(state))
	return result


## A short name for a state: its file for one saved as its own .tres, its id
## inside the scenario file for one embedded there.
static func label(state: ScenarioShipStateBase) -> String:
	if state == null:
		return "(none)"
	if not state.resource_name.is_empty():
		return state.resource_name
	if not state.resource_path.is_empty() and not state.resource_path.contains("::"):
		return state.resource_path.get_file().get_basename()
	return state.resource_scene_unique_id.trim_prefix("Resource_")


static func event_name(event: ScenarioManager.ScenarioEvent) -> String:
	return ScenarioManager.ScenarioEvent.find_key(event)
