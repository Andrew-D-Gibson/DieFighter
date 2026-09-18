class_name ScenarioHazardResource
extends Resource
## A recurring environmental event attached to a scenario.
##
## Hazards fire on a fixed turn count that the player can always see, which is
## the whole point: a flare that wipes every shield on the board is only
## interesting if you knew it was two turns out and chose to shield anyway.
## Random, unannounced damage would just be noise.
##
## AUTHORING:
##   1. Create a ScenarioHazardResource.
##   2. Write its effect_chain_v2 like any other chain — it runs with the player
##      as actor and no activator die, so avoid die-dependent effects.
##   3. Assign it to a ScenarioResource's 'hazard' field.

@export_category('Info')
@export var hazard_name: String
@export_multiline var description: String
@export var icon: Texture2D

## Colour used for the countdown banner and the screen flash when it fires.
@export var color: Color = Color.WHITE

@export_category('Timing')
## Player turns before the first trigger. 1 means "at the start of turn 2".
@export var turns_until_first: int = 3

## Player turns between triggers after the first.
@export var turns_between: int = 3

@export_category('Behavior')
## What actually happens. Runs on the scenario's engine like any other chain.
@export var effect_chain_v2: EffectChainV2
