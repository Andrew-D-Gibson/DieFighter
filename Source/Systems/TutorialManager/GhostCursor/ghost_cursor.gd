class_name GhostCursor
extends Node2D
## A see-through second pointer that acts out what a tutorial step asks for:
## it drags a die onto the Dice Cannon, clicks the map tab, pans the map.
##
## The card says what to do; the ghost shows where and how, which a player
## who has never dragged a die onto a tile can't get from words alone. It
## plays a step's GhostDemos in order, on a loop (fade in, press, eased drag,
## let go, pause), until the TutorialManager stops it as the step closes.
##
## It wears the game's own pointer (the arrow, and the fist while it drags),
## tinted and faded, so it reads as "do this with your mouse" without being
## mistaken for the real one. A drag carries a see-through copy of what it
## picked up (the die, the salvage), since the real thing stays put. It gets out of the way while the player is
## pressing or holding anything, and starts its demos over a moment after
## they let go, so it never fights the player's own hand for attention.

## How the ghost looks at one moment of a demo.
class Pose:
	var position: Vector2
	## 0 to 1, before the ghost's own opacity.
	var alpha: float = 1.0
	var pressed: bool = false
	## How far a click's ring has spread, 0 to 1; negative for no ring.
	var ripple: float = -1.0


const _ARROW_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/default_cursor_raw.png")
const _FIST_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/grab_cursor_raw.png")
## Where the fist sits against the point it holds: the same as the real
## pointer's (MouseCursor._GRAB_OFFSET), so the demo looks like the real drag.
const _FIST_OFFSET: Vector2 = Vector2(-2, -2)
## How solid the copy of a carried die or tile is, within the ghost's opacity.
const _CARRIED_ALPHA: float = 0.6
## The arrow dips this far while a click is held down.
const _PRESS_NUDGE: Vector2 = Vector2(0, 1)

## Over the tutorial's highlight dim (11) and its cards (12), wherever in the
## tree the ghost hangs: it points into the dim's cutouts.
const Z_INDEX: int = 20

const FADE_SECONDS: float = 0.3
## A beat on the thing before pressing it, so the eye lands there first.
const SETTLE_SECONDS: float = 0.25
## How long the button is held still: after the press before moving, and at
## the far end before letting go.
const PRESS_SECONDS: float = 0.18
## Glide speed for a drag, in world pixels per second, kept within the bounds
## below so a short hop isn't a twitch and a long one isn't a crawl.
const MOVE_SPEED: float = 80.0
const MIN_MOVE_SECONDS: float = 0.55
const MAX_MOVE_SECONDS: float = 1.3
## A click glides in from this far down and right of its target.
const CLICK_APPROACH: Vector2 = Vector2(10, 9)
const APPROACH_SECONDS: float = 0.45
## How long the pointer stays after letting go.
const LINGER_SECONDS: float = 0.45
## Hidden between loops.
const GAP_SECONDS: float = 0.7
## How long a click's ring takes to spread and fade, and how far it spreads.
const RIPPLE_SECONDS: float = 0.45
const RIPPLE_RADII: Vector2 = Vector2(2.0, 7.0)
## Once the player lets go of something, the ghost waits this long before it
## starts its demos over.
const RESUME_SECONDS: float = 1.2
## With nothing to point at yet, the ghost looks again this often.
const RETRY_SECONDS: float = 0.25

## The tutorial's action-word yellow (the "Drag" and "Click" in its cards),
## so the ghost reads as the card's instruction being acted out.
@export var tint: Color = Color("#eed35d")
@export_range(0.0, 1.0) var opacity: float = 0.7

## Where NODE targets' paths start: the running scene.
var scene_root: Node
## Whether the player is pressing or holding something right now. A Callable
## so tests can stand in for the mouse.
var is_player_busy: Callable

var _demos: Array[GhostDemo] = []
var _index: int = 0
## Seconds into the current demo.
var _time: float = 0.0
## Seconds left hidden before the current demo starts.
var _wait: float = 0.0
var _sprite: Sprite2D
## The copy of what a drag picked up, under the fist.
var _carried: Sprite2D
## Whether the fist was closed last frame, to notice each new pick-up.
var _gripping: bool = false
var _ripple: float = -1.0


func _init() -> void:
	is_player_busy = _player_is_busy
	z_as_relative = false
	z_index = Z_INDEX
	visible = false
	_carried = Sprite2D.new()
	_carried.self_modulate.a = _CARRIED_ALPHA
	_carried.visible = false
	add_child(_carried)
	_sprite = Sprite2D.new()
	_sprite.texture = _ARROW_TEXTURE
	_sprite.centered = false
	add_child(_sprite)


