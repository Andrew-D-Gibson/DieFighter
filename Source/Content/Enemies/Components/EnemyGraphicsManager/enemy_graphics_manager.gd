class_name EnemyGraphicsManager
extends Node2D

## The component that handles ship shaking effects
@export var shakeable: Shakeable

## The node containing the ship's visual representation
@export var ship_graphics: Node2D

## The time in seconds for hit flash effects to complete
@export var hit_flash_time: float = 1.0

## The scene to instantiate when the enemy dies
@export var death_explosion: PackedScene

## The component that displays the enemy's health and attitude
@export var health_bar: EnemyHealthBar

## How far set_ship_raised() lifts the ship: past the dice (two above a ship),
## hit sparks and Juice shockwaves (+20), but under damage numbers (+100) so
## the killing blow's number stays readable.
const _RAISED_SHIP_Z_INDEX: int = 50
## How much bigger the ship draws while raised.
const _RAISED_SHIP_SCALE: float = 1.2

## How far the kill shudder throws the ship at its start, in pixels.
const _SHUDDER_STRENGTH: float = 3.0
## How far a killed ship is knocked before it blows, and how fast.
const _LAUNCH_DISTANCE: float = 70.0
const _LAUNCH_SECONDS: float = 0.4
const _LAUNCH_SPIN: float = TAU * 0.6
const _LAUNCH_END_SCALE: float = 0.7

## The tween that handles the ship's bobbing animation
var _bob_tween: Tween

## The health bar's slide between its side and compact spots. See
## set_health_bar_position().
var _health_bar_tween: Tween

## Whichever flash is currently fading. See flash().
var _flash_tween: Tween

## The ship's scale before set_ship_raised() enlarged it.
var _lowered_ship_scale: Vector2 = Vector2.ONE

## Set once the kill sequence takes the ship. A hit landing just before the
## killing blow would otherwise restart the bob when its shake ends, and the
## bob tweens to a fixed global position, dragging a launched wreck back.
var _dying: bool = false

## The kill shudder, and where it rattles around. launch() cuts it short.
var _shudder_tween: Tween
var _shudder_rest: Vector2 = Vector2.ZERO

## Sets up the ship graphics and associated components
func update_ship_graphics(ship_graphics_scene: PackedScene) -> void:
	if ship_graphics:
		ship_graphics.queue_free()
	ship_graphics = ship_graphics_scene.instantiate()
	add_child(ship_graphics)
	
	_set_transparency(1)
	
	shakeable.node_to_shake = ship_graphics


## Plays the death animation sequence
func play_death_animation() -> void:
	# Hide the health bar
	health_bar.visible = false
	
	# Fade out the ship graphics
	var tween_time: float = 0.75
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(
		_set_transparency, 
		1.0,
		0.0,
		tween_time
	).set_trans(Tween.TRANS_CUBIC)\
	.set_ease(Tween.EASE_IN)
	
	# Spawn the death explosion and wait
	var explosion: AnimatedSprite2D = death_explosion.instantiate()
	add_sibling(explosion)
	explosion.global_position = self.global_position
	
	await explosion.animation_finished


## Rattles the ship along [param direction] for [param seconds] of real time,
## dying away to nothing: the fighting-game shudder of a body taking a hit too
## big to absorb. Real time because it plays through the kill's hitstop.
## Moves this manager rather than the ship graphics, which Shakeable and the
## bob own.
func play_kill_shudder(direction: Vector2, seconds: float) -> void:
	_dying = true
	stop_bob_tween()
	_shudder_rest = position
	_shudder_tween = TimeDirector.effect_tween(self)
	_shudder_tween.tween_method(func(progress: float) -> void:
		# Alternating sides every frame, shrinking to rest. Mostly along the
		# line the ship is about to fly, so the shudder points the way.
		var side: float = 1.0 if Engine.get_frames_drawn() % 2 == 0 else -1.0
		var strength: float = _SHUDDER_STRENGTH * (1.0 - progress)
		position = _shudder_rest + direction * side * strength + direction.orthogonal() * side * strength * 0.3,
		0.0, 1.0, seconds)
	_shudder_tween.finished.connect(func() -> void: position = _shudder_rest)


## Dims the world and rushes speed lines in on the ship for [param seconds],
## drawn just under the raised ship so its silhouette stays lit.
func play_kill_focus(seconds: float) -> void:
	# The badges would sit lit over the dim, pulling the eye off the ship.
	health_bar.visible = false
	Juice.kill_focus(self, _RAISED_SHIP_Z_INDEX - 1, seconds, Globals.red)


