class_name JuiceGrapple
extends Node2D
## A two-pronged claw on a tether from a ship, drawn on the game's pixel grid
## (spawn it through JuicePixelated), that snatches a die. GrappleEvent sets it
## up; from there it runs the whole grab itself:
##
##   1. The die sets off from [member start] toward [member catch_point] (on
##      its way to the player's hand), and the claw fires after it.
##   2. They meet: the claw bites ([signal caught]) and holds a beat.
##   3. The claw reels the die back to [member start], then lets go and winds
##      back into the ship, and frees itself.
##
## It moves the die itself, in its own _process, rather than leaving that to a
## Tween: tweens step after every node has processed (and after its redraw is
## flushed), so a claw drawn from a tweened die trails it by a frame, which on
## a fast reel put the claw on the wrong side of the die.
##
## The tether is anchored to the ship's Juice anchor every frame, so a ship
## that slides over mid-grab keeps hold of its line.

## The claw has the die.
signal caught

## The die's trip home before the claw has it.
const RELEASE_SECONDS: float = 0.36
## When the claw fires, into the die's trip, so it meets the die mid-flight.
const FIRE_DELAY_SECONDS: float = 0.1
## The beat between the bite and the reel.
const HOLD_SECONDS: float = 0.08
const REEL_SECONDS: float = 0.4
## How far the die turns, back and forth, as it's dragged in.
const _REEL_WOBBLE_DEGREES: float = 18.0
## The reel's wind-up: the die is first tugged a little further out, as if
## it fought the line, before it's yanked in (an ease-in "back" curve).
const _REEL_OVERSHOOT: float = 1.70158

## The prongs' two segments and the hook at their tips, in game pixels.
const _PRONG_BASE_LENGTH: float = 6.0
const _PRONG_TIP_LENGTH: float = 6.0
const _HOOK_LENGTH: float = 2.0
## How far each prong's base leans off the line of the tether: wide and splayed
## while it flies, tucked round the die's sides once it bites.
const _BASE_ANGLE_OPEN: float = deg_to_rad(85.0)
const _BASE_ANGLE_SHUT: float = deg_to_rad(68.0)
const _TIP_SPLAY_OPEN: float = deg_to_rad(40.0)
## Where the hub sits behind a held die's centre, so the prongs hug its sides.
const _GRIP_SETBACK: float = 8.0
const _CLOSE_SECONDS: float = 0.06
const _RETRACT_SECONDS: float = 0.16

## From the approved palette: the claw's bright metal, and the hub's shadow.
const _METAL_COLOR: Color = Color("#cef0f1")
const _HUB_SHADOW_COLOR: Color = Color("#343330")

## The ship the tether runs from.
var origin_node: Node2D
## The die being snatched, and where it starts and is caught.
var die: Node2D
var start: Vector2
var catch_point: Vector2
## The tether's colour (the action's).
var color: Color = Color.WHITE

## Seconds into the grab, at the current Animation Speed's pace.
var _age: float = 0.0
var _origin: Vector2
## How far along the tether the claw is: 0 in the ship, 1 at the catch.
var _reach: float = 0.0
## Where the claw is reaching to while it has no die.
var _target: Vector2
var _holding: bool = false
var _done: bool = false
## 0 open, 1 shut.
var _shut: float = 0.0


## Seconds from launch until the die is back at [member start].
static func duration() -> float:
	return (RELEASE_SECONDS + HOLD_SECONDS + REEL_SECONDS) / Globals.animation_speed


func _ready() -> void:
	# JuicePixelated runs through pauses (it renders inside hitstops); the
	# grab itself waits out the pause menu with the chain that's waiting on it.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_target = catch_point
	if is_instance_valid(origin_node):
		_origin = Juice.anchor_of(origin_node)


func _process(delta: float) -> void:
	if is_instance_valid(origin_node) and origin_node.is_inside_tree():
		_origin = Juice.anchor_of(origin_node)
	elif _done or not is_instance_valid(die):
		# The ship is gone: nothing left to reel into.
		queue_free()
		return
	if not _done:
		_age += delta * Globals.animation_speed
		_step()
	queue_redraw()