func _process(delta: float) -> void:
	advance(delta)


## Starts acting out [param demos], from the first, after [param lead_seconds]
## hidden. Replaces whatever was playing.
func play(demos: Array[GhostDemo], root: Node, lead_seconds: float = 0.0) -> void:
	_demos = []
	for demo: GhostDemo in demos:
		if demo and demo.is_complete():
			_demos.append(demo)
		else:
			push_warning("GhostCursor: skipping a demo with nothing to point at.")
	scene_root = root
	_index = 0
	_time = 0.0
	_wait = lead_seconds
	_apply(null)


func stop() -> void:
	_demos = []
	_apply(null)


func is_playing() -> bool:
	return not _demos.is_empty()


## Whether the ghost is on screen right now.
func is_showing() -> bool:
	return visible and modulate.a > 0.0


## Moves the demo on by [param delta] seconds. Called every frame; tests call
## it directly to step through a demo.
func advance(delta: float) -> void:
	if _demos.is_empty():
		_apply(null)
		return
	if is_player_busy.call():
		# Whatever the player is doing, the ghost's demo was just interrupted
		# halfway; it starts again from the top once their hands are free.
		_index = 0
		_time = 0.0
		_wait = RESUME_SECONDS
		_apply(null)
		return
	if _wait > 0.0:
		_wait -= delta
		_apply(null)
		return

	var demo: GhostDemo = _demos[_index]
	var from: Vector2 = demo.at.resolve(scene_root)
	var to: Vector2 = from if demo.gesture == GhostDemo.Gesture.CLICK else demo.to.resolve(scene_root)
	if not GhostTarget.is_resolved(from) or not GhostTarget.is_resolved(to):
		# Not there yet (the die isn't dealt, the map isn't up), or gone
		# halfway: try the next demo, and come back to this one.
		_next(RETRY_SECONDS)
		_apply(null)
		return

	_time += delta
	var pose: Pose = pose_at(demo.gesture, from, to, _time)
	_apply(pose, demo.gesture)
	var gripping: bool = pose.pressed and demo.gesture == GhostDemo.Gesture.DRAG
	if gripping and not _gripping:
		_pick_up_look(demo.at.resolve_node(scene_root), from)
	_gripping = gripping
	_carried.visible = gripping and _carried.texture != null
	if _time >= duration_of(demo.gesture, from, to):
		_next(0.0)


func _next(wait: float) -> void:
	_index = (_index + 1) % _demos.size()
	_time = 0.0
	_wait = wait


func _apply(pose: Pose, gesture: GhostDemo.Gesture = GhostDemo.Gesture.DRAG) -> void:
	var ripple: float = pose.ripple if pose else -1.0
	if ripple != _ripple:
		_ripple = ripple
		queue_redraw()
	if pose == null or pose.alpha <= 0.0:
		visible = false
		modulate.a = 0.0
		_gripping = false
		_carried.visible = false
		return
	visible = true
	global_position = pose.position
	# The tint goes on the pointer alone, so a carried die keeps its own colours.
	modulate = Color(1, 1, 1, opacity * pose.alpha)
	_sprite.self_modulate = tint
	var gripping: bool = pose.pressed and gesture == GhostDemo.Gesture.DRAG
	_sprite.texture = _FIST_TEXTURE if gripping else _ARROW_TEXTURE
	if gripping:
		_sprite.position = _FIST_OFFSET
	elif pose.pressed:
		_sprite.position = _PRESS_NUDGE
	else:
		_sprite.position = Vector2.ZERO


func _draw() -> void:
	if _ripple < 0.0 or _ripple > 1.0:
		return
	var radius: float = lerpf(RIPPLE_RADII.x, RIPPLE_RADII.y, _ripple)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(tint, tint.a * (1.0 - _ripple)), 1.0)


