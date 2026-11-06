class_name EscortResource
extends Resource
## A ship that rides along with the player after an encounter instead of
## staying behind (the Mayday's grateful runner): set on the ScenarioShipState
## that signs it on (ScenarioShipState.escort). See EscortKeeper.
##
## It joins at the next arrival, sits in its own slot outside the formation
## (EnemyManager.ESCORT_SLOT), and fights as one of the player's side through
## [member fights] won fights. At the arrival after the last of them it says
## goodbye, pays [member payout] and jumps away. If it dies on the way the
## payout is lost, nothing more: the player tried.
##
## One that [member rides_to_gate] stays to the end of the sector instead, and
## takes the slot from another escort still riding (which says its goodbye
## early, paid in full): it's the one the player can't get back.

## The hull that flies along. Its table must hold a Raid in every pool: it is
## on the player's side in every fight it joins (EnemyActionSituation.owes_hand_off).
@export var ship_resource: EnemyResource

## Its state while riding along: on the player's side, deaf to everything
## but being shot at itself (PLAYER_ATTACKED_SELF), since it hears the
## broadcast events of every encounter it passes through.
@export var escort_state: ScenarioShipState

## Its state for the goodbye: the thank-you line, and a chain that ends in a
## FLEE so it jumps away.
@export var farewell_state: ScenarioShipState

## How many won fights it rides through before it says goodbye.
@export_range(1, 5) var fights: int = 2

## Paid as it says goodbye: credits, or a pick for an escort that rides to
## the gate (the Outrigger courier's spare parts).
@export var payout: RewardResource
## Where a payout with picks floats, in world pixels, clear of the escort's
## slot and the hull gauge under it. Zero floats it at the escort, which is
## fine for credits alone (they pay out and go).
@export var payout_position: Vector2 = Vector2.ZERO

@export_category("To the Gate")
## Rides until the sector's gate falls instead of for [member fights] won
## fights, and says goodbye right there, before the player can jump through
## (the Outrigger courier). [member fights] is ignored. A goodbye at the gate
## holds the jump until it's over.
@export var rides_to_gate: bool = false
## Lines said before the farewell state's, one state each, in order: each is
## shown and held until it has run its course. Their own states, so each
## line is translated and linted like any other.
@export var farewell_lead_in: Array[ScenarioShipState] = []
## The ship (ShipResource.id) the player earns when this escort is delivered:
## recorded the moment the job is done, then shown on the ship-unlock card
## once the escort has gone. Empty for an escort that only pays. An id
## rather than the ShipResource, which offers this escort's encounter
## (ShipResource.unlock_scenario): the two can't reference each other.
@export var unlocks_ship: StringName = &""
