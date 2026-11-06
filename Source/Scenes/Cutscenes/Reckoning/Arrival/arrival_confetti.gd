class_name ArrivalConfetti
extends Node2D
## Pixel confetti for the triumphant arrivals (RECKONING_ENDINGS.md §6.3): a
## shower of single-pixel and two-pixel flecks in the fleet's colours, that
## spills in off the top of the frame, flutters down and drifts away. Drawn a
## pixel at a time on the 320x180 grid, so it sits with the ships and flares.
##
## Frees itself once the last fleck has left the frame.

## Colours the flecks are drawn in: the ships' factions, and the drive's gold.
var colors: Array[Color] = [Color.WHITE]
## How many flecks there are.
var amount: int = 40
## Seconds the shower spills in over; flecks start staggered across it.
var spill_seconds: float = 1.6
## Which way and how fast the whole shower drifts, in art pixels a second: the
## convoy's heading, so it reads as moving with them.
var drift: Vector2 = Vector2(6.0, 0.0)

const _FALL_SPEED: Vector2 = Vector2(9.0, 16.0)

var _flecks: Array[Fleck] = []
var _age: float = 0.0


class Fleck:
	var position: Vector2
	var fall: float
	var sway: float
	var sway_speed: float
	var phase: float
	var delay: float
	var color: Color
	var tall: bool


func _ready() -> void:
	for i: int in amount:
		var fleck: Fleck = Fleck.new()
		fleck.position = Vector2(_randf(-8.0, Globals.SCREEN_SIZE.x + 8.0), _randf(-12.0, -2.0))
		fleck.fall = _randf(_FALL_SPEED.x, _FALL_SPEED.y)
		fleck.sway = _randf(4.0, 11.0)
		fleck.sway_speed = _randf(1.2, 2.6)
		fleck.phase = _randf(0.0, TAU)
		fleck.delay = _randf(0.0, spill_seconds)
		fleck.color = colors[i % colors.size()]
		fleck.tall = i % 3 == 0
		_flecks.append(fleck)


func _process(delta: float) -> void:
	_age += delta
	var live: bool = false
	for fleck: Fleck in _flecks:
		if _age < fleck.delay:
			live = true
			continue
		fleck.position.y += fleck.fall * delta
		fleck.position += drift * delta
		if fleck.position.y < Globals.SCREEN_SIZE.y + 4.0:
			live = true
	queue_redraw()
	if not live:
		queue_free()


func _draw() -> void:
	for fleck: Fleck in _flecks:
		if _age < fleck.delay:
			continue
		var sway: float = sin(_age * fleck.sway_speed + fleck.phase)
		var at: Vector2 = (fleck.position + Vector2(sway * fleck.sway * 0.35, 0.0)).round()
		# Edge-on for half its flutter: a fleck turning over, so it twinkles.
		var flat: bool = sway > 0.15
		# Fades in off the top, so nothing pops into the frame.
		var fade: float = clampf((_age - fleck.delay) * 3.0, 0.0, 1.0) * 0.9
		var size: Vector2 = Vector2(2, 1) if flat and fleck.tall else Vector2(1, 2) if fleck.tall else Vector2.ONE
		draw_rect(Rect2(at, size), Color(fleck.color, fade))


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
