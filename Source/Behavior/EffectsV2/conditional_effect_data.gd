## ConditionalEffectData
## A specialised EffectData for branching logic.
## Extends EffectData so it can live alongside regular EffectData
## entries in an EffectChainV2's 'effects' array.
##
## AUTHORING:
##   1. Create a new resource of type ConditionalEffectData (not EffectData).
##   2. Set category = CONDITIONAL and subtype = the desired ConditionalSubtype.
##   3. Populate if_true_effects and/or if_false_effects with EffectData entries
##      (or even nested ConditionalEffectData entries for complex branching).
##
## HOW IT WORKS:
##   ConditionalHandler.apply() evaluates the condition, picks the right branch,
##   then iterates that branch's EffectData array just like EffectChainV2 does.

class_name ConditionalEffectData
extends EffectData


## The EffectData steps to execute when the condition is TRUE.
## Can be empty (effectively: "do something only if condition is true").
@export var if_true_effects: Array[EffectData] = []

## The EffectData steps to execute when the condition is FALSE.
## Can be empty (effectively: "do something only if condition is false").
@export var if_false_effects: Array[EffectData] = []
