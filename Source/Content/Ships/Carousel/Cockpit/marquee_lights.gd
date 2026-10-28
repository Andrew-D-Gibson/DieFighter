class_name MarqueeLights
extends Node2D
## The bulbs along the Carousel's awning, chasing round like a fairground
## ride's. Every third bulb is lit and the pattern walks along the trim; when
## the ring turns they race the way it turned for a moment, and a hit on the
## hull browns them out in a stutter before they come back.
##
## The shell already paints the sockets, so this only draws the glass.

## Each bulb's socket, in screen pixels, left to right.
@export var bulbs: PackedVector2Array
## Bulbs the chase moves per second at rest.
@export var chase_speed: float = 2.5
## How much faster the chase runs while the ring is turning.
@export var race_boost: float = 9.0
@export var race_time: float = 0.9

const _LIT: Color = Color("#eed35d")
const _HOT: Color = Color("#cef0f1")
const _UNLIT: Color = Color("#98873b")
## How long a hit browns the bulbs out, and how they stutter back.
const _BROWNOUT_TIME: float = 0.5

var _offset: float = 0.0
var _direction: float = 1.0
var _race: float = 0.0
var _brownout: float = 0.0


func _ready() -> void:
	Events.player_health_hit.connect(func() -> void: _brownout = _BROWNOUT_TIME)
	_listen_to_ring.call_deferred()


## The ring belongs to the ship's rules under the TileGrid, which is ready
## after the cockpit.
func _listen_to_ring() -> void:
	var grid: TileGrid = Globals.tile_grid
	var behavior: CarouselBehavior = grid.ship_behavior as CarouselBehavior \
		if is_instance_valid(grid) else null
	if behavior and not behavior.ring_turned.is_connected(_on_ring_turned):
		behavior.ring_turned.connect(_on_ring_turned)


func _on_ring_turned(steps: int) -> void:
	# The awning runs left to right across the top of the screen; clockwise
	# carries the ring's top row the same way.
	_direction = 1.0 if steps > 0 else -1.0
	_race = race_time


func _process(delta: float) -> void:
	# Hitstop freezes the clock; the bulbs freeze with everything else.
	if delta == 0.0:
		return
	_race = maxf(0.0, _race - delta)
	_brownout = maxf(0.0, _brownout - delta)
	var speed: float = chase_speed * (1.0 + race_boost * (_race / race_time))
	_offset += speed * _direction * delta
	queue_redraw()


func _draw() -> void:
	if _brownout > 0.0 and fmod(_brownout, 0.12) > 0.05:
		for bulb: Vector2 in bulbs:
			_draw_bulb(bulb, _UNLIT, _UNLIT)
		return
	var lead: int = floori(_offset)
	for i: int in bulbs.size():
		var lit: bool = posmod(i - lead, 3) == 0
		_draw_bulb(bulbs[i], _HOT if lit else _UNLIT, _LIT if lit else _UNLIT)


## A bulb is two pixels on the trim: its hot filament and the glass beside it.
func _draw_bulb(socket: Vector2, filament: Color, glass: Color) -> void:
	var at: Vector2 = to_local(socket)
	draw_rect(Rect2(at, Vector2.ONE), filament)
	draw_rect(Rect2(at + Vector2.LEFT, Vector2.ONE), glass)
