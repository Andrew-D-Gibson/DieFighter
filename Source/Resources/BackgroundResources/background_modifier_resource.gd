class_name BackgroundModifierResource
extends Resource
## A permanent rule that applies for as long as the player sits in a given
## background.
##
## Unlike a ScenarioHazardResource, which counts down and then fires, a
## background modifier never triggers — it is simply true the whole time. That
## makes the background itself a strategic choice rather than scenery: taking
## the route through the blue nebula means planning a fight without shields.
##
## The rule is registered on the scenario's engine as an ordinary Modifier, so
## it flows through the same before/after pipeline as tile and enemy effects
## and composes with them for free.
##
## AUTHORING:
##   1. Create a BackgroundModifierResource.
##   2. Pick an 'effect', then write the name/description the banner shows.
##   3. Assign it to a BackgroundResource's 'global_modifier' field.
##
## To add a new rule, write a Modifier subclass under
## Source/Behavior/Modifiers/BackgroundModifiers/, add an Effect entry, and
## return it from create_modifier().

## Which rule this background enforces.
enum Effect {
	## No ship can raise shields.
	SHIELD_BLACKOUT,
	## Every point of damage is doubled, whoever deals it.
	DOUBLE_DAMAGE,
	## No ship can repair hull.
	REPAIR_BLACKOUT,
	## The player's engine cannot accumulate charge.
	ENGINE_BLACKOUT,
	## Dice cannot be rerolled.
	REROLL_BLACKOUT,
	## Tiles activate once each, however many repetitions they would get.
	NO_REPETITION,
	## No effect may move a number by more than 'amount_cap'.
	AMOUNT_CAP,
}

@export_category('Info')
## Shown on the banner in caps. Keep it short — it reads as a place name.
@export var modifier_name: String

## One line of bbcode explaining the rule, in the same '[color=red]' shorthand
## the rest of the game's text uses.
@export_multiline var description: String

## Tint for the banner. Should match the background's own palette.
@export var color: Color = Color.WHITE

@export_category('Behavior')
@export var effect: Effect = Effect.SHIELD_BLACKOUT

## Only read by Effect.AMOUNT_CAP: the largest amount any single effect may
## move, in either direction.
@export var amount_cap: int = 3


## Builds a fresh Modifier for the rule. Called once per scenario, because
## modifiers are registered on that scenario's engine and die with it.
func create_modifier() -> Modifier:
	var mod: Modifier
	match effect:
		Effect.SHIELD_BLACKOUT:
			mod = ShieldBlackoutModifier.new()
		Effect.DOUBLE_DAMAGE:
			mod = DoubleDamageModifier.new()
		Effect.REPAIR_BLACKOUT:
			mod = RepairBlackoutModifier.new()
		Effect.ENGINE_BLACKOUT:
			mod = EngineBlackoutModifier.new()
		Effect.REROLL_BLACKOUT:
			mod = RerollBlackoutModifier.new()
		Effect.NO_REPETITION:
			mod = NoRepetitionModifier.new()
		Effect.AMOUNT_CAP:
			mod = AmountCapModifier.new(amount_cap)
		_:
			push_error("BackgroundModifierResource: unhandled effect %d" % effect)
			return null

	# The banner and the rule should never be able to disagree about what this
	# background is called.
	if not modifier_name.is_empty():
		mod.modifier_name = modifier_name
	return mod
