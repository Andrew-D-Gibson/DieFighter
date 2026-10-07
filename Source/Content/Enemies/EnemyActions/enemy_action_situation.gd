class_name EnemyActionSituation
extends RefCounted
## What a ship can see of the board when it rolls its six intent slots.
##
## Built once per roll, so every gate and weight reads the same snapshot, and a
## test can describe a board without standing one up.

## The ship rolling. May be null in a test that only cares about the gates.
var ship: Enemy = null

## Whether the player can read the table being rolled. See
## GameStateManager.enemy_intents_visible().
var intents_visible: bool = true


static func for_ship(rolling_ship: Enemy) -> EnemyActionSituation:
	var situation := EnemyActionSituation.new()
	situation.ship = rolling_ship
	if Globals.state_manager:
		situation.intents_visible = Globals.state_manager.enemy_intents_visible()
	return situation
