class_name OverheadConsole
extends Node2D
## A display hanging from the canopy ceiling in the top-left on a rod, opposite
## the hanging dice: the credit readout (MoneyIndicator) in its case, and under
## that a hinged flap holding the EnvironmentMonitor's screen. It waits up in
## the ceiling, out of sight, and drops down only while one of its readouts
## has something to say: credits changing hands, a shop to spend them in, or a
## region rule in force. That keeps the sky clear the rest of the time.
##
## Each readout asks for it with [method request_down] under a reason of its
## own. It stays down while any reason holds and goes back up once none does,
## so the readouts never have to know about each other.
##
## The node's origin is the ceiling mount; everything that moves hangs off
## %Swing, which drops along the rod and swings on the mount.

## How far above its resting place the console waits while stowed: far enough
## that the whole unit, flap included, is above the top of the screen with room
## to spare for camera shake.
@export var stowed_rise: float = 56.0
@export var drop_seconds: float = 0.45
## How far it swings on the rod as it lands, in degrees.
@export var landing_sway_degrees: float = 5.0

@onready var _swing: Node2D = %Swing

## Reasons currently holding the console down.
var _requests: Dictionary[StringName, bool] = {}
## Where it is headed: down, or up into the ceiling.
var _down: bool = false
var _update_queued: bool = false

var _motion_tween: Tween
var _sway_tween: Tween


func _ready() -> void:
	%MoneyIndicator.console = self
	%EnvironmentMonitor.console = self
	_swing.position.y = -stowed_rise
	hide()


## Holds the console down for [param reason] while [param wanted], and lets go
## of it otherwise. Answered at the end of the frame, so one reason letting go
## as another takes hold doesn't send it up and straight back down.
func request_down(reason: StringName, wanted: bool) -> void:
	if wanted:
		_requests[reason] = true
	else:
		_requests.erase(reason)
	if not _update_queued:
		_update_queued = true
		_update.call_deferred()


func is_requested(reason: StringName) -> bool:
	return _requests.has(reason)


## Seconds until the console is all the way down: 0 once it's there, the full
## drop if it's still up or on its way up.
func seconds_until_down() -> float:
	if not _down:
		return drop_seconds
	if _motion_tween and _motion_tween.is_valid() and _motion_tween.is_running():
		return maxf(0.0, drop_seconds - _motion_tween.get_total_elapsed_time())
	return 0.0


## Where [param node], hung off %Swing, sits once the console is down and
## still, wherever the console is right now. Coins aim here rather than at the
## node itself, which may still be on its way down.
func rest_global_position(node: Node2D) -> Vector2:
	return global_transform * node.position


## Swings the console on its rod by [param degrees] and lets it settle: a knock
## from one of the readouts.
func sway(degrees: float) -> void:
	if not _down:
		return
	if _sway_tween and _sway_tween.is_valid():
		_sway_tween.kill()
	_sway_tween = create_tween()
	_sway_tween.tween_property(_swing, "rotation", 0.0, 0.9) \
		.from(deg_to_rad(degrees)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update() -> void:
	_update_queued = false
	var wanted: bool = not _requests.is_empty()
	if wanted == _down:
		return
	if wanted:
		_drop()
	else:
		_rise()


## Drops out of the ceiling, overshoots a little and swings as it lands.
func _drop() -> void:
	_down = true
	show()
	_kill_motion()
	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(_swing, "position:y", 0.0, drop_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Straightens out of the lean it went up with.
	_motion_tween.tween_property(_swing, "rotation", 0.0, drop_seconds * 0.5)
	_motion_tween.chain().tween_callback(sway.bind(landing_sway_degrees))


## Leans as the rod pulls it up, then goes up into the ceiling.
func _rise() -> void:
	_down = false
	_kill_motion()
	if _sway_tween and _sway_tween.is_valid():
		_sway_tween.kill()
	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(_swing, "rotation", deg_to_rad(-4.0), 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_swing, "position:y", -stowed_rise, 0.35) \
		.set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_motion_tween.chain().tween_callback(hide)


func _kill_motion() -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
