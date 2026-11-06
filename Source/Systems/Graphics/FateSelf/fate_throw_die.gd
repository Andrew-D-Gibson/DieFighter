class_name FateThrowDie
extends FateDieSpin
## Fate's Die thrown for real (FateThrowStage): the cube tumbling across an
## invisible tray, a RigidBody3D with floor and walls in this viewport's own
## 3D world. The tray is drawn nowhere; only the die shows.
##
## Physics can't be told which face to land on, so the throw is recorded and
## replayed. The body is thrown for real, hidden, and every physics tick of it
## is kept; once it has come to rest, whichever side ended up on top is known,
## and the cube drawn in its place wears Fate's chosen face there: the mesh is
## turned inside the body so the chosen side sits where the top one landed
## (prepare_landing()). The replay then moves the mesh along the recorded
## path, so it looks, and is, a die that landed on that face.
##
## The throw is seeded: the same seed rolls the same way. It never touches the
## game's RNG, which decided the face long before.
##
## Draws at art-pixel scale like FateDieSpin (draw its texture with nearest
## filtering and palette_snap.gdshader).

## The recording is complete: the die is at rest and its landing can be
## prepared.
signal settled()
## The replayed die struck the floor or a wall hard enough to hear.
signal knocked()

## Texels to a glyph pixel: a face is face_size(3) = 29 pixels wide on
## screen, a cube a bit bigger than the canopy's bone die times two.
const _GLYPH_SCALE_THROWN: int = 3
## The tray's floor, as how far from the middle the die's centre may stray.
const _TRAY_HALF: Vector2 = Vector2(2.0, 1.1)
const _WALL_HEIGHT: float = 8.0
## What the camera sees, in cube widths: the tray with a die's width to spare,
## and how steeply it looks down on it.
const _VIEW_UNITS: Vector2 = Vector2(6.2, 4.14)
const _CAMERA_PITCH: float = 58.0
## It's thrown from the left, in the air, across the tray.
const _START: Vector3 = Vector3(-1.5, 1.1, 0.1)
## Gravity and how soon the tumble dies: tuned for a throw that takes a second
## and a half to read, not for a die that falls like a stone.
const _GRAVITY_SCALE: float = 1.0
const _LINEAR_DAMP: float = 1.6
const _ANGULAR_DAMP: float = 2.2
const _FRICTION: float = 0.7
const _BOUNCE: float = 0.22
## The die is at rest after this many ticks below the speeds beneath.
const _REST_TICKS: int = 8
const _REST_LINEAR: float = 0.3
const _REST_ANGULAR: float = 0.7
## A throw that hasn't come to rest by now is brought to rest: it never
## hangs there (a die leaning on a wall, say).
const _MAX_SECONDS: float = 2.2
## Downward speed, in cube widths a second, that counts as a knock.
const _KNOCK_SPEED: float = 1.0
## The seconds the replay spends easing from the recording's last pose to
## flat on the floor, square to the viewer.
const SQUARE_UP_SECONDS: float = 0.3

var _body: RigidBody3D
var _camera: Camera3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _recording: bool = false
var _record_dt: float = 1.0 / 60.0
var _rest_count: int = 0
var _last_velocity: Vector3 = Vector3.ZERO
var _positions: PackedVector3Array = PackedVector3Array()
var _rotations: Array[Quaternion] = []
var _knock_times: PackedFloat32Array = PackedFloat32Array()
var _knock_cursor: int = 0
## The recording's last pose, and the flat one it eases to.
var _end_rotation: Quaternion = Quaternion.IDENTITY
var _flat_rotation: Quaternion = Quaternion.IDENTITY
var _top_side: int = 0
## How the mesh sits in the body, so the chosen side is the one landing up,
## and the turn that squares its glyph to the viewer, eased in at the end.
var _mesh_turn: Quaternion = Quaternion.IDENTITY
var _square_turn: Quaternion = Quaternion.IDENTITY


func _init() -> void:
	super()
	glyph_scale = _GLYPH_SCALE_THROWN
	turning = false


func _ready() -> void:
	super()
	size = Vector2i((_VIEW_UNITS * float(face_size(glyph_scale))).round())
	_camera = get_camera_3d()
	if _camera == null:
		_camera = Camera3D.new()
		add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _VIEW_UNITS.y
	# Looking down the tray toward -Z, so a glyph's top is -Z when it's upright
	# to the viewer.
	var pitch: float = deg_to_rad(_CAMERA_PITCH)
	_camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * 8.0
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)
	_build_tray()
	_pivot.visible = false


