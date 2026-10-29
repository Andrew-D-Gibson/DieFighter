class_name ChangeHeldDiceEvent
extends EffectEvent
## Re-rolls, or flips the 1s and 6s of, every die the targets are holding,
## or turns each target's highest die to one face (SET_HIGHEST, Cryo Lance).
##
## Unlike REROLL_ALL and FLIP_ONES_AND_SIXES, which reach every die in the
## game, this only touches dice already in the targets' hands. That is what
## makes it matter: aimed at enemies once the player has handed dice over, it
## changes which intent each ship is about to play — after the player has
## committed, but before the ship acts, so they watch it happen.

enum Change { REROLL, FLIP_ONES_AND_SIXES, SET_HIGHEST }

var change: Change = Change.REROLL

## SET_HIGHEST: the face the highest die turns to.
var face: int = 1

## Rings each die as its turn comes. The effect's own colour, so a storm's
## rerolls and a rift's flips each look like their cause.
var color: Color = Color.WHITE

## One die at a time, each landing before the next goes, so the player can
## follow which ship's die became what. Overlapped, a hand of rerolls read as
## one blink. All at animation speed 1.
const _ROLL_HALF_SECONDS: float = 0.35
## A breath between one die landing and the next one going up.
const _GAP_SECONDS: float = 0.15

const _ROLL_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres"
)


## See EffectEvent.changes_die_values().
func changes_die_values() -> bool:
	return true


func resolve(engine: ScenarioEngine) -> void:
	var dice: Array[Dice] = []
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		var hand: DiceQueue = target.get("dice_manager") as DiceQueue
		if hand == null:
			continue
		if change == Change.SET_HIGHEST:
			var highest: Dice = highest_die(hand)
			if highest and highest.value != face:
				dice.append(highest)
			continue
		for die: Dice in hand.queue:
			if is_instance_valid(die) and _changes(die):
				dice.append(die)

	if dice.is_empty():
		return
	for target: Node in targets:
		provoke(target)

	var speed: float = Globals.animation_speed
	for i: int in dice.size():
		var die: Dice = dice[i]
		if i > 0:
			await engine.get_tree().create_timer(_GAP_SECONDS / speed).timeout
			if engine.is_shut_down():
				return
		# A ship can die mid-sequence and take its dice with it.
		if not is_instance_valid(die) or not die.is_inside_tree():
			continue
		_mark(die)
		await die.reroll_with_tween(_new_face(die), _ROLL_HALF_SECONDS / speed)
	Events.enemy_held_dice_changed.emit()


## The "this one" beat as a die goes up: a ring and a blip.
func _mark(die: Dice) -> void:
	Juice.ring(die.get_parent(), die.global_position, color, 12.0, 0.3)
	Events.play_sound.emit(_ROLL_SFX)


## The die [param hand] holds with the highest face, the first of a tie; null
## when it holds none.
static func highest_die(hand: DiceQueue) -> Dice:
	var highest: Dice = null
	for die: Dice in hand.queue:
		if is_instance_valid(die) and (highest == null or die.value > highest.value):
			highest = die
	return highest


## 0 rolls a face nobody can call.
func _new_face(die: Dice) -> int:
	match change:
		Change.REROLL:
			return 0
		Change.SET_HIGHEST:
			return face
	return 7 - die.value


func _changes(die: Dice) -> bool:
	return change == Change.REROLL or die.value == 1 or die.value == 6
