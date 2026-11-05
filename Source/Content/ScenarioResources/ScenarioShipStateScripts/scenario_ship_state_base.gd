class_name ScenarioShipStateBase
extends Resource
## Anything a ship's scenario can lead it to: a ScenarioShipState itself, or a
## node that picks one when it's reached (a weighted roll, a standing branch).


## The state a ship actually enters on reaching this node. [param ship_faction]
## is the ship's own faction, for a node that asks about it.
func resolve(_ship_faction: FactionIdentity) -> ScenarioShipState:
	return null


## Every node one step on from this one, for anything that walks the whole
## graph (a save restore looking a state up, the Scenario Lab, content tests).
func next_states() -> Array[ScenarioShipStateBase]:
	return []
