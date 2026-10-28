class_name OutriggerSail
extends Node
## The Outrigger has no Engine Charger tile: its drive runs on a sail. When
## the player ends a turn in a fight, every die still in their hand charges
## the engine by its face, one after another. So each turn asks what a die is
## worth more as: a shot, or a step towards leaving (and a die the enemy never
## gets to use).
##
## The rules at the edges:
## - "In hand" is the hand as End Turn is pressed. Dice a tile was holding come
##   home on the same player_turn_over, but they were played this turn, so they
##   don't count. This node connects to player_turn_over before any grid tile
##   exists (TileGrid spawns it in _ready; tiles arrive with the save or later),
##   so it reads the hand before Tile.release_held_dice() refills it.
## - Real dice stay in hand, and are rerolled next turn as always. Holograms
##   are borrowed light: they burn into the sail, charging it and fizzling.
## - The sail fills the drive to the jump gate and no further, so a hand the
##   player couldn't use never redlines them into bleeding hull. The redline
##   stays the business of ADD_OVERCHARGE tiles; a drive already past the gate
##   takes nothing from the sail. A die the sail has no room for stays put.
## - Only in a fight. Out of one the drive is already full (EngineCharger fills
##   it on arrival and after a win), and there's nothing to flee.
## - Charging goes through the scenario engine as ChangeEngineChargeEvents, so
##   anything that blocks or caps charge (an engine blackout) does it here too,
##   and it all lands before any ship acts (EnemyTurn waits for the queue).

## Raised once a turn's catch has been queued, with the dice taking part.
signal sail_set(dice: Array[Dice])


func _ready() -> void:
	Events.player_turn_over.connect(_on_player_turn_over)


func _on_player_turn_over() -> void:
	if not is_sail_up():
		return
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null or not is_instance_valid(Globals.player):
		return

	var hand: Array[Dice] = banked_dice()
	var faces: Array[int] = []
	for die: Dice in hand:
		faces.append(die.value)
	var plan: Array[int] = charge_plan(faces, Globals.player.engine_charge, Globals.player.max_engine_charge)

	var catching: Array[Dice] = []
	for i: int in hand.size():
		if plan[i] > 0:
			catching.append(hand[i])
	if catching.is_empty():
		return

	for i: int in catching.size():
		var catch: SailCatchEvent = SailCatchEvent.new()
		catch.actor = Globals.player
		catch.effect_source = Globals.player
		catch.activator_die = catching[i]
		catch.die_value = catching[i].value
		catch.amount = catching[i].value
		catch.order = i
		catch.last = i == catching.size() - 1
		engine.queue_event(catch)
	sail_set.emit(catching)


## Whether ending a turn right now would charge the drive.
static func is_sail_up() -> bool:
	return Globals.state_manager != null \
		and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT


## The dice the sail would catch: the hand, in order, skipping any already on
## their way out.
static func banked_dice() -> Array[Dice]:
	var hand: Array[Dice] = []
	if not is_instance_valid(Globals.player):
		return hand
	for die: Dice in Globals.player.dice_manager.queue:
		if is_instance_valid(die) and not die.is_queued_for_deletion():
			hand.append(die)
	return hand


## How much each of [param faces] adds, in order, to a drive at
## [param charge] whose gate is [param gate]: its face, until the gate is
## reached. Past that, nothing.
static func charge_plan(faces: Array[int], charge: int, gate: int) -> Array[int]:
	var plan: Array[int] = []
	var room: int = maxi(0, gate - charge)
	for face: int in faces:
		var step: int = mini(face, room)
		plan.append(step)
		room -= step
	return plan


## What ending the turn now would leave the drive at: the gauge's preview.
static func projected_charge() -> int:
	if not is_instance_valid(Globals.player):
		return 0
	var charge: int = Globals.player.engine_charge
	if not is_sail_up():
		return charge
	var faces: Array[int] = []
	for die: Dice in banked_dice():
		faces.append(die.value)
	var total: int = 0
	for step: int in charge_plan(faces, charge, Globals.player.max_engine_charge):
		total += step
	return charge + total
