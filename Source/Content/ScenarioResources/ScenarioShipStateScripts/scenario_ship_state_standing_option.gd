class_name ScenarioShipStateStandingOption
extends Resource
## One way a ScenarioShipStateStandingBranch can go: the state a ship enters
## when every one of the conditions holds.

## All must hold. A condition with no faction set asks about the ship's own.
@export var conditions: Array[FactionCondition] = []
## A state, not a roll: a branch picks without drawing from any RNG stream.
@export var state: ScenarioShipState
