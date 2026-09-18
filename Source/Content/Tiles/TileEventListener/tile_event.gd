class_name TileEvent
extends Resource

## Values are stored as raw ints in .tres files — append new ones, never insert.
enum EventType {
	ON_TURN_START,
	ON_TILE_PUSHED,
	ON_TILE_MANUALLY_MOVED,
	## Every enemy has finished acting. The hook for tiles that brace rather
	## than attack — they pay out after you've seen what the turn did to you.
	ON_ENEMY_TURN_OVER,
	## The player's hull (not shields) just took damage. The hook for
	## retaliation: getting hit stops being purely something that happens to you.
	ON_PLAYER_HEALTH_HIT,
	ON_PLAYER_FATAL_DAMAGE = 100,
}

@export var event: EventType
@export var listen_only_for_self: bool = true
