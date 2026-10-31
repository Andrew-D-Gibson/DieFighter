extends Node
## The Scenario Lab: a dev harness for playing any scenario from a clean start,
## and for keeping track of which of its branches have been seen.
##
## A lab run starts the way Continue does, from a save holding only the
## starter kit, so GameStateManager generates an ordinary sector around it. The
## chosen scenario then takes the starting slot just before it loads, as a
## gauntlet run's does (see AutoPilotGauntlet). A restart replays the same run
## seed, so a scenario rolls the same way each time until the seed is rerolled.
##
## A lab run saves to a file of its own, so it can never overwrite, or be
## continued as, the player's real run. The session ends when the menu opens
## or the game is entered any other way.
##
## Coverage is every ship state seen during a lab run, per scenario, kept in
## user:// across sessions. ScenarioGraph says what there is to see.

## Coverage was recorded or reset.
signal coverage_changed()

const _MAIN_GAME_SCENE: String = "uid://deisauteocrjl"
const _SAVE_PATH: String = "user://scenario_lab_save.json"
const _COVERAGE_PATH: String = "user://scenario_lab_coverage.json"

## Scenario ids are prefixed by kind; the list groups them in this order, with
## anything unprefixed (the shop, the repair station, empty space) last.
const _CATEGORY_ORDER: Array[String] = ["COMBAT", "ELITE", "EVENT", "FATE", "GATE"]
const _OTHER_CATEGORY: String = "OTHER"
## Stands for "the fight here ended" (won, or settled without a kill) among a
## scenario's seen state keys, which are all res:// paths or #ids.
const _FIGHT_ENDED_KEY: String = "!fight_ended"
## Scenarios a real run can never reach.
const _EXCLUDED_IDS: Array[String] = ["test"]

## Every scenario the Lab offers, in list order.
var scenario_ids: Array[String] = []
## The scenario the current (or next) lab run plays, into scenario_ids.
var index: int = 0
## The run seed lab runs replay. 0 until the first launch picks one.
var run_seed: int = 0
## True from a launch until the session ends.
var active: bool = false

## Set between launch() and the game scene asking for its save, so a game
## started any other way can be told apart from a lab run.
var _launch_pending: bool = false
## Scenario id -> {state key: true} for every state seen in a lab run.
var _coverage: Dictionary = {}
var _graphs: Dictionary[String, ScenarioGraph] = {}


func _ready() -> void:
	if not DevConsole.is_available():
		return
	_build_catalog()
	_load_coverage()

	Events.load_game_save.connect(_on_load_game_save)
	Events.start_scenario.connect(_record_all_ships)
	Events.ship_scenario_state_changed.connect(_record_ship)
	# Deferred: GameStateManager marks the scenario cleared on this same
	# signal, and only once that's done is an ending told apart from a jump
	# away mid-fight.
	Events.combat_finished.connect(_record_fight_ended, CONNECT_DEFERRED)


# ── Sessions ─────────────────────────────────────────────────────────────────

## Starts a fresh lab run of scenario_ids[new_index] (wrapping around the
## list), on the session's seed or a new one.
func launch(new_index: int, reroll_seed: bool = false) -> void:
	if scenario_ids.is_empty():
		push_error("ScenarioLab: no scenarios to launch.")
		return
	index = wrapi(new_index, 0, scenario_ids.size())
	if reroll_seed or run_seed == 0:
		var seeder := RandomNumberGenerator.new()
		seeder.randomize()
		run_seed = seeder.randi()
	_save_coverage()

	active = true
	_launch_pending = true
	SaveManager.save_path = _SAVE_PATH
	SaveManager.delete_save()
	RNGManager.next_run_seed = run_seed
	Globals.pending_load_save = _build_starter_save()
	get_tree().paused = false
	get_tree().change_scene_to_file(_MAIN_GAME_SCENE)


## Back to ordinary play: real saves, no lab panel unless asked for.
func end_session() -> void:
	if not active:
		return
	SaveManager.delete_save()
	SaveManager.save_path = SaveManager.SAVE_PATH
	active = false
	_launch_pending = false


func current_id() -> String:
	return scenario_ids[index] if not scenario_ids.is_empty() else ""


## The flown ship's starter kit, with no sector, so one is generated.
func _build_starter_save() -> GameSaveResource:
	var game_save: GameSaveResource = ShipCatalog.starting_save(Globals.current_ship())
	game_save.sector_scenarios = []
	game_save.sector_index = 0
	return game_save


func _on_load_game_save(game_save: GameSaveResource) -> void:
	if not _launch_pending:
		# A game entered some other way (a New Game from the menu after a lab
		# run would come through here) isn't a lab run.
		end_session()
		return
	_launch_pending = false

	# The slot keeps the seed it was generated with, so the rest of the sector
	# is the one this run seed always makes.
	var slot: int = game_save.current_scenario_index
	var scenario: ScenarioResource = scenario_resource(current_id())
	scenario.scenario_seed = game_save.sector_scenarios[slot].scenario_seed
	game_save.sector_scenarios[slot] = scenario


