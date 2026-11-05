extends Node2D
## The padlock a Lockout hangs on its tile.
##
## The lock is a blow, so it slams on rather than appearing: it drops in big,
## lands with a squash, a burst of sparks, a ring and a clank, and knocks the
## tile. Its face then counts one pip, two, three: the faces that open it.
## It rattles each time it turns a die away, and pops off when it's opened.

const _LOCK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tractor_lock.tres")

## Approved-palette orange ramp, the lock's own colours.
const _LIGHT: Color = Color("#F29C5D")
const _MID: Color = Color("#EE7F2F")
const _DARK: Color = Color("#BD580F")

const _FACE_SECONDS: float = 0.6
const _SLAM_SECONDS: float = 0.2
const _DROP_PIXELS: float = 10.0
const _SLAM_SCALE: float = 2.4
## The orange wisps that rise off a settled lock.
const _WISP_COUNT: int = 12
const _WISP_START_ALPHA: float = 0.95

@onready var _sprite: Sprite2D = $Sprite2D

var _host: Node2D
var _face_age: float = 0.0
var _released: bool = false
var _settled: bool = false
var _age: float = 0.0


func configure(host: Node2D) -> void:
	_host = host


func _ready() -> void:
	_slam_in()


func _process(delta: float) -> void:
	if _released:
		return
	_age += delta
	if _settled:
		# Left unrounded: under the 6x camera a fraction of an art pixel is
		# still whole screen pixels, so the lock glides instead of ticking.
		_sprite.position.y = sin(_age * 2.4) * 1.2
	queue_redraw()
	_face_age += delta
	if _face_age >= _FACE_SECONDS:
		_face_age -= _FACE_SECONDS
		_sprite.frame = (_sprite.frame + 1) % _sprite.hframes


## The lock turned a die away: it rattles and spits a few sparks.
func on_modifier_triggered() -> void:
	if _released:
		return
	Juice.wiggle(_sprite, 16.0, 0.3)
	_flash(Color(2.0, 1.6, 1.3))
	Juice.sparkle(get_parent(), global_position, _MID, 6, 35.0)


## The lock was opened. Pops up and off, then frees itself. Takes the place
## of the plain free LockoutModifier.on_unregistered would otherwise do.
func release() -> void:
	if _released:
		return
	_released = true
	queue_redraw()
	_sprite.rotation = 0.0
	Juice.sparkle(get_parent(), global_position, Globals.yellow, 12, 55.0, true)
	Juice.ring(get_parent(), global_position, Globals.yellow, 4.0, 0.3, 16.0)
	if is_instance_valid(_host):
		Juice.callout(_host, tr("CALLOUT_UNLOCKED"), Globals.yellow)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_sprite, ^"position:y", -_DROP_PIXELS, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, ^"scale", Vector2(1.4, 1.4), 0.3)
	tween.tween_property(_sprite, ^"modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _slam_in() -> void:
	_sprite.scale = Vector2(_SLAM_SCALE, _SLAM_SCALE)
	_sprite.position = Vector2(0.0, -_DROP_PIXELS)
	_sprite.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_sprite, ^"scale", Vector2.ONE, _SLAM_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, ^"position", Vector2.ZERO, _SLAM_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, ^"modulate:a", 1.0, _SLAM_SECONDS * 0.5)
	tween.chain().tween_callback(_land)


func _land() -> void:
	if _released:
		return
	var parent: Node = get_parent()
	Juice.sparkle(parent, global_position, _LIGHT, 14, 75.0)
	Juice.sparkle(parent, global_position, _DARK, 8, 45.0)
	Juice.ring(parent, global_position, _MID, 6.0, 0.35, 22.0)
	Events.play_sound.emit(_LOCK_SFX)
	Events.camera_shake_small.emit()
	if is_instance_valid(_host):
		Juice.bump(Juice.body_of(_host), 0.35, 0.3)
		Juice.callout(_host, tr("CALLOUT_LOCKED"), _LIGHT)
	_flash(Color(2.2, 1.8, 1.5))
	# Squash on impact, then settle.
	_sprite.scale = Vector2(1.35, 0.7)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, ^"scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _settled = true)


## Brightens the lock past white for a moment, then back.
func _flash(peak: Color) -> void:
	var tween: Tween = create_tween()
	_sprite.self_modulate = peak
	tween.tween_property(_sprite, ^"self_modulate", Color.WHITE, 0.18)


## Low, slow wisps make a persistent lock readable without hiding its die
## faces. They're the lock's only mark on the board (the word LOCKED lives in
## the info panel), so they start bright and fade as they rise.
func _draw() -> void:
	if _released or not _settled:
		return
	for i: int in _WISP_COUNT:
		var phase: float = fposmod(_age * 0.35 + float(i) / float(_WISP_COUNT), 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		# Two lanes a side, so the wisps read as a haze rather than a file.
		var lane: float = 9.0 + float((i >> 1) & 1) * 2.0
		var point: Vector2 = Vector2(side * (lane + sin(phase * TAU) * 1.5), 8.0 - phase * 20.0)
		var color: Color = _LIGHT if i % 3 == 0 else _MID
		color.a = _WISP_START_ALPHA * (1.0 - phase)
		# One art pixel on the game's grid, not an antialiased sub-pixel dot.
		draw_rect(Rect2(point.floor(), Vector2.ONE), color)
