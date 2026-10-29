class_name AttackTweenEvent
extends EffectEvent

var _tween_time: float = 1.25

## Where the die left from, the ship it's flying at, and where that ship was
## last seen, in case it's gone before the die arrives.
var _start: Vector2
var _target: Node2D
var _target_position: Vector2


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty() or not is_instance_valid(targets[0]):
		return
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(actor):
		return

	_target = targets[0] as Node2D
	_target_position = _aim_point(_target)
	_start = activator_die.global_position
	var adjusted_time: float = _tween_time / Globals.animation_speed

	# The target is read every frame rather than once at launch: when another
	# ship dies the survivors slide over, and a die aimed at where the target
	# used to be would sail into empty space.
	var tween: Tween = actor.create_tween().set_parallel(true)
	tween.tween_method(_fly, 0.0, 1.0, adjusted_time) \
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_IN)
	tween.tween_property(
		activator_die, "rotation_degrees", 360.0 * 6.0, adjusted_time
	).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished


## One frame of the flight. [param progress] is already eased, and overshoots
## past 1 with the spring, which lerp carries on through the target.
func _fly(progress: float) -> void:
	if not is_instance_valid(activator_die):
		return
	if is_instance_valid(_target):
		_target_position = _aim_point(_target)
	activator_die.global_position = _start.lerp(_target_position, progress)


## Where on [param target] the die strikes. The player's ship has no body on
## screen, so a die fired at it hits the hull readout on its health bar: the
## number the shot is about to knock down. Every attack tween aimed at the
## player today is a hull shot (status shots, ion bolts and the like fly with
## their own juice), and the bar moves with each ship's cockpit, so it's read
## live rather than fixed.
func _aim_point(target: Node2D) -> Vector2:
	if target is Player:
		return (target as Player).get_hull_anchor()
	return target.global_position
