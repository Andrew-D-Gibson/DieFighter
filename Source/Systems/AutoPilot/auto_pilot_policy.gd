class_name AutoPilotPolicy
extends RefCounted
## How the AutoPilot decides. A policy only ever chooses among the legal moves
## it's handed, and draws any randomness from the rng it's handed, which the
## AutoPilot seeds from the run seed so a replay chooses the same way.


## Picks one of [param moves], which is never empty, or null to wait: nothing
## is worth doing until the board changes (a hand still to come, say).
func choose(_moves: Array[AutoPilotMove], _rng: RandomNumberGenerator) -> AutoPilotMove:
	push_error("AutoPilotPolicy.choose() not overridden")
	return null


## Builds the policy named on the command line, or null for an unknown name:
## random, or one of HeuristicPolicy's styles (smart, aggressive, turtle,
## synergy).
static func named(policy_name: String) -> AutoPilotPolicy:
	if policy_name == "random":
		return RandomPolicy.new()
	var style: HeuristicPolicy.Persona = HeuristicPolicy.persona(policy_name)
	if style:
		return HeuristicPolicy.new(style)
	return null


## Whether the policy may jump away from a fight. A gauntlet run turns this
## off; a policy that never flees can ignore it.
func set_may_flee(_allowed: bool) -> void:
	pass
