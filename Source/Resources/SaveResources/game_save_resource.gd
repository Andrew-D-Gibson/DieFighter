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

@export_category('Run State')
## Per-tile persistent counters (Tile.effect_data), keyed by grid position.
## They outlive a scenario, so a tile rebuilt from its resource on load would
## otherwise forget them.
@export var tile_effect_data: Dictionary = {}

## Map.get_fate_state(): how far Fate has advanced and which tiles it threatens
## next. Empty in a save that predates it, which falls back to a fresh sector.
@export var map_state: Dictionary = {}

## RunStats.get_state(), so the end-of-run summary covers the whole run rather
## than just the part since the last Continue.
@export var run_stats: Dictionary = {}

## RandomNumberGenerator.state per RNGManager bucket name, stored as strings
## because JSON numbers lose int64 precision. RUN always; the per-scenario
## buckets only for a mid-scenario checkpoint.
@export var rng_states: Dictionary = {}

## The scenario the player is standing in, as it was at the checkpoint.
##
## Empty for an arrival checkpoint: the scenario is rebuilt from its seed, so a
## Continue replays it from the top. Filled for a checkpoint taken partway
## through (a won fight, a shop purchase, salvage taken), where rebuilding from
## the seed would hand back things already spent. See
## GameStateManager._capture_scenario_progress() for the fields.
@export var scenario_progress: Dictionary = {}
