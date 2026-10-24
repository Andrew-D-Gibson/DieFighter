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

## The absolute z a dying ship's wreck and explosions draw at: under the
## cockpit walls (the Graphics layer sits at -2) and everything mounted in
## front of them, so the blasts read as out past the canopy, not inside it.
const WRECK_Z_INDEX: int = -3
## How long the hull's flash takes to clear once it cracks. Short, so the
## pieces show their own art while they drift and the eye can follow each one
## to its explosion; the pieces share the hull's material, so they fade too.
const _BREAK_FLASH_SECONDS: float = 0.35

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
## bob tweens to a fixed global position, tugging the shuddering hull about.
var _dying: bool = false

## The kill shudder, and where it rattles around. break_apart() cuts it short.
var _shudder_tween: Tween
var _shudder_rest: Vector2 = Vector2.ZERO

## Once dying, the ship draws through this, on the game's pixel grid. See
## pixelate().
var _pixel_view: JuicePixelated
## The ship graphics' parent inside _pixel_view. It tracks this node, so
## everything that moves the manager still moves the ship.
var _pixel_body: Node2D

## Where the wreck goes. See wreck_layer().
var _wreck_layer: Node2D

## Sets up the ship graphics and associated components
func update_ship_graphics(ship_graphics_scene: PackedScene) -> void:
	if ship_graphics:
		ship_graphics.queue_free()
	ship_graphics = ship_graphics_scene.instantiate()
	add_child(ship_graphics)
	
	_set_transparency(1)
	
	shakeable.node_to_shake = ship_graphics


## Cracks the ship into pieces that drift apart and blow up one by one,
## carried along [param kick] (the killing blow's direction, or zero), each
## blast sounding [param blast_sound]. Resolves once the last explosion has
## played out.
func break_apart(kick: Vector2, blast_sound: SoundEffectResource) -> void:
	_dying = true
	stop_bob_tween()
	if _shudder_tween and _shudder_tween.is_valid():
		_shudder_tween.kill()
		position = _shudder_rest
	health_bar.visible = false
	if not is_instance_valid(ship_graphics):
		return
	flash(Color.WHITE, _BREAK_FLASH_SECONDS)
	var wreck: ShipWreck = ShipWreck.shatter(wreck_layer(), ship_graphics, kick, death_explosion, blast_sound)
	ship_graphics.visible = false
	await wreck.finished


## The layer a dying ship's debris and explosions belong on. See
## [constant WRECK_Z_INDEX]. Detached from the manager's transform, so the
## kill shudder doesn't drag what's already been thrown off; place things on
## it by global position.
func wreck_layer() -> Node2D:
	if not is_instance_valid(_wreck_layer):
		_wreck_layer = Node2D.new()
		_wreck_layer.top_level = true
		_wreck_layer.z_as_relative = false
		_wreck_layer.z_index = WRECK_Z_INDEX
		add_child(_wreck_layer)
	return _wreck_layer


## From here on the ship draws on the game's 320x180 pixel grid, like the
## effects around it. The kill raises, rattles, spins and shrinks the hull;
## drawn straight to the full-resolution screen, that resamples it into smooth
## sub-pixel art. Inside a JuicePixelated it turns and shrinks a game pixel at
## a time. One-way, since only a dying ship moves like that.
func pixelate() -> void:
	if _pixel_view or not is_instance_valid(ship_graphics):
		return
	_pixel_body = Node2D.new()
	_pixel_view = JuicePixelated.spawn(self, _pixel_body, ship_graphics.z_index)
	ship_graphics.reparent(_pixel_body, false)


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
	# Inside the pixel view the ship's own z only sorts it against its
	# trail; the view is what sits among the world's layers.
	if _pixel_view:
		_pixel_view.z_index = ship_graphics.z_index
	if raised:
		_lowered_ship_scale = ship_graphics.scale
		ship_graphics.scale = _lowered_ship_scale * _RAISED_SHIP_SCALE
	else:
		ship_graphics.scale = _lowered_ship_scale


func _set_transparency(alpha: float) -> void:
	ship_graphics.modulate.a = alpha
	ship_graphics.material.set_shader_parameter("alpha", alpha)
