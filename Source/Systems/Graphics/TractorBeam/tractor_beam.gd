## TractorBeam
## The enemy reaching out and taking the die you just spent.
##
## This is the game's thesis played out on screen: you arm your enemy with
## every die you use. It used to be a polite float across the screen. Now the
## ship locks a beam onto the die, the die resists for a beat, and then it's
## yanked across and lands in the enemy's hand with a sound that says what you
## just paid for: a low thunk on a slot that will hurt you, a flat click on a
## slot that does nothing.
##
## The beat scales with the die's face value, like the enemy's own handover
## (EnemyActionEvent): a 1 is plucked away, a 6 fights and drags.
##
## Purely cosmetic and non-blocking. GiveDieToTargetEvent has already put the
## die in the enemy's queue before the beam starts; the beam only takes over
## *how it gets there*, so the player can keep placing dice while it plays.
class_name TractorBeam
extends Node2D

const _LOCK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tractor_lock.tres")
const _DREAD_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _DEAD_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dead_click.tres")
const _HIT_PARTICLES: PackedScene = preload("uid://doi43icsr46q0")

enum Phase {
	LOCK,    ## The beam reaches out from the ship to the die (catching it
			 ## mid-ricochet if the die was fired into the hull)
	RESIST,  ## The die strains against it, pulling back toward the player
	YANK,    ## The beam wins and drags the die into the enemy's hand
	RELEASE, ## The die has landed; the beam fades
}

# Phase lengths in seconds at 1x animation speed. Each pair is (light, heavy),
# lerped by die value: a 1 uses the first, a 6 the second.
const _LOCK_SECONDS: float = 0.6
const _RESIST_SECONDS: Vector2 = Vector2(0.10, 0.32)
const _YANK_SECONDS: Vector2 = Vector2(0.32, 0.68)
const _RELEASE_SECONDS: float = 0.36
const _SLAM_SECONDS: float = 0.12

## How far the die strains away from the ship while resisting, in pixels.
const _RESIST_PULL: Vector2 = Vector2(1.0, 4.0)
const _RESIST_JITTER: Vector2 = Vector2(0.4, 1.4)

## A die closer than this to the ship was fired into it (an Attack Tween) and
## bounces off the hull before the beam catches it — otherwise there'd be
## nothing to pull.
const _RICOCHET_RADIUS: float = 40.0
const _RICOCHET_DISTANCE: Vector2 = Vector2(24.0, 40.0)

## The scale a die rests at in an enemy's queue (see EnemyDiceManager.add).
const _HELD_SCALE: float = 0.75

## Trail length in points at 1x animation speed.
const _TRAIL_POINTS: int = 16

## One beam per die: a second pull on the same die replaces the first.
static var _active: Dictionary[Dice, TractorBeam] = {}

var _die: Dice
var _enemy: Enemy
var _weight: float = 0.0
var _threat: EnemyActionResource.Threat = EnemyActionResource.Threat.NEUTRAL
var _color: Color

var _phase: Phase = Phase.LOCK
var _phase_time: float = 0.0
var _phase_length: float = 0.0

## Where the die was when the beam first touched it, where it bounced to (the
## same place when there was no ricochet), and where it strained to.
var _start_position: Vector2
var _grab_position: Vector2
var _resist_position: Vector2

var _glow: Line2D
var _core: Line2D
var _trail: Line2D


## Pulls `die` into `enemy`'s hand. Call after the die is already in the
## enemy's queue, so its home position is the slot it's headed for.
static func pull(die: Dice, enemy: Enemy) -> void:
	if not is_instance_valid(die) or die.is_queued_for_deletion():
		return
	if not is_instance_valid(enemy) or die.host_queue != enemy.dice_manager:
		return

	release(die)

	var beam: TractorBeam = TractorBeam.new()
	beam._setup(die, enemy)
	enemy.add_child(beam)
	_active[die] = beam


## Ends any beam on `die` right away, leaving the die wherever it is. For code
## that's about to move the die itself, like the enemy using it.
static func release(die: Dice) -> void:
	var beam: TractorBeam = _active.get(die)
	if is_instance_valid(beam):
		beam._finish(false)


