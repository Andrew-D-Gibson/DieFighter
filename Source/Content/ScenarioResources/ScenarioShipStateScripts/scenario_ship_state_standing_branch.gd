class_name ScenarioShipStateStandingBranch
extends ScenarioShipStateBase
## Picks a ship's state from what the fleet remembers of the player
## (FactionLedger). Use it wherever a state goes: as a ship's starting state,
## so a shopkeeper greets a player who robbed the last shop differently; or
## as a transition's target, so an outcome depends on the player's past.
##
## The first option whose conditions all hold wins; with none, [member
## otherwise]. It rolls nothing, so a ship opening an encounter on a branch
## lands in the same state on every replay of the same run.

@export var options: Array[ScenarioShipStateStandingOption] = []
## The state when no option's conditions hold: the encounter as it plays for
## a player the fleet has no opinion of.
@export var otherwise: ScenarioShipState


func resolve(ship_faction: FactionIdentity) -> ScenarioShipState:
	return pick(FactionStanding.ledger_now(), ship_faction)


## The state [param ledger] picks, for a ship of [param ship_faction].
func pick(ledger: FactionLedger, ship_faction: FactionIdentity) -> ScenarioShipState:
	for option: ScenarioShipStateStandingOption in options:
		if option and option.state and FactionCondition.all_hold(option.conditions, ledger, ship_faction):
			return option.state
	return otherwise


func next_states() -> Array[ScenarioShipStateBase]:
	var next: Array[ScenarioShipStateBase] = []
	for option: ScenarioShipStateStandingOption in options:
		if option and option.state:
			next.append(option.state)
	if otherwise:
		next.append(otherwise)
	return next
