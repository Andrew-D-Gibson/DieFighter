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

## Paid as it says goodbye, in credits only.
@export var payout: RewardResource