func _setup(die: Dice, enemy: Enemy) -> void:
	_die = die
	_enemy = enemy
	_weight = (clampf(die.value, 1, 6) - 1.0) / 5.0
	_threat = _threat_for(die, enemy)
	_color = _color_for(_threat)
	_start_position = die.global_position
	_grab_position = _ricochet_target()

	# Points are written in global space, so the beam doesn't swing around
	# with the ship's bob.
	top_level = true
	# A top-level item hangs off the canvas root rather than the enemy, so it
	# no longer inherits the enemy's z. Match the ship's absolute z, one below,
	# so the beam comes out from underneath it. Ships sit above the main
	# viewer, so that also runs the beam over the tile grid it's pulling from.
	z_as_relative = false
	_follow_enemy_z()

	_glow = _make_line(6.0, Color(_color, 0.35))
	_core = _make_line(2.0, _color.lightened(0.5))
	_trail = _make_line(4.0, Color(Globals.white, 0.5))
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(0.553, 0.957, 0.945, 0.0))
	fade.set_color(1, Color(0.553, 0.957, 0.945, 1.0))
	_trail.gradient = fade


func _ready() -> void:
	_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	_start_phase(Phase.LOCK)
	Events.play_sound.emit(_LOCK_SFX)


func _exit_tree() -> void:
	if _active.get(_die) == self:
		_active.erase(_die)


func _process(delta: float) -> void:
	# Someone else took the die — the enemy died and passed it on, or combat
	# ended. Let go without touching it; its new owner is moving it now.
	if not is_instance_valid(_die) or not is_instance_valid(_enemy) \
	or _die.host_queue != _enemy.dice_manager:
		queue_free()
		return

	# The ships drop behind the cockpit when the player jumps; stay under this one.
	_follow_enemy_z()

	# Another die joining this enemy reflows the queue, which hands every die
	# back to Draggable's homing. Keep hold of this one until it lands.
	if _phase != Phase.RELEASE:
		_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	_phase_time += delta
	var t: float = clampf(_phase_time / _phase_length, 0.0, 1.0)

	match _phase:
		Phase.LOCK:
			_lock(t)
		Phase.RESIST:
			_resist(t)
		Phase.YANK:
			_yank(t)
		Phase.RELEASE:
			_draw_beam(_die.global_position, 1.0 - t)

	if t >= 1.0:
		_advance()


## The beam reaches for the die. A die fired into the hull is flying back off
## it meanwhile, so the beam visibly chases it down.
func _lock(t: float) -> void:
	if _grab_position != _start_position:
		_die.global_position = _start_position.lerp(_grab_position, _ease_out(t))
		_die.rotation = lerpf(0.0, -TAU, _ease_out(t))
	_draw_beam(_enemy.global_position.lerp(_die.global_position, _ease_out(t)), 1.0)


func _resist(t: float) -> void:
	# Strain away from the ship, trembling harder the heavier the die.
	var jitter: float = lerpf(_RESIST_JITTER.x, _RESIST_JITTER.y, _weight)
	_die.global_position = _grab_position.lerp(_resist_position, _ease_out(t)) + Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -jitter, jitter),
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -jitter, jitter)
	)
	_die.scale = Vector2.ONE * lerpf(1.0, 1.1, t)
	_draw_beam(_die.global_position, 1.0 + 0.6 * t)


func _yank(t: float) -> void:
	# Home is read live: it moves if more dice join this enemy mid-flight.
	var home: Vector2 = _die.draggable.home_position
	var eased: float = t * t * t
	_die.global_position = _resist_position.lerp(home, eased)
	_die.scale = Vector2.ONE * lerpf(1.1, _HELD_SCALE, eased)
	_die.rotation = lerpf(0.0, TAU, eased)

	_trail.add_point(_die.global_position)
	# A point lands per frame, so a slower yank needs proportionally more of
	# them for the trail to cover the same distance behind the die.
	var max_points: int = maxi(2, roundi(_TRAIL_POINTS * _time_scale()))
	while _trail.get_point_count() > max_points:
		_trail.remove_point(0)
	_draw_beam(_die.global_position, 1.6)


func _advance() -> void:
	match _phase:
		Phase.LOCK:
			_die.rotation = 0.0
			var away: Vector2 = (_grab_position - _enemy.global_position).normalized()
			_resist_position = _grab_position + away * lerpf(_RESIST_PULL.x, _RESIST_PULL.y, _weight)
			_start_phase(Phase.RESIST)
		Phase.RESIST:
			_start_phase(Phase.YANK)
		Phase.YANK:
			_land()
			_start_phase(Phase.RELEASE)
		Phase.RELEASE:
			_finish(true)


func _start_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	var seconds: float
	match phase:
		Phase.LOCK:
			seconds = _LOCK_SECONDS
		Phase.RESIST:
			seconds = lerpf(_RESIST_SECONDS.x, _RESIST_SECONDS.y, _weight)
		Phase.YANK:
			seconds = lerpf(_YANK_SECONDS.x, _YANK_SECONDS.y, _weight)
		Phase.RELEASE:
			seconds = _RELEASE_SECONDS
	_phase_length = seconds * _time_scale()


