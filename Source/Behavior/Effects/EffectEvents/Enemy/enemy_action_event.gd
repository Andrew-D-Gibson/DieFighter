class_name EnemyActionEvent
extends EffectEvent

var enemy: Enemy
var action: EnemyActionResource
var action_popup: PackedScene = preload("uid://b8gjt5a2dcrbn")

## What an action that can't happen any more is played as: the "..." of a
## wasted die, with the die handed back.
const _DO_NOTHING: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")
## Pops up in place of the action's own icon when it can't happen.
const BLOCKED_ICON: Texture2D = preload("res://Assets/Textures/Enemies/IntentIndicator/blocked_info.png")

## How long the die takes to travel out in front of the enemy, by face value:
## a 1 skips over lightly and a 6 drags, so a turn's handovers read by weight
## before the player re-reads a single intent.
const _LIGHT_HANDOVER_SECONDS: float = 0.45
const _HEAVY_HANDOVER_SECONDS: float = 0.95

## Beat between the die arriving and the action firing. Scales the same way, so
## a heavy die also hangs there a moment longer before it goes off.
const _LIGHT_HOLD_SECONDS: float = 0.3
const _HEAVY_HOLD_SECONDS: float = 0.6

## Beat after an action and everything it set off has resolved, before the
## ship's next die goes (Enemy queues it as a WaitEvent). Without it one
## action's damage numbers and callouts were still on screen when the next
## die was already flying, and the player lost track of which did what.
const SETTLE_SECONDS: float = 0.5

## How far the die spins on its way out in front of the ship: one full turn,
## so it lands upright.
const _USE_SPIN: float = TAU

## How many times the full effect chain plays for this single activation.
## Defaults to 1; modifiers may multiply this in on_before_event() (e.g.
## "tiles activated by a 4 activate twice").
var activation_repetitions: int = 1

## How many Feeds carried the die to this ship. 0 when it came from the
## player's hand. See FeedAllyEvent.
var feed_depth: int = 0

## Ships that already acted with this die in a relay chain.
var relay_visited: Array[Node] = []

## Whether the targeting computer lights the intent row for this die's face.
## Off for a shot that isn't on the ship's table (OpeningStrike).
var pulses_intent: bool = true


func resolve(engine: ScenarioEngine) -> void:
	# Also covers a die queued for this turn that the ship gave away when it
	# died before reaching it.
	if not _can_still_act():
		return

	Globals.targeting_computer.target_enemy(enemy)
	# Pulses the matching intent on the targeting computer, so the player can
	# see which row of the intent table this die is about to play. Before the
	# die leaves the hand, so the intent never blinks dim in between.
	if pulses_intent:
		Events.enemy_used_die.emit(enemy, die_value)

	# Remove die from the visual stacking queue
	# It's about to fly in front of the enemy
	TractorBeam.release(activator_die)
	activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	enemy.dice_manager.remove(activator_die)

	# Tween the die to in front of the enemy, weighted by its face value.
	var weight: float = (clampf(die_value, 1, 6) - 1.0) / 5.0
	var tween_time: float = lerpf(_LIGHT_HANDOVER_SECONDS, _HEAVY_HANDOVER_SECONDS, weight)
	var adjusted_tween_time: float = tween_time / Globals.animation_speed
	var tween: Tween = enemy.get_tree().create_tween()
	tween.tween_property(
		activator_die, 
		"global_position", 
		enemy.global_position + Vector2(0,12), 
		adjusted_tween_time
	).set_ease(Tween.EASE_IN_OUT)
	# A heavy die also grows slightly as it arrives, so the value reads even
	# with the screen shaking.
	tween.parallel().tween_property(
		activator_die,
		"scale",
		Vector2.ONE * lerpf(0.8, 1.15, weight),
		adjusted_tween_time
	).set_ease(Tween.EASE_OUT)
	# The die turns over once on the way, a flourish that marks it as the
	# ship's to spend now. Wrapped first, so a die still tilted from a beam
	# that was cut short spins one turn rather than unwinding several, then
	# set back to 0 at the end: a full turn looks upright but isn't 0, and
	# whatever moves the die next would spin it back.
	activator_die.rotation = wrapf(activator_die.rotation, -PI, PI)
	tween.parallel().tween_property(activator_die, "rotation", _USE_SPIN, adjusted_tween_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(activator_die.set_rotation.bind(0.0))
	enemy.spending_die = activator_die as Dice
	enemy.spending_tween = tween
	await tween.finished
	
	# The ship can be freed while its die is in flight — fleeing with dice
	# still queued, or killed by something that resolved in the meantime.
	if not _can_still_act():
		return
		
	await enemy.get_tree().create_timer(
		lerpf(_LIGHT_HOLD_SECONDS, _HEAVY_HOLD_SECONDS, weight) / Globals.animation_speed
	).timeout

	if not _can_still_act():
		return
	
	# The ship rears as it commits and the die kicks, so the action reads as
	# the ship's doing — and as the die the player handed it going off.
	Juice.bump(enemy.graphics_manager.ship_graphics, 0.15, 0.3)
	activator_die.play_pop(0.4)
	Juice.ring(enemy, activator_die.global_position, Globals.white, 14.0, 0.3, 4.0)

	# Make an action indicator popup
	var popup_icon: Texture2D = settle_action()
	var popup_time: float = 0.75
	var action_indicator: Node2D = action_popup.instantiate()
	enemy.add_child(action_indicator)
	action_indicator.sprite.texture = popup_icon
	action_indicator.popup_time = popup_time
	action_indicator.global_position = activator_die.global_position + Vector2(0,12)
		

	# Build the EffectContext for this activation
	var context: EffectContext = EffectContext.new()
	context.actor = enemy
	context.effect_source = enemy
	context.activator_die = activator_die
	context.repetitions = activation_repetitions
	context.enemy_intent_amount = action.intent_amount
	# Null if the bound ship was destroyed (and freed) since the roll: the
	# action then finds no one to act on, as get_outcome() already said.
	context.bound_target = action.bound_ship()
	context.feed_depth = feed_depth
	context.relay_visited = relay_visited

	

	# Play the effect chain — this enqueues more events; the engine's while-loop
	# picks them up automatically because they're appended to the same event_queue.
	if action.effect_chain:
		await action.effect_chain.play(context, engine)


## Settles what the ship actually does with the die, now that it's about to,
## and returns the icon to pop up for it. An action that meant to do
## something but no longer can (its ally destroyed since the slot was rolled,
## a full hangar) plays as Do Nothing, like a jam, and pops a "?" over the
## "...", so the player sees it fizzle rather than wonder where it went.
func settle_action() -> Texture2D:
	if EnemyActionResource.outcome_of(action, enemy) != EnemyActionResource.Outcome.BLOCKED:
		return action.info_texture if action else null
	# A copy, like every rolled action: the preloaded one is shared.
	action = _DO_NOTHING.duplicate(true)
	return BLOCKED_ICON


## A ship killed while its die was in flight is still a valid node through its
## death animation, but it has already handed the die on and must not act.
func _can_still_act() -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(activator_die):
		return false
	return enemy.health.health > 0 and (activator_die as Dice).host_queue == enemy.dice_manager
