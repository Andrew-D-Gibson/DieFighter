class_name BackgroundHazardResource
extends Resource
## A recurring environmental event that belongs to a background: the star in a
## solar flare region flares, the storm in an ion region discharges.
##
## The counterpart to BackgroundModifierResource. A modifier is simply true the
## whole time; a hazard counts down and then fires. Hazards fire on a fixed turn
## count that the player can always see, which is the whole point: a flare that
## wipes every shield on the board is only interesting if you knew it was two
## turns out and chose to shield anyway. Random, unannounced damage would just
## be noise.
##
## Hazards live on backgrounds rather than scenarios so the place itself does
## the telegraphing — the region's art shows what is coming before the
## environment monitor's countdown says when.
##
## AUTHORING:
##   1. Create a BackgroundHazardResource.
##   2. Write its effect_chain like any other chain — it runs with the player
##      as actor and no activator die, so avoid die-dependent effects.
##   3. Assign it to a BackgroundResource's 'hazard' field. A background
##      carries a hazard or a global_modifier, never both: the environment
##      monitor has one screen.

@export_category('Info')
@export var hazard_name: String
@export_multiline var description: String

## Art for the environment monitor's screen, beside the countdown, and for the
## info panel it opens. Keep it within 9x9 so it fits next to the digit. Left
## null, the monitor shows its hazard glyph tinted to 'color'.
@export var icon: Texture2D

## Colour used for the monitor's lamp, countdown and the screen flash when it
## fires.
@export var color: Color = Color.WHITE

## When in the round the hazard goes off.
enum Timing {
	## As the player's turn starts, after their hand is rolled. Right for
	## hazards that change the board the player is about to act on.
	YOUR_TURN_STARTS,
	## As the player ends their turn, once the dice they handed over have
	## landed and before any ship uses them. Right for hazards that act on
	## dice: at turn start a fresh hand has nothing committed to disturb.
	YOUR_TURN_ENDS,
}

@export_category('Timing')
@export var timing: Timing = Timing.YOUR_TURN_STARTS

## Trigger points before the first hit, counting the coming one: 1 means the
## next turn start (YOUR_TURN_STARTS) or the end of the current turn
## (YOUR_TURN_ENDS).
@export var turns_until_first: int = 3

## Player turns between triggers after the first.
@export var turns_between: int = 3

@export_category('Behavior')
## What actually happens. Runs on the scenario's engine like any other chain.
@export var effect_chain: EffectChain
