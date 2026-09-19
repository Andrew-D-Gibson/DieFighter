class_name PushTileInDirectionEvent
extends EffectEvent

var direction: Vector2i = Vector2i.ZERO


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(effect_source):
		return
	if effect_source is not Tile:
		return

	var allowed: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
	]
	if direction not in allowed:
		push_error("PushTileInDirectionEvent: direction must be cardinal. Got: %s" % str(direction))
		return

	Globals.tile_grid.push_tile(effect_source as Tile, direction)
