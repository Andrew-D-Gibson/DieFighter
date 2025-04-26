class_name EnemyGraphicsManager
extends Node2D

## The component that handles ship shaking effects
@export var shakeable: Shakeable

## The node containing the ship's visual representation
@export var ship_graphics: Node2D

## The time in seconds for hit flash effects to complete
@export var hit_flash_time: float = 0.5

## The scene to instantiate when the enemy dies
@export var death_explosion: PackedScene

## The component that displays the enemy's health and attitude
@export var health_bar: EnemyHealthBar

## The tween that handles the ship's bobbing animation
var _bob_tween: Tween


## Sets up the ship graphics and associated components
func update_ship_graphics(ship_graphics_scene: PackedScene) -> void:
	if ship_graphics:
		ship_graphics.queue_free()
	ship_graphics = ship_graphics_scene.instantiate()
	add_child(ship_graphics)
	
	shakeable.node_to_shake = ship_graphics
	start_bob_tween()


## Plays the death animation sequence
func play_death_animation() -> void:
	# Hide the health bar
	health_bar.visible = false
	
	# Fade out the ship graphics
	var tween_time: float = 0.75
	var tween = get_tree().create_tween()
	tween.tween_property(ship_graphics, "modulate", Color(1,1,1,0), tween_time)
	
	# Spawn the death explosion and wait
	var explosion = death_explosion.instantiate()
	add_sibling(explosion)
	explosion.global_position = self.global_position
	
	await explosion.animation_finished


## Sets the position of the health bar
func set_health_bar_position(position: Vector2) -> void:
	health_bar.position = position


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
		
	var tween_time = randf_range(2, 4)
	_bob_tween = get_tree().create_tween()
	_bob_tween.tween_property(ship_graphics, 'global_position', self.global_position + Vector2(0, 8), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(ship_graphics, 'global_position', self.global_position, tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.set_loops()


## Plays a red flash effect when health is damaged
func _health_hit_flash() -> void:
	ship_graphics.material.set_shader_parameter('color', Globals.red)
	
	var tween = get_tree().create_tween()
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 1, hit_flash_time * 0.05).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 0, hit_flash_time * 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Plays a blue flash effect when shields are damaged
func _shields_hit_flash() -> void:
	ship_graphics.material.set_shader_parameter('color', Globals.blue)
	
	var tween = get_tree().create_tween()
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 1, hit_flash_time * 0.05).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 0, hit_flash_time * 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
