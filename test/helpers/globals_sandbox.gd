extends RefCounted
## Snapshots the Globals singleton references and puts them back afterwards.
##
## Several systems register themselves on Globals in _ready(), and several
## effects read Globals.player and friends. A test that sets one and forgets
## to clear it leaks a freed node into every test after it.

const _FIELDS: Array[String] = [
	"player", "tile_grid", "map", "targeting_computer", "reward_manager",
	"money_indicator", "enemy_manager", "scenario_manager", "state_manager",
	"background_manager", "jump_manager", "hazard_manager",
	"background_modifier_manager", "run_stats", "shop", "tutorial_manager",
	"tutorial_active", "tutorial_controls_enemy_turns", "pending_load_save",
]

var _saved: Dictionary = {}


func _init() -> void:
	for field: String in _FIELDS:
		_saved[field] = Globals.get(field)


func restore() -> void:
	for field: String in _FIELDS:
		Globals.set(field, _saved[field])
