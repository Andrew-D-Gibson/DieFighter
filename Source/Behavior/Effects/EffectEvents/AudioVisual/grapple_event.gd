class_name GrappleEvent
extends EffectEvent
## The activator die sets off home to the player's hand, and a claw on a
## tether from the actor catches it partway and reels it back (Seize).
##
## A die simply staying with the ship never told the player it had been
## theirs to get back. Letting it start home first, then snatching it, shows
## both halves: it was coming back to you, and it was taken.
##
## Holds the chain until the die is back where it started, in front of the
## ship, so what follows (the callout, the ship keeping the die) lands on the
## theft. JuiceGrapple runs the grab; the claw winds back in on its own after.

## How far toward the hand the die gets before the claw has it.
const _CATCH_SHARE: float = 0.45
## The jolt as the claw bites.
const _CLAMP_HITSTOP_MS: int = 40
## Above the dice (z 10) under the same parent, so the prongs close over it.
const _CLAW_Z_INDEX: int = 15

var color: Color = Color.WHITE
## Plays as the claw clamps shut.
var clamp_sfx: SoundEffectResource


## A duration and a colour, not an output: an Amplifier leaves it alone.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die) or activator_die is not Dice:
		return
	if not is_instance_valid(actor) or actor is not Node2D or not actor.is_inside_tree():
		return
	var die: Dice = activator_die as Dice
	var start: Vector2 = die.global_position

	var claw: JuiceGrapple = JuiceGrapple.new()
	claw.origin_node = actor as Node2D
	claw.die = die
	claw.start = start
	claw.catch_point = start.lerp(_hand_point(start), _CATCH_SHARE)
	claw.color = color
	claw.caught.connect(_clamp.bind(die))
	JuicePixelated.spawn(die.get_parent(), claw, _CLAW_Z_INDEX)

	# A timer rather than the claw's own signal: a claw freed mid-grab (its
	# ship gone) would never send it, and the chain would wait forever. Both
	# run on game time, so they finish together.
	await actor.get_tree().create_timer(JuiceGrapple.duration(), false).timeout


## Where the die would have gone: the player's hand, or straight down when
## there's no hand to aim at.
func _hand_point(from: Vector2) -> Vector2:
	if is_instance_valid(Globals.player) and Globals.player.is_inside_tree():
		return Globals.player.dice_manager.global_position
	return from + Vector2(0.0, 80.0)


func _clamp(die: Dice) -> void:
	if not is_instance_valid(die):
		return
	if clamp_sfx:
		Events.play_sound.emit(clamp_sfx)
	die.play_pop(0.3)
	Juice.sparkle(die, die.global_position, color, 6, 30.0)
	TimeDirector.hitstop(roundi(_CLAMP_HITSTOP_MS / Globals.animation_speed))
