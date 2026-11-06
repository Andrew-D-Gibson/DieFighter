class_name FateSelfDie
extends Node2D
## Fate's Die hanging over "You" (RECKONING_ENDINGS.md §4), a small FateDieSpin
## the size of the canopy's bone die. Between throws it turns lazily and slows
## toward the face Fate will throw next round, so an attentive player can read
## what's coming. Fate's throw each round is FateThrowStage's: it lifts the
## cube out to the middle of the screen, throws it, and sets it back down on
## the thrown face (lift_out(), land_on()). With nothing known of the next
## throw, it just keeps turning.
##
## Steered here rather than by the cube's own spin, which only wobbles about a
## fixed axis and can't be aimed.

const _SNAP_SHADER: Shader = preload("res://Assets/Shaders/palette_snap.gdshader")
const _SETTLE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")

## Pixels of air between the top of the hull and the cube.
const _HOVER_GAP: float = 9.0
const _BOB_PIXELS: float = 1.5
const _BOB_SPEED: float = 1.4

## Radians a second: turning idly, and the creep it slows to as it settles.
const _LAZY_SPEED: float = 0.9
const _CREEP_SPEED: float = 0.08
## Seconds from the end of a throw until it has all but settled on the next.
const _SETTLE_SECONDS: float = 7.0
## How hard it's drawn to the coming face once settled, per second.
const _PULL: float = 1.6
## How long a thrown face is held before the die drifts on.
const _SHOW_SECONDS: float = 1.6
## Its death: the pause after it stops turning, the float home, the settle.
const _STOP_SECONDS: float = 0.25
const _FLOAT_SECONDS: float = 1.1

## A landed face shows square-ish but tipped, top and left sides in view, so it
## still reads as a cube.
static var _tilt: Quaternion = Basis.from_euler(Vector3(0.4, 0.55, 0.0)).get_rotation_quaternion()

enum Mode { DRIFTING, SHOWING, STOPPED, FLOATING }

var _spin: FateDieSpin
var _sprite: Sprite2D
var _snap: ShaderMaterial
var _ship: Enemy
var _hull_half_height: float = 12.0
var _mode: Mode = Mode.DRIFTING
var _mode_time: float = 0.0
var _age: float = 0.0
var _turn: Quaternion = Quaternion.IDENTITY
var _axis: Vector3 = Vector3(0.3, 1.0, 0.2).normalized()
var _speed: float = _LAZY_SPEED
var _landing_side: int = 0
var _landing_face: FateDie.Face = FateDie.Face.BLANK
## Where it hangs when no ship is left to follow.
var _last_point: Vector2 = Vector2.ZERO
var _floating: bool = false


func _ready() -> void:
	top_level = true
	z_as_relative = false
	_spin = FateDieSpin.new()
	_spin.glyph_scale = 1
	_spin.turning = false
	add_child(_spin)
	var ledger: FateLedger = Globals.fate_ledger
	if ledger:
		_spin.show_faces(ledger.die.faces)
	_sprite = Sprite2D.new()
	_sprite.texture = _spin.get_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_snap = ShaderMaterial.new()
	_snap.shader = _SNAP_SHADER
	_sprite.material = _snap
	add_child(_sprite)
	_turn = Basis.from_euler(Vector3(0.6, 0.4, 0.2)).get_rotation_quaternion()
	visible = false


## Hangs over [param ship], whose hull reaches [param hull_half_height] above
## its centre.
func follow(ship: Enemy, hull_half_height: float) -> void:
	_ship = ship
	_hull_half_height = hull_half_height
	_last_point = _ship_point()


## Where the cube hangs now, in world space: where the shards stream to.
func hover_point() -> Vector2:
	if _floating:
		return global_position
	var bob: float = sin(_age * _BOB_SPEED) * _BOB_PIXELS
	return (_ship_point() + Vector2(0, bob)).round()