# ── Catalog ──────────────────────────────────────────────────────────────────

func _build_catalog() -> void:
	scenario_ids.clear()
	for id: String in ContentRegistry.get_scenario_ids():
		if id not in _EXCLUDED_IDS:
			scenario_ids.append(id)
	scenario_ids.sort_custom(func(a: String, b: String) -> bool:
		var rank_a: int = _category_rank(category(a))
		var rank_b: int = _category_rank(category(b))
		if rank_a != rank_b:
			return rank_a < rank_b
		return a < b
	)


func category(id: String) -> String:
	var prefix: String = id.get_slice("_", 0)
	return prefix if prefix in _CATEGORY_ORDER else _OTHER_CATEGORY


## "COMBAT_bounty_run" -> "Bounty Run".
func display_name(id: String) -> String:
	var name_part: String = id
	if category(id) != _OTHER_CATEGORY:
		name_part = id.trim_prefix(category(id) + "_")
	return name_part.capitalize()


func _category_rank(category_name: String) -> int:
	var rank: int = _CATEGORY_ORDER.find(category_name)
	return rank if rank >= 0 else _CATEGORY_ORDER.size()


func scenario_resource(id: String) -> ScenarioResource:
	return load(ContentRegistry.get_scenario_path(id)) as ScenarioResource


func graph(id: String) -> ScenarioGraph:
	if not _graphs.has(id):
		_graphs[id] = ScenarioGraph.build(scenario_resource(id))
	return _graphs[id]


## The id of the scenario the player is standing in, or "" between scenarios.
func live_id() -> String:
	if not is_instance_valid(Globals.scenario_manager) or Globals.scenario_manager.current_scenario == null:
		return ""
	var path: String = Globals.scenario_manager.current_scenario.resource_path
	return ContentRegistry.get_scenario_id(path) if not path.is_empty() else ""


# ── Coverage ─────────────────────────────────────────────────────────────────

func has_seen(id: String, state: ScenarioShipState) -> bool:
	return (_coverage.get(id, {}) as Dictionary).has(Enemy.state_key(state))


func has_ended_fight(id: String) -> bool:
	return (_coverage.get(id, {}) as Dictionary).has(_FIGHT_ENDED_KEY)


## (seen, total) over a scenario's states, plus seeing its fight end if it
## has one. Seen states the scenario no longer has (a renamed file) don't count.
func coverage(id: String) -> Vector2i:
	var keys: Array[String] = graph(id).keys()
	if graph(id).has_fight:
		keys.append(_FIGHT_ENDED_KEY)
	var seen: Dictionary = _coverage.get(id, {})
	var seen_count: int = 0
	for key: String in keys:
		if seen.has(key):
			seen_count += 1
	return Vector2i(seen_count, keys.size())


func reset_coverage() -> void:
	_coverage.clear()
	_save_coverage()
	coverage_changed.emit()


func _record_all_ships() -> void:
	if not active or not is_instance_valid(Globals.enemy_manager):
		return
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		_record_ship(ship)


func _record_ship(ship: Enemy) -> void:
	if ship.scenario_state:
		_record(Enemy.state_key(ship.scenario_state))


func _record_fight_ended() -> void:
	if is_instance_valid(Globals.state_manager) and Globals.state_manager.is_scenario_cleared():
		_record(_FIGHT_ENDED_KEY)


func _record(key: String) -> void:
	if not active:
		return
	var id: String = live_id()
	if id.is_empty():
		return
	var seen: Dictionary = _coverage.get_or_add(id, {})
	if seen.has(key):
		return
	seen[key] = true
	_save_coverage()
	coverage_changed.emit()


func _load_coverage() -> void:
	var text: String = FileAccess.get_file_as_string(_COVERAGE_PATH)
	if text.is_empty():
		return
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary:
		push_warning("ScenarioLab: unreadable coverage file; starting fresh.")
		return
	var last_id: String = str((data as Dictionary).get("last", ""))
	index = maxi(scenario_ids.find(last_id), 0)
	var seen_by_id: Dictionary = (data as Dictionary).get("seen", {})
	for id: String in seen_by_id:
		var seen: Dictionary = {}
		for key: Variant in seen_by_id[id]:
			seen[str(key)] = true
		_coverage[id] = seen


func _save_coverage() -> void:
	var seen_by_id: Dictionary = {}
	for id: String in _coverage:
		seen_by_id[id] = (_coverage[id] as Dictionary).keys()
	var file := FileAccess.open(_COVERAGE_PATH, FileAccess.WRITE)
	if not file:
		push_error("ScenarioLab: can't write %s" % _COVERAGE_PATH)
		return
	file.store_string(JSON.stringify({"last": current_id(), "seen": seen_by_id}, "\t"))
