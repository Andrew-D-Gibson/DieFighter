extends "res://test/helpers/die_fighter_test.gd"
## Data integrity for everything authored under res://Source/Content.
##
## Effects are stored in .tres files as raw (category, subtype) ints, and a
## broken one fails silently in play: a tile that does nothing, or does
## something else. These tests load every content resource and check each
## effect it contains against the catalog, so that surfaces here instead.

const CONTENT_ROOT: String = "res://Source/Content/"
const TILE_DIR: String = "res://Source/Content/Tiles/TileResources/"
const SCENARIO_DIR: String = "res://Source/Content/ScenarioResources/Scenarios/"

## Backgrounds carry hazard chains, so they are scanned alongside content even
## when no scenario happens to reference them yet.
const BACKGROUND_ROOT: String = "res://Source/Resources/BackgroundResources/"

## Every EffectData / EffectChain reachable from content, paired with the file
## it came from. Built once in before_all(): loading all content is the slow part.
var _effects: Array[Dictionary] = []
var _chains: Array[Dictionary] = []


func before_all() -> void:
	for path: String in _tres_files(CONTENT_ROOT) + _tres_files(BACKGROUND_ROOT):
		var res: Resource = load(path)
		if res:
			_collect(res, path, {})


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


## Walks every stored property of a resource, into sub-resources, arrays and
## dictionaries, recording each EffectData and EffectChain found.
func _collect(value: Variant, origin: String, seen: Dictionary) -> void:
	if value is Array:
		for item: Variant in value:
			_collect(item, origin, seen)
	elif value is Dictionary:
		for key: Variant in value:
			_collect(key, origin, seen)
			_collect(value[key], origin, seen)
	elif value is Resource:
		var res: Resource = value
		if seen.has(res.get_instance_id()):
			return
		seen[res.get_instance_id()] = true
		if res is EffectData:
			_effects.append({"data": res, "origin": origin})
		if res is EffectChain:
			_chains.append({"chain": res, "origin": origin})
		for prop: Dictionary in res.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["name"] != "script":
				_collect(res.get(prop["name"]), origin, seen)


func _describe(entry: Dictionary) -> String:
	var data: EffectData = entry["data"]
	return "%s: %s/%d" % [
		entry["origin"], EffectEnums.Category.find_key(data.category), data.subtype]


func test_content_was_found() -> void:
	assert_gt(_effects.size(), 0, "no EffectData found under %s; did the content move?" % CONTENT_ROOT)


func test_every_authored_effect_exists_in_the_catalog() -> void:
	for entry: Dictionary in _effects:
		var data: EffectData = entry["data"]
		var row: Dictionary = EffectCatalog.get_entry(data.category, data.subtype)
		assert_false(row.is_empty(), "%s has no catalog row (stale ordinal?)" % _describe(entry))
		assert_false(row.get("reserved", false), "%s uses a reserved, unimplemented effect" % _describe(entry))


## Statuses are named by a string, which the editor can't check. A typo would
## author an effect that silently does nothing.
func test_every_authored_status_exists() -> void:
	var status_effects: Array = [
		[EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.APPLY_STATUS],
		[EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.CLEAR_STATUS],
		[EffectEnums.Category.AMOUNT_MODIFIER, EffectEnums.AmountModifierSubtype.SET_TO_TARGET_STATUS],
		[EffectEnums.Category.CONDITIONAL, EffectEnums.ConditionalSubtype.IF_TARGET_HAS_STATUS],
	]
	var checked: int = 0
	for entry: Dictionary in _effects:
		var data: EffectData = entry["data"]
		if [data.category, data.subtype] in status_effects:
			checked += 1
			assert_true(StatusCatalog.has(StringName(data.string_param)),
				"%s names unknown status '%s'" % [_describe(entry), data.string_param])
	if checked == 0:
		pass_test("no authored content uses statuses yet")


func test_conditional_effects_are_conditional_data() -> void:
	for entry: Dictionary in _effects:
		var data: EffectData = entry["data"]
		if data.category == EffectEnums.Category.CONDITIONAL:
			assert_true(data is ConditionalEffectData,
				"%s is CONDITIONAL but not a ConditionalEffectData" % _describe(entry))