## The shards are in: the cube shows, flaring up out of white.
func appear() -> void:
	if visible:
		return
	visible = true
	_snap.set_shader_parameter(&"flash", 1.0)
	create_tween().tween_method(func(value: float) -> void: _snap.set_shader_parameter(&"flash", value),
		1.0, 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_set_mode(Mode.DRIFTING)


## The cube is out being thrown (FateThrowStage): this one is hidden, still
## turned to side [param slot] so a copy of it drawn elsewhere reads right.
func lift_out(slot: int) -> void:
	modulate.a = 0.0
	_landing_side = clampi(slot, 0, FateDie.FACE_COUNT - 1)
	_turn = _turn_showing(_landing_side)
	_set_mode(Mode.SHOWING)


## The throw is over and the cube is back: it shows, landed on [param face]
## (side [param slot]).
func land_on(slot: int, face: FateDie.Face) -> void:
	modulate.a = 1.0
	if not visible or _mode == Mode.STOPPED or _mode == Mode.FLOATING:
		return
	_landing_side = clampi(slot, 0, FateDie.FACE_COUNT - 1)
	_landing_face = face
	_turn = _turn_showing(_landing_side)
	_land()


## What the cube's own little 3D world shows, for a copy drawn elsewhere.
func spin_texture() -> Texture2D:
	return _spin.get_texture()


## Whether the cube is on show, there to be lifted out.
func is_shown() -> bool:
	return visible and modulate.a > 0.0 and _mode != Mode.STOPPED and _mode != Mode.FLOATING


## "You" is gone: the cube stops dead, then floats free to [param rest] (in
## world space), drawing at absolute z [param rest_z] once it gets there, and
## settles. Resolves once it has.
func release_to(rest: Vector2, rest_z: int) -> void:
	_set_mode(Mode.STOPPED)
	_floating = true
	var start: Vector2 = global_position
	await get_tree().create_timer(_STOP_SECONDS).timeout
	if not is_inside_tree():
		return
	_set_mode(Mode.FLOATING)
	z_index = maxi(z_index, rest_z)
	# A lazy arc, up and over, as if it were carried rather than thrown.
	var lift: Vector2 = (start + rest) * 0.5 + Vector2(0, -24)
	var flight: Tween = create_tween()
	flight.tween_method(func(t: float) -> void:
		global_position = start.lerp(lift, t).lerp(lift.lerp(rest, t), t).round(),
		0.0, 1.0, _FLOAT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# It turns once on the way, slowly, and comes in on the face it last
	# showed.
	var from: Quaternion = _turn
	flight.parallel().tween_method(func(t: float) -> void:
		_turn = from.slerp(_resting_turn(), t), 0.0, 1.0, _FLOAT_SECONDS)
	await flight.finished
	if not is_inside_tree():
		return
	Events.play_sound.emit(_SETTLE_SFX)
	Juice.ring(get_parent(), rest, Globals.purple, 12.0, 0.35, 3.0)
	var settle: Tween = create_tween()
	settle.tween_property(self, "global_position", rest + Vector2(0, 2), 0.08).set_ease(Tween.EASE_OUT)
	settle.tween_property(self, "global_position", rest, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await settle.finished


func _process(delta: float) -> void:
	_age += delta
	_mode_time += delta
	match _mode:
		Mode.DRIFTING:
			_drift(delta)
		Mode.SHOWING:
			# Held while lifted out (modulate hides it): FateThrowStage
			# lands it, which restarts the clock.
			if modulate.a > 0.0 and _mode_time >= _SHOW_SECONDS:
				_set_mode(Mode.DRIFTING)
		Mode.STOPPED, Mode.FLOATING:
			pass

	if not _floating:
		if is_instance_valid(_ship):
			_last_point = _ship_point()
			z_index = FateSelfPresentation.absolute_z(_ship.graphics_manager.ship_graphics) + 1 \
				if is_instance_valid(_ship.graphics_manager.ship_graphics) else z_index
		global_position = hover_point()
	# A breath of wobble over whatever it's doing, dying away once it stops.
	var breath: float = 0.0 if _mode == Mode.STOPPED else 1.0
	var wobble: Quaternion = Basis.from_euler(Vector3(sin(_age * 1.1) * 0.05, sin(_age * 0.8) * 0.07, 0.0) * breath).get_rotation_quaternion()
	_spin.set_orientation(wobble * _turn)


## Idle turning that slows, and is drawn round, toward the coming face.
func _drift(delta: float) -> void:
	var target_side: int = _side_for(_upcoming_face())
	var settled: float = 0.0
	if target_side >= 0:
		settled = clampf(_mode_time / _SETTLE_SECONDS, 0.0, 1.0)
	_speed = lerpf(_LAZY_SPEED, _CREEP_SPEED, 1.0 - pow(1.0 - settled, 2.0))
	# The axis wanders, so every side comes round in turn.
	_axis = (_axis + Vector3(sin(_age * 0.37), cos(_age * 0.29), sin(_age * 0.53) * 0.4) * 0.35 * delta).normalized()
	_rotate(delta)
	if target_side >= 0:
		var pull: float = _PULL * settled * settled
		_turn = _turn.slerp(_turn_showing(target_side), 1.0 - exp(-pull * delta))


func _rotate(delta: float) -> void:
	_turn = (Quaternion(_axis, _speed * delta) * _turn).normalized()


func _land() -> void:
	_set_mode(Mode.SHOWING)
	var color: Color = FateFaceCatalog.color_of(_landing_face)
	_spin.flare(_landing_side, color)
	Juice.ring(get_parent(), global_position, color, 14.0, 0.35, 4.0)
	Juice.sparkle(get_parent(), global_position, color, 6, 30.0)
	Events.play_sound.emit(_SETTLE_SFX)


func _set_mode(mode: Mode) -> void:
	_mode = mode
	_mode_time = 0.0


## The face the next round will throw, BLANK when it isn't known (outside the
## Reckoning, or before its first throw).
func _upcoming_face() -> FateDie.Face:
	var director: ReckoningDirector = ReckoningDirector.active()
	return director.upcoming_face() if director else FateDie.Face.BLANK


## The side bearing [param face] that's nearest to coming round already, or -1.
func _side_for(face: FateDie.Face) -> int:
	var ledger: FateLedger = Globals.fate_ledger
	if face == FateDie.Face.BLANK or not ledger:
		return -1
	var best: int = -1
	var best_angle: float = INF
	for slot: int in FateDie.FACE_COUNT:
		if ledger.die.face_at(slot) != face:
			continue
		var angle: float = _turn.angle_to(_turn_showing(slot))
		if angle < best_angle:
			best_angle = angle
			best = slot
	return best


func _turn_showing(side: int) -> Quaternion:
	return _tilt * FateDieSpin.facing(side)


## Comes to rest on whichever side is nearest the viewer.
func _resting_turn() -> Quaternion:
	var best: int = 0
	var best_angle: float = INF
	for side: int in FateDie.FACE_COUNT:
		var angle: float = _turn.angle_to(_turn_showing(side))
		if angle < best_angle:
			best_angle = angle
			best = side
	return _turn_showing(best)


func _ship_point() -> Vector2:
	if not is_instance_valid(_ship):
		return _last_point
	return _ship.global_position + Vector2(0, -_hull_half_height - _HOVER_GAP)
