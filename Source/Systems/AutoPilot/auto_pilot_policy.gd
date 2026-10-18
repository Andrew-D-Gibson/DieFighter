class_name AutoPilotPolicy
extends RefCounted
## How the AutoPilot decides. A policy only ever chooses among the legal moves
## it's handed, and draws any randomness from the rng it's handed, which the
## AutoPilot seeds from the run seed so a replay chooses the same way.


## Picks one of [param moves], which is never empty.
func choose(_moves: Array[AutoPilotMove], _rng: RandomNumberGenerator) -> AutoPilotMove:
	push_error("AutoPilotPolicy.choose() not overridden")
	return null


## Builds the policy named on the command line, or null for an unknown name.
static func named(policy_name: String) -> AutoPilotPolicy:
	match policy_name:
		"random":
			return RandomPolicy.new()
	return null
