@tool
## DelayedEffectData
## The EffectData for UTILITY / DELAY_EFFECTS: steps that play on a later turn
## of the fight instead of now.
##
## AUTHORING:
##   1. Create a DelayedEffectData (not a plain EffectData), category UTILITY,
##      subtype DELAY_EFFECTS.
##   2. Before it in the chain, target the ship it is planted on and build the
##      running amount (SET_TO_DIE_VALUE, MULTIPLY...). Both are captured now.
##   3. `amount` = how many of the player's turns from now it plays (1 = as the
##      next turn starts). `color` tints the countdown badge.
##   4. Put the payload in delayed_effects: flourishes and an ATTRIBUTE_CHANGE
##      that consumes the running amount. The targets are already set to the
##      ship it was planted on. There is no die by then, so no die steps, and
##      no SET_TO_DIE_VALUE: the amount comes in ready-made.
##
## HOW IT WORKS: DelayEffectsHandler plants a DelayedPayload modifier on the
## first target. It shows a countdown badge on that ship, moves to another
## hostile ship if its ship leaves first, and plays the payload through a
## DelayedPayloadEvent when its turn comes.

class_name DelayedEffectData
extends EffectData


## The steps to play when the delay runs out.
@export var delayed_effects: Array[EffectData] = []

## 11x11 icon for the countdown badge on the ship it's planted on.
@export var badge_icon: Texture2D

## Name shown on the badge's info panel ("Time Bomb").
@export var badge_title: String = ""

## What it does when it goes off, for the badge's info panel, in tile-text
## style. "{amount}" is replaced by the captured running amount.
@export_multiline var badge_text: String = ""