## Moves the die and the claw to where they are at _age.
func _step() -> void:
	var reel_start: float = RELEASE_SECONDS + HOLD_SECONDS
	if _age < RELEASE_SECONDS:
		var trip: float = _age / RELEASE_SECONDS
		_place_die(start.lerp(catch_point, 1.0 - cos(trip * PI / 2.0)))
		var fired: float = clampf((_age - FIRE_DELAY_SECONDS) / (RELEASE_SECONDS - FIRE_DELAY_SECONDS), 0.0, 1.0)
		_reach = fired * fired
		return
	if not _holding:
		_place_die(catch_point)
		_holding = true
		create_tween().tween_property(self, "_shut", 1.0, _CLOSE_SECONDS / Globals.animation_speed)
		caught.emit()
	if _age < reel_start:
		return
	var t: float = minf((_age - reel_start) / REEL_SECONDS, 1.0)
	var eased: float = (_REEL_OVERSHOOT + 1.0) * t * t * t - _REEL_OVERSHOOT * t * t
	_place_die(catch_point.lerp(start, eased))
	if is_instance_valid(die):
		die.rotation_degrees = sin(t * TAU * 1.5) * _REEL_WOBBLE_DEGREES * (1.0 - t)
	if t >= 1.0:
		_let_go()


func _place_die(at: Vector2) -> void:
	if is_instance_valid(die):
		die.global_position = at


## Opens, then winds back into the ship and frees itself.
func _let_go() -> void:
	_done = true
	if is_instance_valid(die):
		die.rotation = 0.0
	_target = _head()
	_holding = false
	_reach = 1.0
	var seconds: float = _RETRACT_SECONDS / Globals.animation_speed
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "_shut", 0.0, seconds * 0.4)
	tween.tween_property(self, "_reach", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _head() -> Vector2:
	if _holding and is_instance_valid(die):
		var line: Vector2 = (die.global_position - _origin).normalized()
		return die.global_position - line * _GRIP_SETBACK
	return _origin.lerp(_target, _reach)


func _draw() -> void:
	if _reach <= 0.01 and not _holding:
		return
	var head: Vector2 = _head()
	var toward: Vector2 = (head - _origin).normalized()
	if toward == Vector2.ZERO:
		return
	var from: Vector2 = to_local(_origin).floor()
	var hub: Vector2 = to_local(head).floor()

	# A faint glow under a one-pixel line, like the tractor beams.
	draw_line(from, hub, Color(color, Juice.soften_flash(0.3)), 3.0, false)
	draw_line(from, hub, color, 1.0, false)

	for side: float in [-1.0, 1.0]:
		_draw_prong(hub, toward, side)
	draw_rect(Rect2(hub - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), _HUB_SHADOW_COLOR)
	draw_rect(Rect2(hub - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), _METAL_COLOR)


## One prong: a base leaning out from the hub, a tip running forward (splayed
## while open), and a hook turned in toward the die.
func _draw_prong(hub: Vector2, toward: Vector2, side: float) -> void:
	var base_angle: float = lerpf(_BASE_ANGLE_OPEN, _BASE_ANGLE_SHUT, _shut) * side
	var knee: Vector2 = hub + toward.rotated(base_angle) * _PRONG_BASE_LENGTH
	var tip_angle: float = lerpf(_TIP_SPLAY_OPEN, 0.0, _shut) * side
	var tip: Vector2 = knee + toward.rotated(tip_angle) * _PRONG_TIP_LENGTH
	var hook: Vector2 = tip + toward.rotated(tip_angle - PI / 2.0 * side) * _HOOK_LENGTH
	draw_line(hub, knee, _METAL_COLOR, 1.0, false)
	draw_line(knee, tip, _METAL_COLOR, 1.0, false)
	draw_line(tip, hook, _METAL_COLOR, 1.0, false)
