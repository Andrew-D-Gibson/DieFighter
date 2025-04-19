class_name GameSaveResource
extends Resource

@export_category('Player Info')
@export var player_health: int
@export var player_max_health: int
@export var player_defense: int

@export var num_of_dice: int
@export var money: int

@export var tile_locations: Dictionary[TileResource, Vector2i]

@export_category('Map Info')
@export var current_scenario_index: int
@export var sector_scenarios: Array[ScenarioResource]
