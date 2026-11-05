extends "res://test/helpers/die_fighter_test.gd"
## Every ship that can be on the player's side while a ship it fights is
## fighting the player can hand its die on to that ship (a Raid).
##
## Without one, a die fed to it never reaches the enemy: the player could
## feed it every die, charge their engines while the enemy sat the turn out,
## and only then turn on the fight. The selector makes sure such a ship rolls
## its hand-off (EnemyActionSituation.owes_hand_off), but it can only roll
## one the ship's pools hold.

const SCENARIO_DIR: String = "res://Source/Content/ScenarioResources/Scenarios/"


func test_ships_that_can_side_with_the_player_mid_fight_can_hand_off() -> void:
	var scenario_count: int = 0
	var missing: Array[String] = []
	for path: String in _tres_files(SCENARIO_DIR):
		var scenario: ScenarioResource = load(path) as ScenarioResource
		if scenario == null:
			continue
		scenario_count += 1
		var ships: Array[EnemyStateRewardResource] = []
		for entry: EnemyStateRewardResource in scenario.starting_enemies:
			if entry and entry.enemy_resource and entry.starting_state:
				ships.append(entry)
		for ship: EnemyStateRewardResource in ships:
			if _hands_off_in_every_pool(ship.enemy_resource):
				continue
			for other: EnemyStateRewardResource in ships:
				if other == ship:
					continue
				var clash: String = _clash(_reachable(ship.starting_state), _reachable(other.starting_state))
				if clash.is_empty():
					continue
				var line: String = "%s in %s (%s)" % [
					ship.enemy_resource.resource_path.get_file(), path.get_base_dir().get_file(), clash]
				if line not in missing:
					missing.append(line)
	assert_gt(scenario_count, 0, "no scenarios found under %s; did they move?" % SCENARIO_DIR)
	assert_true(missing.is_empty(),
		"these can side with the player while a ship they fight is fighting the player, and some pool has no Raid:\n  %s"
			% "\n  ".join(missing))


## A state of a ship that can reach [param states] that is on the player's
## side, and one of a ship that can reach [param other_states] that fights
## both of them, as "mine vs theirs"; empty when there's no such pair.
static func _clash(states: Array[ScenarioShipState], other_states: Array[ScenarioShipState]) -> String:
	for state: ScenarioShipState in states:
		if state.attitude == Enemy.Attitude.AGGRESSIVE:
			continue
		for other: ScenarioShipState in other_states:
			if other.attitude == Enemy.Attitude.AGGRESSIVE \
			and FactionRelations.are_hostile(state.faction, other.faction):
				return "%s vs %s" % [state.resource_path.get_file(), other.resource_path.get_file()]
	return ""


static func _hands_off_in_every_pool(resource: EnemyResource) -> bool:
	for pool: EnemyTurnActionList in resource.action_options:
		var has_one: bool = pool.actions_possible.any(func(option: EnemyActionOptionResource) -> bool:
			return option != null and not option.fills_kept_faces and option.base_action != null \
				and option.base_action.hands_off_to_hostile()
		)
		if not has_one:
			return false
	return true


## Every state [param start] can lead to, itself included, through plain and
## weighted transitions and standing branches.
static func _reachable(start: ScenarioShipStateBase) -> Array[ScenarioShipState]:
	var found: Array[ScenarioShipState] = []
	var seen: Dictionary = {}
	var frontier: Array[ScenarioShipStateBase] = [start]
	while not frontier.is_empty():
		var next: ScenarioShipStateBase = frontier.pop_back()
		if next == null or seen.has(next):
			continue
		seen[next] = true
		if next is ScenarioShipState:
			found.append(next as ScenarioShipState)
		frontier.append_array(next.next_states())
	return found


static func _tres_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_tres_files(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".tres"):
			found.append(dir_path.path_join(file))
	return found
