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

## Where a 6's glint catches, from the die's centre at full size: its upper
## right corner.
const _GLINT_OFFSET: Vector2 = Vector2(4.0, -4.0)


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

## Where this die stands with the player. Only a DELIVERED die is theirs to
## play: one ON_OFFER (a shop shelf, salvage) is the offer's to place, and one
## ARRIVING has been taken from an offer and is still flying into the hand.
enum Delivery { DELIVERED, ON_OFFER, ARRIVING }
var delivery: Delivery = Delivery.DELIVERED

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

## The scale a die rests at while a ship or a tile holds it.
const HELD_SCALE: float = 0.75

## A purely cosmetic tween on this die's scale or angle that nothing awaits
## (a landing slam). Tracked so a new holder can cut it off: left running, it
## would go on writing the old holder's scale after the handover.
var _flourish_tween: Tween

## A destroyed ship's dice going home to the player hang at the wreck while it
## blows apart, then cross at a pace the eye can follow. They used to be
## yanked across in the same instant as the explosion, and the player couldn't
## tell who had got what. Game time, so the kill's hitstop holds them too.
## (Dice going to another ship hang there under its tractor beam instead.)
const _DEATH_LINGER_SECONDS: float = 0.55
const _DEATH_CROSSING_SECONDS: float = 0.5

## Holds the die at a destroyed ship's wreck until it leaves: the wait for its
## turn in the volley of beams, or the linger and crossing home. See
## hand_off_after_death().
var _handoff_tween: Tween
## Where the crossing to the new holder began.
var _handoff_from: Vector2


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
	# A player can't pick up a die still crossing from a wreck, but the
	# AutoPilot drops dice by code; wherever it lands now owns its movement.
	cancel_handoff()
	# A die let go over a tile straight off a shop shelf used to fire that
	# tile as well as being bought, and could start a fight with the keeper.
	# Until it has landed in the hand, where it's let go is the offer's call.
	if not is_playable():
		return
	var dice_acceptors: Array[Node] = get_tree().get_nodes_in_group('CanAcceptDice')
	for acceptor: CanAcceptDice  in dice_acceptors:
		acceptor.check_die_drop(self, end_position)


## Marks this die as something an offer is showing, not yet the player's:
## letting go of it over a tile buys or claims it rather than playing it.
func put_on_offer() -> void:
	delivery = Delivery.ON_OFFER


## Called as the player takes this die from an offer, once it's in their hand
## queue. Until it settles there on screen it can't be picked up or played:
## players kept grabbing a bought die mid-flight and dropping it on a tile.
## Arrival ends it rather than a timer, since the hand's slot can shift under
## the die on the way.
func begin_arrival() -> void:
	delivery = Delivery.ARRIVING
	draggable.out_of_reach = true
	if not draggable.reached_new_home.is_connected(_on_arrived):
		draggable.reached_new_home.connect(_on_arrived, CONNECT_ONE_SHOT)
	draggable.announce_next_arrival()


func _on_arrived() -> void:
	delivery = Delivery.DELIVERED
	draggable.out_of_reach = false


## Whether this die is the player's to play: not on an offer, nor still on
## its way into the hand from one.
func is_playable() -> bool:
	return delivery == Delivery.DELIVERED


## Flips the die over to [param new_value] (0 rolls a random face), taking
## [param tween_time] seconds at 1x for each half of the turn, shortened by the
## animation-speed option.
func reroll_with_tween(new_value: int = 0, tween_time: float = 0.2) -> void:
	var final_scale: Vector2 = rest_scale()
	tween_time /= Globals.animation_speed

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
	# The second half carries on round to a full turn. Restarting it from 0
	# left every rerolled die resting upside down at 180°, and a ship then
	# spun it back upright as it used it.
	tween.tween_property(self, 'rotation_degrees', 360, tween_time).from(180).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'global_position', global_position, tween_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, 'scale', final_scale, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Square up for whoever holds it once it lands, which needn't be who held
	# it when the roll began: a ship can die mid-roll and pass the die on.
	tween.chain().tween_callback(reset_visual_state)
	tween.tween_callback(func() -> void:
		if value == 6:
			play_six_glint()
	)

	await tween.finished


## Light catches the corner of a die that just landed on a 6: the best face
## is worth a second look before it's spent.
func play_six_glint() -> void:
	var corner: Vector2 = global_position + _GLINT_OFFSET * scale
	Juice.glint(self, corner, Globals.yellow, 5.0, 0.4)
	Juice.sparkle(self, corner, Globals.yellow, 4, 20.0)


