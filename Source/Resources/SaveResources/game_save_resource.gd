class_name GameSaveResource
extends Resource

@export_category('Player Info')
@export var player_health: int
@export var player_max_health: int
@export var player_defense: int
@export var player_engine_charge: int

@export var num_of_dice: int
@export var money: int

@export var tile_locations: Dictionary[Vector2i, TileResource]

@export_category('Map Info')
@export var current_scenario_index: int
@export var sector_scenarios: Array[ScenarioResource]

## Which sector of the run the player is in, zero-based. Drives enemy stat
## scaling (see GameStateManager.get_difficulty_multiplier) and the run's
## win condition.
@export var sector_index: int = 0