## Dresses the carried copy as [param source] looks now: its first sprite,
## placed against the ghost as the real thing sits against [param grip].
## Nothing to copy (a node with no sprite) leaves just the fist.
func _pick_up_look(source: Node, grip: Vector2) -> void:
	_carried.texture = null
	var look: Node2D = _first_drawn(source)
	if look == null:
		return
	if look is Sprite2D:
		var sprite: Sprite2D = look
		_carried.texture = sprite.texture
		_carried.hframes = sprite.hframes
		_carried.vframes = sprite.vframes
		_carried.frame = sprite.frame
		_carried.region_enabled = sprite.region_enabled
		_carried.region_rect = sprite.region_rect
		_carried.centered = sprite.centered
		_carried.offset = sprite.offset
		_carried.flip_h = sprite.flip_h
		_carried.flip_v = sprite.flip_v
	else:
		var animated: AnimatedSprite2D = look
		_carried.texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		_carried.hframes = 1
		_carried.vframes = 1
		_carried.frame = 0
		_carried.region_enabled = false
		_carried.centered = animated.centered
		_carried.offset = animated.offset
		_carried.flip_h = animated.flip_h
		_carried.flip_v = animated.flip_v
	_carried.position = look.global_position - grip
	_carried.scale = look.global_scale


## The first visible sprite in [param node] or under it, breadth first, so a
## die's or tile's face wins over the small parts drawn on it.
static func _first_drawn(node: Node) -> Node2D:
	if not is_instance_valid(node):
		return null
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_front()
		if current is Sprite2D and (current as Sprite2D).texture \
				and (current as Sprite2D).is_visible_in_tree():
			return current
		if current is AnimatedSprite2D and (current as AnimatedSprite2D).sprite_frames \
				and (current as AnimatedSprite2D).is_visible_in_tree():
			return current
		pending.append_array(current.get_children())
	return null


func _player_is_busy() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Draggable.holding() != null


## --- The timeline: pure, so tests and previews can sample any moment ---

## How long one pass of a demo lasts, the pause after it included.
static func duration_of(gesture: GhostDemo.Gesture, from: Vector2, to: Vector2) -> float:
	var acting: float
	if gesture == GhostDemo.Gesture.CLICK:
		acting = APPROACH_SECONDS + SETTLE_SECONDS + PRESS_SECONDS
	else:
		acting = SETTLE_SECONDS + PRESS_SECONDS + move_seconds(from, to) + PRESS_SECONDS
	return FADE_SECONDS + acting + LINGER_SECONDS + FADE_SECONDS + GAP_SECONDS


static func move_seconds(from: Vector2, to: Vector2) -> float:
	return clampf(from.distance_to(to) / MOVE_SPEED, MIN_MOVE_SECONDS, MAX_MOVE_SECONDS)


## The ghost [param t] seconds into a demo. A CLICK clicks [param from].
static func pose_at(gesture: GhostDemo.Gesture, from: Vector2, to: Vector2, t: float) -> Pose:
	if gesture == GhostDemo.Gesture.CLICK:
		return _click_pose(from, t)
	return _drag_pose(from, to, t)


static func _drag_pose(from: Vector2, to: Vector2, t: float) -> Pose:
	var pose: Pose = Pose.new()
	pose.position = from
	if t < FADE_SECONDS:
		pose.alpha = t / FADE_SECONDS
		return pose
	t -= FADE_SECONDS + SETTLE_SECONDS
	if t < 0.0:
		return pose
	pose.pressed = true
	t -= PRESS_SECONDS
	if t < 0.0:
		return pose
	var move: float = move_seconds(from, to)
	if t < move:
		pose.position = from.lerp(to, _ease(t / move))
		return pose
	pose.position = to
	t -= move + PRESS_SECONDS
	if t < 0.0:
		return pose
	pose.pressed = false
	return _fade_out_after_linger(pose, t)


static func _click_pose(at: Vector2, t: float) -> Pose:
	var pose: Pose = Pose.new()
	var start: Vector2 = at + CLICK_APPROACH
	pose.position = start
	if t < FADE_SECONDS:
		pose.alpha = t / FADE_SECONDS
		return pose
	t -= FADE_SECONDS
	if t < APPROACH_SECONDS:
		pose.position = start.lerp(at, _ease(t / APPROACH_SECONDS))
		return pose
	pose.position = at
	t -= APPROACH_SECONDS + SETTLE_SECONDS
	if t < 0.0:
		return pose
	if t < RIPPLE_SECONDS:
		pose.ripple = t / RIPPLE_SECONDS
	pose.pressed = t < PRESS_SECONDS
	t -= PRESS_SECONDS
	if t < 0.0:
		return pose
	return _fade_out_after_linger(pose, t)


static func _fade_out_after_linger(pose: Pose, t: float) -> Pose:
	t -= LINGER_SECONDS
	if t > 0.0:
		pose.alpha = 1.0 - clampf(t / FADE_SECONDS, 0.0, 1.0)
	return pose


## Slow off the mark and slow into place, like a hand.
static func _ease(x: float) -> float:
	return 0.5 - cos(PI * clampf(x, 0.0, 1.0)) / 2.0