func _physics_process(_delta: float) -> void:
	if not _recording:
		return
	_record_tick()


## Throws the die, hidden, from [param seed_value]. Emits settled once it's at
## rest; the recording is read after that.
func throw(seed_value: int) -> void:
	_rng.seed = seed_value
	_positions.clear()
	_rotations.clear()
	_knock_times.clear()
	_knock_cursor = 0
	_rest_count = 0
	_record_dt = 1.0 / float(Engine.physics_ticks_per_second)
	_body.freeze = false
	_body.global_transform = Transform3D(
		Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)),
		_START + Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.4, 0.4)))
	_body.linear_velocity = Vector3(_rng.randf_range(2.9, 3.5), _rng.randf_range(0.2, 1.4), _rng.randf_range(-1.1, 1.1))
	var spin: float = _rng.randf_range(10.0, 15.0)
	_body.angular_velocity = Vector3(
		spin * (1.0 if _rng.randf() < 0.5 else -1.0),
		_rng.randf_range(-6.0, 6.0),
		_rng.randf_range(-7.0, 7.0))
	_recording = true


## Whether the throw is recorded and at rest.
func is_settled() -> bool:
	return not _recording and not _rotations.is_empty()


## Seconds of recording.
func throw_seconds() -> float:
	return maxf(0.0, (_rotations.size() - 1) * _record_dt)


## The seconds a replay takes: the recording, then the die squaring up.
func replay_seconds() -> float:
	return throw_seconds() + SQUARE_UP_SECONDS


## The side that came to rest on top, before the mesh was turned. Meaningful
## once settled.
func top_side() -> int:
	return _top_side


## Makes side [param side] the one that lands up, and turns it to read the
## right way up from the camera. Call once settled, before replaying.
func prepare_landing(side: int) -> void:
	var from_normal: Vector3 = _SIDES[side][0]
	var to_normal: Vector3 = _SIDES[_top_side][0]
	var best: Quaternion = Quaternion.IDENTITY
	var best_error: float = INF
	# The turns that carry that side to the top are one per quarter turn about
	# it; the one that leaves its glyph nearest the right way up wins, so the
	# last squaring up is the smallest.
	var carry: Quaternion = _arc(from_normal, to_normal)
	for quarter: int in 4:
		var turn: Quaternion = Quaternion(to_normal, quarter * PI * 0.5) * carry
		var glyph_up: Vector3 = (Basis(_end_rotation) * Basis(turn)) * (_SIDES[side][1] as Vector3)
		var error: float = absf(_yaw_to_screen_up(glyph_up))
		if error < best_error:
			best_error = error
			best = turn
	_mesh_turn = best
	var glyph_up_end: Vector3 = (Basis(_flat_rotation) * Basis(_mesh_turn)) * (_SIDES[side][1] as Vector3)
	_square_turn = Quaternion(Vector3.UP, _yaw_to_screen_up(glyph_up_end))


