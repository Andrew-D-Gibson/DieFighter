class_name CarouselTrackLights
extends Node2D
## The Carousel's track lights, drawn over the tiles in the TileGrid's own
## pixel space: a chevron in the seam between each pair of ring cells, chasing
## round in the direction the ring will turn next, brackets on the ignition
## slot, and an arrow up the conduit from the Reactor. They are the ring's
## telegraph, so they always show the *coming* motion: forward, held or
## reversed by a Gearbox.
##
## Every colour is a palette colour picked by threshold, never a blend, so the
## lights stay in the art's palette while they pulse.

const _WHITE: Color = Color("#CEF0F1")
const _BASE: Color = Color("#2C71AA")
const _FORWARD: Color = Color("#8DF1F4")
const _REVERSE: Color = Color("#EE7F2F")
const _REVERSE_DARK: Color = Color("#BD580F")
const _HOLD: Color = Color("#D03656")
const _HOLD_DARK: Color = Color("#90263C")
const _IGNITION_COLD: Color = Color("#BD580F")
const _IGNITION: Color = Color("#EE7F2F")
const _IGNITION_HOT: Color = Color("#EED35D")

## Cells round the ring, clockwise; set by the behavior.
var ring: Array[Vector2i] = []
var ignition_cell: Vector2i = Vector2i(2, 0)
var reactor_cell: Vector2i = Vector2i(2, 1)
var cell_size: int = 24
## +1 clockwise, -1 counter-clockwise, 0 held: what next turn will do.
var motion: int = 1
## Whether a tile is sitting in the ignition slot right now.
var ignition_loaded: bool = false

var _time: float = 0.0
## 1 just after the ring turns, or the Reactor fires, fading to 0.
var _sweep: float = 0.0
var _ignite: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	_sweep = maxf(0.0, _sweep - delta * 2.0)
	_ignite = maxf(0.0, _ignite - delta * 1.6)
	queue_redraw()


## Every light flares, as the ring clunks round.
func flare_track() -> void:
	_sweep = 1.0


## The ignition brackets and conduit flare, as the Reactor fires the slot.
func flare_ignition() -> void:
	_ignite = 1.0


func _draw() -> void:
	if ring.is_empty():
		return
	for i: int in ring.size():
		_draw_seam_light(i)
	_draw_ignition()
	_draw_conduit()


## The light in the seam between ring[i] and the next cell clockwise.
func _draw_seam_light(i: int) -> void:
	var from_cell: Vector2i = ring[i]
	var to_cell: Vector2i = ring[(i + 1) % ring.size()]
	# The first pixel past the shared edge, on the axis of travel.
	var centre: Vector2i = (from_cell + to_cell) * cell_size / 2 + Vector2i(cell_size, cell_size) / 2
	if motion == 0:
		_draw_bar(centre, to_cell - from_cell, _HOLD if _pulse(1.6) > 0.5 else _HOLD_DARK)
		return
	var dir: Vector2i = (to_cell - from_cell) * motion

	# A comet runs round the ring the way it will turn: a bright head, a short
	# tail behind it, the rest of the seams dim.
	var head: float = _time * 3.0 * motion
	var behind: float = fposmod((head - float(i)) * motion, float(ring.size()))
	var color: Color = _BASE
	if behind < 1.0:
		color = _WHITE
	elif behind < 3.0:
		color = _FORWARD if motion > 0 else _REVERSE
	elif motion < 0:
		color = _REVERSE_DARK
	# The seam into the ignition slot is always hot: that tile fires next.
	var feeds_ignition: bool = (to_cell == ignition_cell and motion > 0) \
		or (from_cell == ignition_cell and motion < 0)
	if feeds_ignition:
		color = _IGNITION_HOT if _pulse(1.2) > 0.5 else _IGNITION
	if _sweep > 0.4:
		color = _WHITE
	_draw_chevron(centre, dir, color)


## A chevron pointing along dir, its tip just past the seam.
func _draw_chevron(centre: Vector2i, dir: Vector2i, color: Color) -> void:
	var side: Vector2i = Vector2i(dir.y, dir.x).abs()
	var tip: Vector2i = centre if (dir.x > 0 or dir.y > 0) else centre - dir.abs()
	var back: Vector2i = tip - dir
	_px(tip, color)
	_px(back + side, color)
	_px(back - side, color)
	_px(back - dir + side * 2, color)
	_px(back - dir - side * 2, color)


## A short bar straddling the seam: the ring is held.
func _draw_bar(centre: Vector2i, along: Vector2i, color: Color) -> void:
	var side: Vector2i = Vector2i(along.y, along.x).abs()
	for k: int in range(-2, 3):
		_px(centre + side * k, color)
		_px(centre - along.abs() + side * k, color)


func _draw_ignition() -> void:
	var color: Color = _IGNITION_COLD
	if _ignite > 0.3:
		color = _WHITE if _ignite > 0.75 else _IGNITION_HOT
	elif ignition_loaded:
		color = _IGNITION_HOT if _pulse(1.0) > 0.5 else _IGNITION
	elif _pulse(1.0) > 0.5:
		color = _IGNITION
	var origin: Vector2i = ignition_cell * cell_size
	var s: int = cell_size - 1
	# An L in each corner, in the tile's transparent rounded corner.
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var c: Vector2i = origin + corner * s
		var sx: int = 1 if corner.x == 0 else -1
		var sy: int = 1 if corner.y == 0 else -1
		_px(c, color)
		_px(c + Vector2i(sx, 0), color)
		_px(c + Vector2i(sx * 2, 0), color)
		_px(c + Vector2i(0, sy), color)
		_px(c + Vector2i(0, sy * 2), color)


## An arrow up the seam between the Reactor and the ignition slot.
func _draw_conduit() -> void:
	var seam: Vector2i = Vector2i(ignition_cell.x * cell_size + cell_size / 2, reactor_cell.y * cell_size)
	var color: Color = _IGNITION if _pulse(0.8) > 0.5 else _IGNITION_COLD
	if _ignite > 0.0:
		color = _WHITE if _ignite > 0.6 else _IGNITION_HOT
	_px(seam + Vector2i(0, -1), color)
	_px(seam + Vector2i(-1, -1), color)
	_px(seam + Vector2i(-2, 0), color)
	_px(seam + Vector2i(1, 0), color)
	_px(seam + Vector2i(-3, 1), color)
	_px(seam + Vector2i(2, 1), color)


func _pulse(hz: float) -> float:
	return 0.5 + 0.5 * sin(_time * TAU * hz)


func _px(p: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), color)
