class_name CountDownEvent
extends EffectEvent
## Counts down every countdown tile among [member targets] by [member amount]
## (TileCountdown). Each time one runs out its ON_COUNTDOWN_ZERO response goes
## off, straight after this event and before the rest of the chain that
## counted it (the die's hand-off), so a payout reads as the die's doing.


## amount is how far to count, not an output. An Amplifier on a countdown
## tile grows its payout instead, which comes from the same tile.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		var tile: Tile = target as Tile
		if not is_instance_valid(tile) or not tile.is_countdown():
			continue
		for fire: int in tile.count_down(amount):
			tile.handle_tile_event(tile, TileEvent.EventType.ON_COUNTDOWN_ZERO, true)