## Poses the die [param seconds] into the replay. The mesh is hidden until the
## first call.
func replay_at(seconds: float) -> void:
	if _rotations.is_empty():
		return
	_pivot.visible = true
	var count: int = _rotations.size()
	var rotation: Quaternion
	var position: Vector3
	if seconds <= throw_seconds():
		var at: float = clampf(seconds / _record_dt, 0.0, count - 1.0)
		var i: int = mini(int(at), count - 1)
		var j: int = mini(i + 1, count - 1)
		var f: float = at - i
		rotation = _rotations[i].slerp(_rotations[j], f)
		position = _positions[i].lerp(_positions[j], f)
		_fire_knocks(seconds)
	else:
		var t: float = clampf((seconds - throw_seconds()) / SQUARE_UP_SECONDS, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		rotation = _end_rotation.slerp(_flat_rotation, t)
		position = _positions[count - 1].lerp(Vector3(_positions[count - 1].x, 0.5, _positions[count - 1].z), t)
		rotation = Quaternion.IDENTITY.slerp(_square_turn, t) * rotation
		_fire_knocks(throw_seconds())
	_pivot.position = position
	_pivot.basis = Basis(rotation) * Basis(_mesh_turn)


## Where the die rests, in this viewport's pixels.
func rest_point() -> Vector2:
	return _camera.unproject_position(Vector3(_positions[_positions.size() - 1].x, 0.5, _positions[_positions.size() - 1].z)) \
		if not _positions.is_empty() else start_point()


## Where it's thrown from, in this viewport's pixels.
func start_point() -> Vector2:
	return _camera.unproject_position(_START)


## Pixels a cube's width takes on screen.
func cube_pixels() -> float:
	return float(face_size(glyph_scale))


func _record_tick() -> void:
	var rotation: Quaternion = _body.global_basis.get_rotation_quaternion()
	var velocity: Vector3 = _body.linear_velocity
	if not _rotations.is_empty() and _body.linear_velocity.y - _last_velocity.y > _KNOCK_SPEED and _last_velocity.y < -_KNOCK_SPEED:
		_knock_times.append(throw_seconds() + _record_dt)
	_last_velocity = velocity
	_positions.append(_body.global_position)
	_rotations.append(rotation)
	var still: bool = velocity.length() < _REST_LINEAR and _body.angular_velocity.length() < _REST_ANGULAR
	_rest_count = _rest_count + 1 if still and _body.global_position.y < 0.62 else 0
	var elapsed: float = _rotations.size() * _record_dt
	if _rest_count >= _REST_TICKS or elapsed >= _MAX_SECONDS:
		_finish()


func _finish() -> void:
	_recording = false
	_body.freeze = true
	_end_rotation = _rotations[_rotations.size() - 1]
	var basis: Basis = Basis(_end_rotation)
	_top_side = 0
	var best: float = -INF
	for side: int in _SIDES.size():
		var up: float = (basis * (_SIDES[side][0] as Vector3)).y
		if up > best:
			best = up
			_top_side = side
	# Flat: the top side's normal straight up, turned the shortest way.
	var top_normal: Vector3 = basis * (_SIDES[_top_side][0] as Vector3)
	_flat_rotation = (_arc(top_normal, Vector3.UP) * _end_rotation).normalized()
	settled.emit()


func _fire_knocks(seconds: float) -> void:
	while _knock_cursor < _knock_times.size() and _knock_times[_knock_cursor] <= seconds:
		_knock_cursor += 1
		knocked.emit()


## The turn that carries [param from] onto [param to], the short way, or a half
## turn about a side axis when they're opposite.
static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var dot: float = from.dot(to)
	if dot > 0.99999:
		return Quaternion.IDENTITY
	if dot < -0.99999:
		var axis: Vector3 = from.cross(Vector3.RIGHT)
		if axis.length() < 0.1:
			axis = from.cross(Vector3.UP)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(from.cross(to).normalized(), acos(clampf(dot, -1.0, 1.0)))


## The signed turn about the vertical that points [param glyph_up] (what the
## glyph calls up, in the world) at the top of the screen, which is -Z here.
static func _yaw_to_screen_up(glyph_up: Vector3) -> float:
	var flat: Vector2 = Vector2(glyph_up.x, glyph_up.z)
	if flat.length() < 0.001:
		return 0.0
	# Rotating a vector by +a about Y takes (x, z) to (x cos a + z sin a, -x sin a + z cos a).
	var target: Vector2 = Vector2(0.0, -1.0)
	return -flat.angle_to(target)


## Floor and four walls, and the body, all in this viewport's own world.
func _build_tray() -> void:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = _FRICTION
	material.bounce = _BOUNCE
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.physics_material_override = material
	floor_body.add_child(_box_shape(Vector3(30.0, 1.0, 30.0), Vector3(0.0, -0.5, 0.0)))
	add_child(floor_body)
	var wall_body: StaticBody3D = StaticBody3D.new()
	wall_body.physics_material_override = material
	var reach: Vector2 = _TRAY_HALF + Vector2.ONE * 0.5
	for sign_x: float in [-1.0, 1.0]:
		wall_body.add_child(_box_shape(Vector3(1.0, _WALL_HEIGHT, 30.0), Vector3(sign_x * (reach.x + 0.5), _WALL_HEIGHT * 0.5, 0.0)))
	for sign_z: float in [-1.0, 1.0]:
		wall_body.add_child(_box_shape(Vector3(30.0, _WALL_HEIGHT, 1.0), Vector3(0.0, _WALL_HEIGHT * 0.5, sign_z * (reach.y + 0.5))))
	add_child(wall_body)

	_body = RigidBody3D.new()
	_body.physics_material_override = material
	_body.gravity_scale = _GRAVITY_SCALE
	_body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_body.linear_damp = _LINEAR_DAMP
	_body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_body.angular_damp = _ANGULAR_DAMP
	_body.continuous_cd = true
	_body.add_child(_box_shape(Vector3.ONE, Vector3.ZERO))
	_body.position = _START
	_body.freeze = true
	add_child(_body)


static func _box_shape(extent: Vector3, at: Vector3) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = extent
	shape.shape = box
	shape.position = at
	return shape