## The scale this die rests at with its current holder: shrunk while a ship or
## a tile holds it, full size in the player's hand or between queues.
func rest_scale() -> Vector2:
	var holder: Node = host_queue.get_parent() if host_queue else null
	if host_queue is EnemyDiceManager or holder is Enemy or holder is Tile:
		return Vector2.ONE * HELD_SCALE
	return Vector2.ONE


## Squares the die up for its current holder: upright, at that holder's rest
## scale, with any cosmetic flourish cut off. The one place a die's transform is
## reset when it changes hands, so a die can't arrive tilted or at the size its
## last holder gave it, whatever was animating it on the way out.
##
## A die being dragged is left alone; the drag owns its scale and wobble, and
## the drop squares it up.
func reset_visual_state() -> void:
	if draggable and draggable.state == Draggable.DragState.DRAGGING:
		return
	if _flourish_tween and _flourish_tween.is_valid():
		_flourish_tween.kill()
	_flourish_tween = null
	rotation = 0.0
	scale = rest_scale()


## A new tween bound to this die for a cosmetic scale or angle flourish that
## nothing awaits, replacing the last one. reset_visual_state() kills it, so a
## handover can't be overwritten by the flourish finishing afterwards.
func create_flourish_tween() -> Tween:
	if _flourish_tween and _flourish_tween.is_valid():
		_flourish_tween.kill()
	_flourish_tween = create_tween()
	return _flourish_tween


## How long a destroyed ship's dice take to cross home to the player, from
## the moment it dies: the linger at the wreck plus the crossing. The engine
## holds the next chain at least this long after any death; dice that go to
## another ship extend that hold to their own landing (EnemyDiceManager).
static func death_handoff_seconds() -> float:
	return (_DEATH_LINGER_SECONDS + _DEATH_CROSSING_SECONDS) / Globals.animation_speed


## Called once a destroyed ship has handed this die on, and returns how many
## game seconds it will take to land. [param delay] is its place in the
## wreck's volley: a hold of several leaves a beat apart rather than as one.
##
## Bound for another ship, it waits out [param delay] where it is, then that
## ship's tractor beam takes it, so every die reads as taken by whoever took
## it. Bound for the player, who has no beam, it hangs while the wreck goes
## up and then crosses home. The holder is read every frame of the crossing
## (Draggable.home_position), since the survivors close the gap the dead ship
## left at the same moment. Until it leaves, its Draggable leaves it alone,
## and it can't be picked up.
func hand_off_after_death(delay: float = 0.0) -> float:
	cancel_handoff()
	var speed: float = Globals.animation_speed
	var holder: Node = host_queue.get_parent() if host_queue else null
	if holder is Enemy:
		var heir: Enemy = holder
		if delay <= 0.0:
			TractorBeam.pull(self, heir)
		else:
			draggable.held_by_code = true
			_handoff_tween = create_tween()
			_handoff_tween.tween_interval(delay / speed)
			_handoff_tween.tween_callback(_beam_to.bind(heir))
		return delay / speed + TractorBeam.seconds_to_land(value)

	draggable.held_by_code = true
	_handoff_tween = create_tween()
	_handoff_tween.tween_interval((_DEATH_LINGER_SECONDS + delay) / speed)
	_handoff_tween.tween_callback(func() -> void: _handoff_from = global_position)
	_handoff_tween.tween_method(_cross_to_holder, 0.0, 1.0, _DEATH_CROSSING_SECONDS / speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_handoff_tween.tween_callback(_end_handoff)
	return (_DEATH_LINGER_SECONDS + delay + _DEATH_CROSSING_SECONDS) / speed


## The die's turn in a wreck's volley: its new holder's beam takes over. A
## holder that has since lost it (spent, or died and passed it on) has no
## claim, and TractorBeam.pull() ignores it.
func _beam_to(heir: Enemy) -> void:
	_end_handoff()
	if is_instance_valid(heir):
		TractorBeam.pull(self, heir)


## Cuts a death hand-off short and gives the die back to its Draggable: for
## code that takes the die somewhere else first (a ship spending it).
func cancel_handoff() -> void:
	if _handoff_tween and _handoff_tween.is_valid():
		_handoff_tween.kill()
	_end_handoff()


## Whether the die is still waiting at a destroyed ship's wreck, or crossing
## home from it. A die a beam has taken over is the beam's (TractorBeam).
func is_handing_off() -> bool:
	return _handoff_tween != null


func _cross_to_holder(progress: float) -> void:
	global_position = _handoff_from.lerp(draggable.home_position, progress)


func _end_handoff() -> void:
	_handoff_tween = null
	draggable.held_by_code = false


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
