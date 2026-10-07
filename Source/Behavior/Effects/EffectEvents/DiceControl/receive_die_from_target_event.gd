class_name ReceiveDieFromTargetEvent
extends EffectEvent
## Moves the die the first target took most recently into the actor's queue.
##
## The newest die rather than a random one, so the player can predict what a
## Repo Beam will pull: the die they just handed over. A die coming back to the
## player is rerolled, as every die returning to the hand is.

const _RECLAIM_COLOR: Color = Color(0.553, 0.957, 0.945)


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty() or not is_instance_valid(targets[0]):
		return
	var source: DiceQueue = targets[0].get("dice_manager") as DiceQueue
	if source == null or source.queue.is_empty():
		return
	if not is_instance_valid(actor):
		return
	var holder: DiceQueue = actor.get("dice_manager") as DiceQueue
	if holder == null:
		return

	var die: Dice = source.queue[-1]
	var reroll: bool = actor is Player
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	holder.add(die, not reroll, true)

	# The die itself says "this one's yours again" as it breaks free; the beam
	# that pulled it is authored on whatever tile fired the effect.
	Juice.die_flare(die, _RECLAIM_COLOR)
