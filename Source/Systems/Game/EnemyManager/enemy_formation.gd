class_name EnemyFormation
extends RefCounted
## Works out where ships stand along the enemy spawning path.
##
## Scenarios used to author a hard-coded spot for every ship they spawned. That
## only ever produced one correct layout: the roster the scenario happened to
## start with, on a screen with nothing else on it. A ship dying left a gap, the
## shop panel opened on top of whoever was standing there, and the tutorial's
## popups covered the one enemy they were talking about.
##
## So position is derived instead. A scenario says who shows up and in what
## order; this decides where they go, from how many there are and how much of
## the screen is currently free. One ship centres itself, a wing spreads evenly,
## and the survivors close ranks when one of them dies.
##
## Space is taken away by reservations — a screen-space x span claimed by
## something else on screen (the shop panel, the tutorial's popups, a ship that
## a scenario effect deliberately parked somewhere). Each is keyed by its owner
## so it can be dropped again, and the formation re-expands when it is.
##
## Everything here is in screen-space x. Turning that back into a position along
## the curve is [EnemyManager]'s job.


## The full stretch of screen the formation may use, before reservations.
var usable_span: Vector2 = Vector2(40.0, 280.0)

## Closest two ships are allowed to stand. When the free space can't give
## everyone this much, the formation overflows its free span rather than
## stacking ships on top of each other — a ship half-behind the shop panel is
## bad, two ships in the same pixel is worse.
var min_ship_spacing: float = 40.0

var _reservations: Dictionary[StringName, Vector2] = {}


## Claims [param span] for [param key], replacing any span that key already
## held. Returns whether this actually changed the layout, so callers can skip
## a pointless reflow.
func reserve(key: StringName, span: Vector2) -> bool:
	var ordered: Vector2 = Vector2(minf(span.x, span.y), maxf(span.x, span.y))
	if _reservations.get(key, Vector2.INF) == ordered:
		return false
	_reservations[key] = ordered
	return true


## Gives [param key]'s claimed space back. Returns whether anything was held.
func clear_reservation(key: StringName) -> bool:
	return _reservations.erase(key)


func has_reservation(key: StringName) -> bool:
	return _reservations.has(key)


## Where [param count] ships should stand, left to right.
func solve(count: int) -> PackedFloat32Array:
	var positions: PackedFloat32Array = PackedFloat32Array()
	if count <= 0:
		return positions

	var span: Vector2 = get_free_span()
	var spacing: float = (span.y - span.x) / float(count + 1)

	if count > 1 and spacing < min_ship_spacing:
		return _overflow_positions(count, span)

	for i: int in range(count):
		positions.append(span.x + spacing * float(i + 1))
	return positions


## The widest unreserved stretch of [member usable_span]. Falls back to the
## whole span when reservations have swallowed all of it, so a ship always has
## somewhere to be.
func get_free_span() -> Vector2:
	var free: Array[Vector2] = [usable_span]

	for reserved: Vector2 in _reservations.values():
		var remaining: Array[Vector2] = []
		for stretch: Vector2 in free:
			remaining.append_array(_subtract(stretch, reserved))
		free = remaining

	var widest: Vector2 = usable_span
	var widest_width: float = -1.0
	for stretch: Vector2 in free:
		var width: float = stretch.y - stretch.x
		if width > widest_width:
			widest_width = width
			widest = stretch
	return widest


## [param stretch] minus [param reserved]: nothing, one side, or both sides.
func _subtract(stretch: Vector2, reserved: Vector2) -> Array[Vector2]:
	if reserved.y <= stretch.x or reserved.x >= stretch.y:
		return [stretch]

	var remainder: Array[Vector2] = []
	if reserved.x > stretch.x:
		remainder.append(Vector2(stretch.x, reserved.x))
	if reserved.y < stretch.y:
		remainder.append(Vector2(reserved.y, stretch.y))
	return remainder


## Too many ships for the free span: line them up at the minimum spacing,
## centred on the free space, and slide the whole line back inside the usable
## span if that pushed anyone off the edge of the screen.
func _overflow_positions(count: int, span: Vector2) -> PackedFloat32Array:
	var line_width: float = min_ship_spacing * float(count - 1)
	var start: float = (span.x + span.y) * 0.5 - line_width * 0.5
	start = clampf(
		start,
		usable_span.x,
		maxf(usable_span.x, usable_span.y - line_width)
	)

	var positions: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(count):
		positions.append(start + min_ship_spacing * float(i))
	return positions