## Knocks the ship off along [param direction], spinning and shrinking away
## with a spark trail, and resolves where it lands, which is where the death
## explosion then goes.
func launch(direction: Vector2) -> void:
	_dying = true
	stop_bob_tween()
	if _shudder_tween and _shudder_tween.is_valid():
		_shudder_tween.kill()
		position = _shudder_rest
	health_bar.visible = false
	Juice.trail(self, Globals.red, _LAUNCH_SECONDS)

	var spin: float = _LAUNCH_SPIN * signf(direction.x if direction.x != 0.0 else 1.0)
	var tween: Tween = create_tween().set_parallel(true)
	# Expo out: all the speed is up front, like a body leaving a big hit.
	tween.tween_property(self, "position", position + direction * _LAUNCH_DISTANCE, _LAUNCH_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", rotation + spin, _LAUNCH_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", scale * _LAUNCH_END_SCALE, _LAUNCH_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


## Sets the position of the health bar, sliding it there over [param duration]
## seconds rather than jumping when the formation moves it mid-fight.
func set_health_bar_position(pos: Vector2, duration: float = 0.0) -> void:
	if _health_bar_tween:
		_health_bar_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		health_bar.position = pos
		return
	_health_bar_tween = create_tween()
	_health_bar_tween.tween_property(health_bar, "position", pos, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)


## Updates the health bar's attitude indicator
func set_health_bar_attitude(attitude: Enemy.Attitude) -> void:
	health_bar.set_attitude_indicator(attitude)


## Sets up the health bar with the given health component
func set_health_bar_health(health: Health) -> void:
	health_bar.health_component = health
	health_bar._set_health()
	health_bar._set_shields()


## Called when the enemy's shields are hit
func on_shields_hit() -> void:
	stop_bob_tween()
	shakeable.small_shake()
	_shields_hit_flash()
	await shakeable.shake_ended
	start_bob_tween()


## Called when the enemy's health is hit
func on_health_hit() -> void:
	stop_bob_tween()
	shakeable.large_shake()
	_health_hit_flash()
	await shakeable.shake_ended
	start_bob_tween()


## Stops the current bobbing animation
func stop_bob_tween() -> void:
	if _bob_tween:
		_bob_tween.kill()


## Starts a new bobbing animation
func start_bob_tween() -> void:
	if _bob_tween:
		_bob_tween.kill()
		
	# Don't start bobbing if we're translating in space, 
	# like tweening to enter the scene or tweening to another 
	# position on the spawn curve
	if get_parent().moving_in_world or _dying:
		return
		
	var tween_time: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 2, 4)
	# Node-owned so it dies with the ship. A looping tree-owned tween outlives
	# its target, and Godot kills it with "Infinite loop detected".
	_bob_tween = create_tween()
	_bob_tween.tween_property(ship_graphics, 'global_position', self.global_position + Vector2(0, 8), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(ship_graphics, 'global_position', self.global_position, tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.set_loops()


## Plays a red flash effect when health is damaged
func _health_hit_flash() -> void:
	flash(Globals.red, hit_flash_time)


## Plays a blue flash effect when shields are damaged
func _shields_hit_flash() -> void:
	flash(Globals.blue, hit_flash_time)


## A hard impact flash, for hits and authored effects (FLASH_TARGET) alike.
## Snaps to full instantly rather than easing in: impacts usually land inside a
## hitstop, where an ease-in would still be at zero when the freeze ends.
##
## Every flash drives the same shader parameter, so a new one cancels whatever
## flash is still fading instead of the two tweens fighting over it.
func flash(color: Color, duration: float = 0.25) -> void:
	# A ship whose graphics haven't loaded (or a bare one in a test) has
	# nothing to flash.
	if not is_instance_valid(ship_graphics) or ship_graphics.material == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	ship_graphics.material.set_shader_parameter('flash_color', color)
	ship_graphics.material.set_shader_parameter('flash_amount', 1.0)

	_flash_tween = create_tween()
	_flash_tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Lifts the ship above the dice and impact sparks that normally draw over it,
## so a kill flash reads as the whole silhouette. Ship scenes don't set a z of
## their own, so lowering returns to 0.
func set_ship_raised(raised: bool) -> void:
	if not is_instance_valid(ship_graphics):
		return
	# A hit's bump may still be springing the scale; it would undo ours.
	Juice.cancel_bump(ship_graphics)
	ship_graphics.z_index = _RAISED_SHIP_Z_INDEX if raised else 0
	if raised:
		_lowered_ship_scale = ship_graphics.scale
		ship_graphics.scale = _lowered_ship_scale * _RAISED_SHIP_SCALE
	else:
		ship_graphics.scale = _lowered_ship_scale


func _set_transparency(alpha: float) -> void:
	ship_graphics.modulate.a = alpha
	ship_graphics.material.set_shader_parameter("alpha", alpha)
