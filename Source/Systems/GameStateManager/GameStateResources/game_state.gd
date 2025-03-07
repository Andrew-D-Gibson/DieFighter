class_name GameStateResource
extends Resource

@export_category('Player Info')
@export var player_health: int
@export var player_max_health: int
@export var player_defense: int
@export var num_of_dice: int
@export var tile_locations: Dictionary[TileResource, Vector2i]

# Temporary
@export var current_encounter: EncounterResource
