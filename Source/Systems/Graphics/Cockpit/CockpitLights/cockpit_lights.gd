class_name CockpitLights
extends Node2D
## Keeps the cockpit's little indicator lights alive: LEDs flicker or blink on
## their own clocks, a status meter ticks over, and the dash CRT scrolls a
## trace. The walls texture already bakes every light in its "on" colours, so
## this only paints over the pixels that are currently off, in exact palette
## colours, and the art underneath stays the source of truth.
##
## Everything here is ambient. Timings are slow and changes small on purpose:
## the player should feel the cockpit is running, never look at it.

enum Mode {
	## Mostly on, with a rare stutter of quick off/on flicks.
	FLICKER,
	## A steady rhythm: long on, short off.
	BLINK,
}

const _GREEN_OFF: Color = Color("#4c7520")
const _BLUE_OFF: Color = Color("#2c71aa")
const _RED_OFF: Color = Color("#511521")
const _UNLIT: Color = Color("#0f0c2e")

const _CRT_TRACE: Color = Color("#4c7520")
const _CRT_TRACE_HEAD: Color = Color("#659c2a")

## Pixels of the five-light status meter on the strip under the dice tray.
const _METER_PIXELS: Array[Vector2i] = [
	Vector2i(223, 172), Vector2i(225, 172), Vector2i(227, 172),
	Vector2i(229, 172), Vector2i(231, 172),
]

## The dash CRT's screen, in sprite pixels. Its bezel is baked into the walls.
const _CRT_RECT: Rect2i = Rect2i(287, 161, 8, 4)
## One heartbeat of trace, as a row per column (0 is the top of the screen).
const _CRT_TRACE_ROWS: Array[int] = [2, 2, 2, 2, 2, 1, 0, 3, 2, 2, 2, 2, 1, 2, 2, 2]
const _CRT_SCROLL_SPEED: float = 6.0


class Indicator:
	var pixels: Array[Vector2i]
	var off_color: Color
	var mode: Mode
	## BLINK: seconds on, then seconds off.
	var on_time: float
	var off_time: float
	## FLICKER: seconds between stutters, picked fresh each time.
	var min_gap: float
	var max_gap: float

	var is_on: bool = true
	var _timer: float = 0.0
	var _flicks_left: int = 0

	func _init(
		p_pixels: Array[Vector2i], p_off_color: Color, p_mode: Mode,
		p_a: float, p_b: float
	) -> void:
		pixels = p_pixels
		off_color = p_off_color
		mode = p_mode
		if mode == Mode.BLINK:
			on_time = p_a
			off_time = p_b
		else:
			min_gap = p_a
			max_gap = p_b

	## Starts each light somewhere different in its cycle so nothing on the
	## dash pulses in lockstep.
	func randomize_phase(rng: RandomNumberGenerator) -> void:
		if mode == Mode.BLINK:
			_timer = rng.randf_range(0.0, on_time)
		else:
			_timer = rng.randf_range(min_gap, max_gap)

	## Advances the light. Returns true when its state changed.
	func step(delta: float, rng: RandomNumberGenerator) -> bool:
		var was_on: bool = is_on
		_timer -= delta
		if _timer > 0.0:
			return false

		if mode == Mode.BLINK:
			is_on = not is_on
			_timer = on_time if is_on else off_time
		elif _flicks_left > 0:
			is_on = not is_on
			_flicks_left -= 1
			_timer = rng.randf_range(0.04, 0.09)
		elif not is_on:
			is_on = true
			_timer = rng.randf_range(min_gap, max_gap)
		else:
			# A stutter is one or two quick off/on pairs, then a final off
			# that the branch above turns back on for the long gap.
			_flicks_left = 2 * rng.randi_range(1, 2)
			is_on = false
			_timer = rng.randf_range(0.04, 0.09)
		return is_on != was_on


var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _indicators: Array[Indicator] = []

var _meter_level: int = 3
var _meter_timer: float = 0.0
var _crt_scroll: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_indicators = [
		# Left console LED cluster.
		Indicator.new(_square(14, 162), _GREEN_OFF, Mode.FLICKER, 6.0, 14.0),
		Indicator.new(_square(9, 164), _BLUE_OFF, Mode.BLINK, 2.4, 0.25),
		Indicator.new(_square(4, 166), _RED_OFF, Mode.FLICKER, 9.0, 20.0),
		# Lights on the box at the foot of the left console column.
		Indicator.new([Vector2i(78, 161)] as Array[Vector2i], _RED_OFF, Mode.BLINK, 3.1, 0.6),
		Indicator.new([Vector2i(76, 165)] as Array[Vector2i], _BLUE_OFF, Mode.FLICKER, 5.0, 11.0),
	]
	for indicator: Indicator in _indicators:
		indicator.randomize_phase(_rng)


func _process(delta: float) -> void:
	# Hitstop freezes the clock; the dash freezes with everything else.
	if delta == 0.0:
		return

	for indicator: Indicator in _indicators:
		indicator.step(delta, _rng)

	_meter_timer -= delta
	if _meter_timer <= 0.0:
		_meter_timer = _rng.randf_range(0.8, 2.6)
		# Drift a step at a time so the meter reads as a reading, not noise.
		_meter_level = clampi(_meter_level + _rng.randi_range(-1, 1), 1, _METER_PIXELS.size())

	_crt_scroll += delta * _CRT_SCROLL_SPEED
	queue_redraw()


func _draw() -> void:
	for indicator: Indicator in _indicators:
		if indicator.is_on:
			continue
		for pixel: Vector2i in indicator.pixels:
			_draw_pixel(pixel, indicator.off_color)

	_draw_meter()
	_draw_crt()


func _draw_meter() -> void:
	for i: int in range(_METER_PIXELS.size()):
		var color: Color = _UNLIT
		if i < _meter_level:
			color = Globals.green
			if i == _METER_PIXELS.size() - 2:
				color = Globals.yellow
			elif i == _METER_PIXELS.size() - 1:
				color = Globals.red
		_draw_pixel(_METER_PIXELS[i], color)


## The trace scrolls right to left, newest sample at the right edge, which is
## drawn a shade brighter like fresh phosphor.
func _draw_crt() -> void:
	var offset: int = int(_crt_scroll)
	for column: int in range(_CRT_RECT.size.x):
		var sample: int = posmod(offset + column, _CRT_TRACE_ROWS.size())
		var row: int = mini(_CRT_TRACE_ROWS[sample], _CRT_RECT.size.y - 1)
		var color: Color = _CRT_TRACE_HEAD if column >= _CRT_RECT.size.x - 2 else _CRT_TRACE
		_draw_pixel(_CRT_RECT.position + Vector2i(column, row), color)


func _draw_pixel(pixel: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(pixel), Vector2.ONE), color)


## The 2x2 LEDs on the left console, by their top-left pixel.
static func _square(x: int, y: int) -> Array[Vector2i]:
	return [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
