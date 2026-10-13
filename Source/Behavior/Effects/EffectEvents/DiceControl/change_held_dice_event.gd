class_name ChangeHeldDiceEvent
extends EffectEvent
## Re-rolls, or flips the 1s and 6s of, every die the targets are holding.
##
## Unlike REROLL_ALL and FLIP_ONES_AND_SIXES, which reach every die in the
## game, this only touches dice already in the targets' hands. That is what
## makes it matter: aimed at enemies once the player has handed dice over, it
## changes which intent each ship is about to play — after the player has
## committed, but before the ship acts, so they watch it happen.

enum Change { REROLL, FLIP_ONES_AND_SIXES }

var change: Change = Change.REROLL

## Seconds between one die starting to turn over and the next, so a handful
## of dice read as a ripple rather than a single blink.
const _STAGGER_SECONDS: float = 0.12

## How long Dice.reroll_with_tween takes to land its new face.
const _ROLL_SECONDS: float = 0.4


func resolve(engine: ScenarioEngine) -> void:
	var dice: Array[Dice] = []
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		var hand: DiceQueue = target.get("dice_manager") as DiceQueue
		if hand == null:
			continue
		for die: Dice in hand.queue:
			if is_instance_valid(die) and _changes(die):
				dice.append(die)

	if dice.is_empty():
		return

	# Not awaited one by one, so the rolls overlap — as RerollAllDiceEvent does.
	for die: Dice in dice:
		if is_instance_valid(die):
			die.reroll_with_tween(0 if change == Change.REROLL else 7 - die.value)
		await engine.get_tree().create_timer(_STAGGER_SECONDS).timeout
	# The new face is written partway through the roll; let the last one land
	# before anything reads the hands.
	await engine.get_tree().create_timer(_ROLL_SECONDS).timeout
	Events.enemy_held_dice_changed.emit()


func _changes(die: Dice) -> bool:
	return change == Change.REROLL or die.value == 1 or die.value == 6
