class_name FactionDeed
extends Resource
## Something the player did that a faction will remember for the rest of the
## run. A ScenarioShipState lists the deeds its outcome stands for (the shop
## the player opened fire on, the Picket they relieved), and FactionStanding
## records them as the ship enters that state. See FactionLedger.

## Whose standing moves. Null means the faction of the ship entering the state
## (its EnemyResource.faction), which is right almost always: the shopkeeper
## who was robbed is the Caravan who remembers it. Set it when the deed
## touches someone else: shooting a Conscriptor to let a Pilgrim go home is
## felt by the Inbound too.
@export var faction: FactionIdentity
## How far the deed moves that faction's standing. Kept small: FactionLedger
## reads standing in bands a couple of points wide.
@export_range(-10, 10) var standing: int = 0
## The deed's name, counted in the ledger for content to ask about later
## (FactionCondition.Test.DEED_DONE). Name it after what happened, faction
## first: "caravan_shop_attacked", "rearguard_spared". Empty counts nothing.
@export var deed: StringName = &""


## The faction this deed is felt by, given the ship whose state recorded it.
func faction_for(ship_faction: FactionIdentity) -> FactionIdentity:
	return faction if faction else ship_faction
