class_name ChaseLights
extends Node2D
## Running lights set in the Carousel's viewport ring, chasing round it. One
## in every few is lit and the pattern walks along the track; when the ship's
## tile ring turns they race the way it turned for a moment, and a hit on the
## hull browns them out in a stutter before they come back.
##
## The shell already paints the dark sockets, so this only draws the lit
## ones.

## Each light's socket, in screen pixels, in order along the track.
@export var lights: PackedVector2Array
## One lit in every this many.
@export var spacing: int = 3
## Lights the chase moves per second at rest.
@export var chase_speed: float = 2.5
## How much faster the chase runs while the ring is turning.
@export var race_boost: float = 9.0
@export var race_time: float = 0.9
@export var lit_color: Color = Color("#eed35d")
@export var hot_color: Color = Color("#cef0f1")

## How long a hit browns the lights out.
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
	# The track runs left to right over the top of the view; clockwise
	# carries the tile ring's top row the same way.
	_direction = 1.0 if steps > 0 else -1.0
	_race = race_time


func _process(delta: float) -> void:
	# Hitstop freezes the clock; the lights freeze with everything else.
	if delta == 0.0:
		return
	_race = maxf(0.0, _race - delta)
	_brownout = maxf(0.0, _brownout - delta)
	var speed: float = chase_speed * (1.0 + race_boost * (_race / race_time))
	_offset += speed * _direction * delta
	queue_redraw()


func _draw() -> void:
	if _brownout > 0.0 and fmod(_brownout, 0.12) > 0.05:
		return
	var lead: int = floori(_offset)
	for i: int in lights.size():
		var phase: int = posmod(i - lead, spacing)
		var at: Vector2 = to_local(lights[i])
		if phase == 0:
			# A 2x2 lamp with a hot corner.
			draw_rect(Rect2(at, Vector2(2, 2)), lit_color)
			draw_rect(Rect2(at, Vector2.ONE), hot_color)
		elif phase == 1 and spacing > 2:
			# The light just passed, still cooling.
			draw_rect(Rect2(at, Vector2.ONE), lit_color)
