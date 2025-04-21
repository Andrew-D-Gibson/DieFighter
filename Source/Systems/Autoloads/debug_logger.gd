extends Node

var _log_file: FileAccess
var _log_path: String = "res://debug_log.txt"

func _ready() -> void:
	# Clear the log file at startup
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	if _log_file == null:
		push_error("Failed to open debug log file at: " + _log_path)
		return
	
	# Connect to scenario events
	Events.scenario_event.connect(_on_scenario_event)
	Events.player_attacked_ship.connect(_on_player_attacked_ship)
	Events.enemy_acted.connect(_on_enemy_acted)
	Events.enemy_left.connect(_on_enemy_left)
	Events.combat_finished.connect(_on_combat_finished)
	
	# Connect to global events
	Events.load_scenario.connect(_on_load_scenario)
	Events.start_scenario.connect(_on_start_scenario)
	Events.start_combat.connect(_on_start_combat)
	Events.player_turn_over.connect(_on_player_turn_over)
	Events.enemy_turn_over.connect(_on_enemy_turn_over)
	Events.game_over.connect(_on_game_over)
	
	_log("Debug logger initialized")

func _log(message: String) -> void:
	if _log_file == null:
		return
		
	var time_dict = Time.get_time_dict_from_system()
	var timestamp = "%02d:%02d:%02d" % [
		time_dict.hour,
		time_dict.minute,
		time_dict.second
	]
	_log_file.store_line("[%s] %s" % [timestamp, message])
	_log_file.flush()

func _on_scenario_event(event: ScenarioManager.ScenarioEvent) -> void:
	_log("Scenario Event: %s" % ScenarioManager.ScenarioEvent.keys()[event])

func _on_player_attacked_ship(ship: Enemy, ship_faction: ScenarioManager.Faction) -> void:
	_log("Player attacked ship: %s (Faction: %s)" % [ship.name, ScenarioManager.Faction.keys()[ship_faction]])

func _on_enemy_acted(enemy_name: String, action_name: String) -> void:
	_log("Enemy %s performed action: %s" % [enemy_name, action_name])

func _on_enemy_left(ship: Enemy, faction: ScenarioManager.Faction) -> void:
	_log("Enemy left: %s" % ScenarioManager.Faction.keys()[faction])

func _on_combat_finished() -> void:
	_log("Combat finished")

func _on_load_scenario(scenario: ScenarioResource) -> void:
	_log("Loading scenario: %s" % scenario.resource_path)

func _on_start_scenario() -> void:
	_log("Starting scenario")

func _on_start_combat() -> void:
	_log("Starting combat")

func _on_player_turn_over() -> void:
	_log("Player turn over")

func _on_enemy_turn_over() -> void:
	_log("Enemy turn over")

func _on_game_over() -> void:
	_log("Game over")

func _exit_tree() -> void:
	if _log_file != null:
		_log_file.close() 