## The die arrives: it slams into place, and the enemy reacts to what it just
## got — a flash in the threat color and a sound that says the same thing.
func _land() -> void:
	_die.global_position = _die.draggable.home_position
	_die.rotation = 0.0
	_die.draggable.state = Draggable.DragState.ENEMY_HOLDING
	_trail.clear_points()

	var slam: Tween = _die.create_tween()
	slam.tween_property(_die, "scale", Vector2.ONE * _HELD_SCALE, _SLAM_SECONDS * _time_scale()) \
		.from(Vector2.ONE * _HELD_SCALE * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# A small puff off the die itself as it clicks in. The hit particles are
	# tuned for weapon impacts (a big upward spray), so rein them in to a short
	# burst in every direction.
	var sparks: CPUParticles2D = _HIT_PARTICLES.instantiate()
	sparks.color = _color
	sparks.amount = 4 + roundi(_weight * 6.0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 20.0
	sparks.initial_velocity_max = 45.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.lifetime = 0.6
	_die.add_child(sparks)

	match _threat:
		EnemyActionResource.Threat.DANGEROUS:
			#_enemy.graphics_manager.flash(_color, 0.35)
			Events.play_sound.emit(_DREAD_SFX)
		EnemyActionResource.Threat.NEUTRAL:
			#_enemy.graphics_manager.flash(_color, 0.2)
			Events.play_sound.emit(_DEAD_SFX)
		_:
			Events.play_sound.emit(_DEAD_SFX)

	Events.enemy_armed.emit(_enemy, _die.value)


## Ends the beam. With `landed` false the die is left mid-flight for whoever
## is taking it over.
func _finish(landed: bool) -> void:
	if landed and is_instance_valid(_die) and is_instance_valid(_enemy) \
	and _die.host_queue == _enemy.dice_manager:
		_die.draggable.state = Draggable.DragState.ENEMY_HOLDING
	if _active.get(_die) == self:
		_active.erase(_die)
	queue_free()


func _draw_beam(end: Vector2, intensity: float) -> void:
	var start: Vector2 = _enemy.global_position
	_glow.points = PackedVector2Array([start, end])
	_core.points = PackedVector2Array([start, end])

	# A beam that shimmers reads as energy rather than as a drawn line.
	var shimmer: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.8, 1.2)
	_glow.width = 3.0 * intensity * shimmer
	_glow.default_color.a = 0.35 * clampf(intensity, 0.0, 1.0)
	_core.default_color.a = clampf(intensity, 0.0, 1.0)


func _make_line(width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	return line


## Where the beam catches the die. Normally where it already is; a die sitting
## on the hull ricochets back toward the player's grid first.
func _ricochet_target() -> Vector2:
	var enemy_pos: Vector2 = _enemy.global_position
	if _start_position.distance_to(enemy_pos) >= _RICOCHET_RADIUS:
		return _start_position

	var toward_player: Vector2 = Vector2.DOWN
	if is_instance_valid(Globals.tile_grid):
		toward_player = (Globals.tile_grid.global_position - enemy_pos).normalized()
	var spread: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -0.4, 0.4)
	var distance: float = lerpf(_RICOCHET_DISTANCE.x, _RICOCHET_DISTANCE.y, _weight)
	return _start_position + toward_player.rotated(spread) * distance


## What this die will do once the enemy uses it, following a relay to the ally
## that ends up spending it. The slots are fixed for the turn by the time a
## die is handed over, so this is exactly what the intents promise.
static func _threat_for(die: Dice, enemy: Enemy) -> EnemyActionResource.Threat:
	return enemy.threat_of_face(die.value)


static func _color_for(threat: EnemyActionResource.Threat) -> Color:
	match threat:
		EnemyActionResource.Threat.DANGEROUS:
			return Globals.red
		EnemyActionResource.Threat.NEUTRAL:
			return Globals.purple
		_:
			return Globals.white


func _follow_enemy_z() -> void:
	z_index = _absolute_z(_enemy) - 1


## The z an item actually draws at: its own z_index plus every ancestor's, up
## to the first one that isn't relative.
static func _absolute_z(item: CanvasItem) -> int:
	var z: int = 0
	var node: Node = item
	while node is CanvasItem:
		var canvas_item: CanvasItem = node
		z += canvas_item.z_index
		if not canvas_item.z_as_relative:
			break
		node = canvas_item.get_parent()
	return z


## Multiplier turning a 1x duration into real seconds at the current animation
## speed.
static func _time_scale() -> float:
	return 1.0 / Globals.animation_speed


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