func test_repetitions_only_appear_in_repetition_conditions() -> void:
	for entry: Dictionary in _chains:
		var chain: EffectChain = entry["chain"]
		for data: EffectData in chain.effects:
			if data:
				assert_ne(data.category, EffectEnums.Category.REPETITION,
					"%s puts a REPETITION inside 'effects'" % entry["origin"])


func test_chains_have_no_empty_slots() -> void:
	for entry: Dictionary in _chains:
		var chain: EffectChain = entry["chain"]
		assert_false(chain.effects.has(null), "%s has an empty effect slot" % entry["origin"])
		assert_gt(chain.base_repetitions, 0, "%s never plays" % entry["origin"])


func test_every_tile_is_registered_for_saving() -> void:
	for path: String in _tres_files(TILE_DIR):
		if load(path) is TileResource:
			assert_ne(ContentRegistry.get_tile_id(path), "", "%s can't be saved" % path)


## The environment monitor has one screen: a rule or a countdown, not both.
func test_no_background_carries_both_a_rule_and_a_hazard() -> void:
	for path: String in _tres_files(BACKGROUND_ROOT):
		var background: BackgroundResource = load(path) as BackgroundResource
		if background:
			assert_false(background.global_modifier != null and background.hazard != null,
				"%s has both a global_modifier and a hazard" % path)


func test_every_hazard_has_a_chain() -> void:
	for path: String in _tres_files(BACKGROUND_ROOT):
		var hazard: BackgroundHazardResource = load(path) as BackgroundHazardResource
		if hazard:
			assert_not_null(hazard.effect_chain, "%s does nothing when it fires" % path)


func test_every_scenario_is_registered_for_saving() -> void:
	for path: String in _tres_files(SCENARIO_DIR):
		if load(path) is ScenarioResource:
			assert_ne(ContentRegistry.get_scenario_id(path), "", "%s can't be saved" % path)


## A faction's bounty floats from the last of its ships to go, at the same spot
## as that ship's own reward. If both offer something to pick, two offers open
## on top of each other. The convention: a faction bounty that offers picks
## pairs with ship rewards that pay money only (num_of_rewards = 0), and a ship
## reward that offers picks pairs with a money-only bounty.
func test_no_ship_and_faction_reward_both_offer_picks() -> void:
	for path: String in _tres_files(SCENARIO_DIR):
		var scenario: ScenarioResource = load(path) as ScenarioResource
		if not scenario:
			continue
		for spawn: EnemyStateRewardResource in scenario.starting_enemies:
			if not _offers_picks(spawn.reward_resource):
				continue
			for faction: int in _reachable_factions(spawn.starting_state):
				assert_false(_offers_picks(scenario.rewards.get(faction)),
					"%s: %s's reward and faction %s's bounty both offer picks" % [
						path, spawn.enemy_resource.resource_path.get_file(),
						ScenarioManager.Faction.keys()[faction]])


static func _offers_picks(reward: RewardResource) -> bool:
	return reward != null and (reward.num_of_rewards > 0 or reward.max_money_pickup > 0)


## Every faction a ship can be in, following its state transitions.
static func _reachable_factions(start: ScenarioShipStateBase) -> Array[int]:
	var factions: Array[int] = []
	var seen: Dictionary = {}
	var pending: Array[ScenarioShipStateBase] = [start]
	while not pending.is_empty():
		var state: ScenarioShipStateBase = pending.pop_back()
		if state == null or seen.has(state):
			continue
		seen[state] = true
		if state is ScenarioShipState:
			var ship_state: ScenarioShipState = state as ScenarioShipState
			if ship_state.faction not in factions:
				factions.append(ship_state.faction)
			pending.append_array(ship_state.transitions.values())
		elif state is ScenarioShipStateProbabilityTransition:
			pending.append_array((state as ScenarioShipStateProbabilityTransition).weighted_probabilities.keys())
	return factions
