class_name Dice
extends Node2D

@export var holographic: bool = false
@export var holographic_shader: ShaderMaterial
@export var default_shader: ShaderMaterial

@export_category('Components')
@export var draggable: Draggable

@export_category('Graphics')
# This array must have 7 values, a blank then 1-6
@export var value_textures: Array[Texture2D]
@export var holographic_textures: Array[Texture2D]
@export var holographic_particles: PackedScene

# Optional: force specific rolls (used by tutorial)
static var forced_rolls: Array[int] = []


@export var value: int = 0:
	set(new_value):
		value = clampi(new_value, 1, 6)
		
		if holographic:
			$Sprite2D.texture = holographic_textures[value]
			var mat: ShaderMaterial = holographic_shader.duplicate()
			mat.set_shader_parameter(
				"seed", RNGManager.randi(RNGManager.Bucket.COSMETIC) % 1000 / 100.0
			)
			$Sprite2D.material = mat
		else:
			$Sprite2D.texture = value_textures[value]
			var mat: ShaderMaterial = default_shader.duplicate()
			mat.set_shader_parameter(
				"time_offset", RNGManager.randf(RNGManager.Bucket.COSMETIC) * 10.0
			)
			$Sprite2D.material = mat
		
var host_queue: DiceQueue

## The ship that was targeted when the player dropped this die on a tile. A
## die that waits its turn in a busy queue still acts on that ship even if the
## player has moved on to another target since; see
## [method TargetingComputer.target_for]. Cleared as the die lands back in a
## ship's hand, so a stale aim never follows it into its next drop.
var aimed_at: Enemy = null

## True while the player has locked this die for the length of a jump, so
## arrival unlocks only what the jump locked and leaves a tutorial's own
## locks alone.
var transit_locked: bool = false

## How far the face jitters while rattling, in pixels; 0 when still. The
## sprite shakes rather than the die, whose position Draggable owns.
var _rattle_strength: float = 0.0
var _rattle_tween: Tween
var _rattle_elapsed: float = 0.0
## Jitter steps per second. Slower than the frame rate, so each jolt lands on
## the pixel grid long enough to read instead of blurring.
const _RATTLE_STEPS_PER_SECOND: float = 30.0
## Degrees of tilt per pixel of rattle.
const _RATTLE_TILT: float = 6.0


func _ready() -> void:
	set_process(false)
	if value == 0:
		value = get_random_die_value()
		
	draggable.drag_ended.connect(_check_for_acceptor)
	
	if holographic:
		var particles: CPUParticles2D = holographic_particles.instantiate()
		particles.position = Vector2(0, -5)
		add_child(particles)
		

static func get_random_die_value() -> int:
	# If tutorial has forced values, use them first
	if forced_rolls.size() > 0:
		return forced_rolls.pop_front()

	# Normal roll
	return RNGManager.randi_range(RNGManager.Bucket.DICE, 1, 6)


func _check_for_acceptor(_draggable: Draggable, end_position: Vector2) -> void:
	var dice_acceptors: Array[Node] = get_tree().get_nodes_in_group('CanAcceptDice')
	for acceptor: CanAcceptDice  in dice_acceptors:
		acceptor.check_die_drop(self, end_position)


func reroll_with_tween(new_value: int = 0) -> void:
	var final_scale: Vector2 = Vector2(1,1)
	# A die between queues (in flight, or never held) rests at full size.
	var holder: Node = host_queue.get_parent() if host_queue else null
	if holder is Enemy or holder is Tile:
		final_scale = Vector2(0.75, 0.75)
	
	var tween_time: float = 0.2
		
	var tween: Tween = get_tree().create_tween().set_parallel()
	tween.tween_property(self, 'rotation_degrees', 180, tween_time).from(0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, 'global_position', global_position + Vector2(0,-8), tween_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, 'scale', Vector2(0.75, 0.75), tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(func() -> void:
		if new_value == 0:
			value = get_random_die_value()
		else:
			value = new_value
		# The new face lands with a snap, so it reads as rolled, not swapped.
		play_pop(0.25)
	)
	tween.tween_property(self, 'rotation_degrees', 180, tween_time).from(0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'global_position', global_position, tween_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, 'scale', final_scale, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished


## A quick squash on the face, for the moments a die matters: landing in a
## tile, flipping under Scramble, going off in front of a ship. The sprite
## bumps rather than the die itself, whose scale the movement tweens own.
func play_pop(strength: float = 0.3) -> void:
	Juice.bump($Sprite2D, strength, 0.3)


## Starts the face shaking, building from still to [param max_strength]
## pixels over [param ramp_time]. Keeps going until settle().
func rattle(max_strength: float, ramp_time: float) -> void:
	if _rattle_tween:
		_rattle_tween.kill()
	_rattle_elapsed = 0.0
	set_process(true)
	_rattle_tween = create_tween()
	_rattle_tween.tween_property(self, "_rattle_strength", max_strength, ramp_time)\
		.from(0.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)


## Stops a rattle dead and lands the face with a pop.
func settle() -> void:
	if not is_processing():
		return
	if _rattle_tween:
		_rattle_tween.kill()
	_rattle_strength = 0.0
	set_process(false)
	$Sprite2D.position = Vector2.ZERO
	$Sprite2D.rotation = 0.0
	play_pop(0.4)


func _process(delta: float) -> void:
	_rattle_elapsed += delta
	if _rattle_elapsed < 1.0 / _RATTLE_STEPS_PER_SECOND:
		return
	_rattle_elapsed = 0.0

	var jitter: float = _rattle_strength
	$Sprite2D.position = Vector2(
		roundf(RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -jitter, jitter)),
		roundf(RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -jitter, jitter))
	)
	$Sprite2D.rotation_degrees = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -jitter, jitter) * _RATTLE_TILT


func _on_tree_exiting() -> void:
	if host_queue:
		host_queue.remove(self)
