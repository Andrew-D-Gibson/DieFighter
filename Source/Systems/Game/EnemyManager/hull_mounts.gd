class_name HullMounts
extends RefCounted
## The hull of a ship made of parts (ScenarioResource.hull) and the parts
## seated on it. EnemyManager owns the roster; this owns the hull's lifetime,
## where each part sits on it, and the formation space they hold.

const _HULL_KEY: StringName = &"hull"
## How much of the formation a mounted part holds, for its speech box.
const _MOUNT_FOOTPRINT: float = 32.0

var _formation: EnemyFormation
var _hull: ShipHull = null
## Where the hull comes to rest once it has flown in.
var _rest: Vector2 = Vector2.ZERO
## Each mounted part, and where on the hull it sits.
var _mounts: Dictionary[Enemy, Vector2] = {}


func _init(formation: EnemyFormation) -> void:
	_formation = formation


func has_hull() -> bool:
	return is_instance_valid(_hull)


func is_mounted(ship: Enemy) -> bool:
	return _mounts.has(ship)


## Seats [param ship] at [param offset] on the hull build() will stand up.
func mount(ship: Enemy, offset: Vector2) -> void:
	_mounts[ship] = offset


## Stands up [param spec]'s hull under [param parent], waiting
## [param drop] above [param rest] to fly in, and claims [param centre_x]'s
## stretch of the formation for it. Sockets whose part is already gone (a
## Continue) start scarred. Only the old hull goes: parts mounted since stay.
func build(spec: ShipHullResource, parent: Node, rest: Vector2, centre_x: float,
		drop: float, starting: Array[EnemyStateRewardResource], roster: Array[Enemy]) -> void:
	_formation.clear_reservation(_HULL_KEY)
	if is_instance_valid(_hull):
		_hull.queue_free()
	_hull = null
	if spec == null or spec.hull_scene == null:
		_mounts.clear()
		return

	_hull = spec.hull_scene.instantiate()
	_rest = rest
	_hull.position = rest + Vector2(0, -drop)
	parent.add_child(_hull)
	parent.move_child(_hull, 0)

	_formation.reserve(_HULL_KEY, Vector2(centre_x - spec.width * 0.5, centre_x + spec.width * 0.5))

	for spawn: EnemyStateRewardResource in starting:
		if spawn.mounted and not _has_part_at(spawn.mount_offset, roster):
			_hull.scar(spawn.mount_offset, true)
	# A Continue frees parts that were already gone without announcing them.
	for part: Enemy in _mounts.keys():
		if not is_instance_valid(part) or part not in roster:
			_mounts.erase(part)

	for part: Enemy in _mounts:
		var x: float = centre_x + _mounts[part].x
		_formation.reserve(EnemyFormation.ship_key(part),
			Vector2(x - _MOUNT_FOOTPRINT * 0.5, x + _MOUNT_FOOTPRINT * 0.5))
	carry()


func fly_in(duration: float) -> void:
	# Not bound to the hull: a tween freed with it would never finish, and the
	# fly-in waiting on it would hang.
	var arrive: Tween = _hull.get_tree().create_tween()
	arrive.tween_property(_hull, "position", _rest, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await arrive.finished


## Seats every part on the hull, where the hull is this frame.
func carry() -> void:
	for part: Enemy in _mounts:
		if is_instance_valid(part):
			part.position = _hull.mount_position(_mounts[part])


## Moves the hull down by [param dy] as the player jumps away, and lets it go
## once it is below [param bottom].
func fall(dy: float, bottom: float) -> void:
	if not is_instance_valid(_hull):
		return
	_hull.global_position.y += dy
	if _hull.global_position.y > bottom:
		free_hull()


## A part left the fight: scar its socket, and break up the hull with the
## last. Mid-jump the hull is already on its way out, so nothing is scarred.
func unmount(ship: Enemy, jumping: bool) -> void:
	if not _mounts.has(ship):
		return
	var offset: Vector2 = _mounts[ship]
	forget(ship)
	if not is_instance_valid(_hull) or jumping:
		return
	_hull.scar(offset)
	if _mounts.is_empty():
		_formation.clear_reservation(_HULL_KEY)
		_hull.break_up()
		_hull = null


## Drops [param ship] without ceremony: it is being freed off screen.
func forget(ship: Enemy) -> void:
	_mounts.erase(ship)
	_formation.clear_reservation(EnemyFormation.ship_key(ship))


func free_hull() -> void:
	_formation.clear_reservation(_HULL_KEY)
	if is_instance_valid(_hull):
		_hull.queue_free()
	_hull = null
	for part: Enemy in _mounts:
		_formation.clear_reservation(EnemyFormation.ship_key(part))
	_mounts.clear()


func _has_part_at(offset: Vector2, roster: Array[Enemy]) -> bool:
	for part: Enemy in _mounts:
		if is_instance_valid(part) and part in roster and _mounts[part] == offset:
			return true
	return false
