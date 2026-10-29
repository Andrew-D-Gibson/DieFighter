class_name TileCountdown
extends RefCounted
## A countdown tile's count, "(countdown) N" in its text: it starts at
## TileResource.countdown, each COUNT_DOWN (usually the die placed on it)
## takes its amount off, and every time it reaches 0 the tile fires its
## ON_COUNTDOWN_ZERO response and starts again from N. Extra counts carry over,
## so no pip is wasted, and one big count can run it out more than once.
##
## The count lasts from turn to turn and starts over with every fight. It is
## kept in Tile.effect_data under KEY as what's left, so it rides along with
## the tile's other counters (saved with the run, carried through an
## upgrade); no entry reads as a full count. Saves are only written outside a
## fight, when the count has already been put back to full.
##
## Also owns the tile's CountdownReadout, which shows what's left on the art.

const KEY: String = "countdown"

const _READOUT_NAME: StringName = &"CountdownReadout"

var _tile: Tile


func _init(tile: Tile) -> void:
	_tile = tile


## What the count starts from, or 0 for a tile that doesn't count down.
func start() -> int:
	if _tile.tile_resource == null:
		return 0
	return _tile.tile_resource.countdown


func is_countdown() -> bool:
	return start() > 0


## What's left before it fires: 1 to start(), or 0 for a tile that doesn't
## count down. Capped at start(), so an upgrade to a shorter count holds.
func remaining() -> int:
	var full: int = start()
	if full <= 0:
		return 0
	return clampi(int(_tile.effect_data.get(KEY, full)), 1, full)


## Takes [param amount] off the count and returns how many times it ran out,
## carrying the rest over into the next count. Firing the payout is the
## caller's (CountDownEvent), once per run-out.
func count_down(amount: int) -> int:
	var full: int = start()
	if full <= 0 or amount <= 0:
		return 0
	var left: int = remaining() - amount
	var fires: int = 0
	while left <= 0:
		fires += 1
		left += full
	_tile.effect_data[KEY] = left
	_show(fires > 0)
	return fires


## Back to a full count, for a new fight (and at the end of one, so a tile
## between fights shows what it will start from).
func reset() -> void:
	if _tile.effect_data.has(KEY):
		_tile.effect_data.erase(KEY)
	refresh()


## Puts the readout on the tile's art, or takes it off a tile that no longer
## counts down, and shows the count.
func refresh() -> void:
	_show(false)


## The other countdown tiles on the grid [param tile] is on, or every one on
## the grid when it isn't.
static func others_on_grid(tile: Tile) -> Array[Tile]:
	var found: Array[Tile] = []
	var grid: TileGrid = Globals.tile_grid
	if not is_instance_valid(grid):
		return found
	for other: Tile in grid.tile_locations.values():
		if is_instance_valid(other) and other != tile and other.is_countdown():
			found.append(other)
	return found


func _show(ran_out: bool) -> void:
	# Tile is a @tool script; the readout has no business in the editor.
	if Engine.is_editor_hint() or _tile.sprite_frames == null:
		return
	var readout: CountdownReadout = _tile.sprite_frames.get_node_or_null(NodePath(_READOUT_NAME)) as CountdownReadout
	if not is_countdown():
		if readout:
			readout.queue_free()
		return
	if readout == null:
		readout = CountdownReadout.new()
		readout.name = _READOUT_NAME
		# Drawn in art pixels: the sprite is centred on its 24x24 frame.
		readout.position = Vector2(-12, -12)
		_tile.sprite_frames.add_child(readout)
	readout.value = remaining()
	if ran_out and _tile.is_visible_in_tree():
		Juice.sparkle(_tile, readout.centre(), Globals.white, 8, 30.0)
