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

## The tween that handles the ship's bobbing animation
var _bob_tween: Tween

## Whichever flash is currently fading. See _flash().
var _flash_tween: Tween

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


## Sets the position of the health bar
func set_health_bar_position(pos: Vector2) -> void:
	health_bar.position = pos


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
	if get_parent().moving_in_world:
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
	_flash(Globals.red, hit_flash_time, true)


## Plays a blue flash effect when shields are damaged
func _shields_hit_flash() -> void:
	_flash(Globals.blue, hit_flash_time, true)


## A short, hard impact flash for authored effects (FLASH_TARGET). Snaps to full
## instantly rather than easing in: it usually lands inside a hitstop, where an
## ease-in would still be at zero when the freeze ends.
func flash(color: Color, duration: float = 0.25) -> void:
	_flash(color, duration, false)


## Every flash drives the same shader parameter, so a new one cancels whatever
## flash is still fading instead of the two tweens fighting over it.
func _flash(color: Color, duration: float, ease_in: bool) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	ship_graphics.material.set_shader_parameter('flash_color', color)

	_flash_tween = create_tween()
	if ease_in:
		_flash_tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 1, duration * 0.05).from(0).set_trans(Tween.TRANS_QUAD)
		_flash_tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 0, duration * 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		ship_graphics.material.set_shader_parameter('flash_amount', 1.0)
		_flash_tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_transparency(alpha: float) -> void:
	ship_graphics.modulate.a = alpha
	ship_graphics.material.set_shader_parameter("alpha", alpha)
