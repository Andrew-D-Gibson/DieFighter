class_name TileEvent
extends Resource

enum EventType {
	ON_TURN_START,
	ON_TILE_PUSHED,
	ON_TILE_MANUALLY_MOVED,
}

@export var event: EventType
@export var listen_only_for_self: bool = true
