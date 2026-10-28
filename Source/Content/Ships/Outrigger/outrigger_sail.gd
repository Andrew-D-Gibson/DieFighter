class_name OutriggerSail
extends Node
## The Outrigger has no Engine Charger tile: its drive runs on a sail. When
## the player ends a turn in a fight, every die still in their hand charges
## the engine by its face, one after another, and then goes to the targeted
## ship like any spent die. Enemy pressure is the same as on any ship; what a
## kept die buys is charge instead of a tile's effect. So each turn asks what
## a die is worth more as: a shot, or a step towards leaving.
##
## The rules at the edges:
## - "In hand" is the hand as End Turn is pressed. Dice a tile was holding come
##   home on the same player_turn_over, but they were played this turn, so they
##   don't count. This node connects to player_turn_over before any grid tile
##   exists (TileGrid spawns it in _ready; tiles arrive with the save or later),
##   so it reads the hand before Tile.release_held_dice() refills it.
## - The sail fills the drive to the jump gate and no further, so keeping dice
##   never redlines the player into bleeding hull (the redline stays the
##   business of ADD_OVERCHARGE tiles). A die the sail has no room for adds
##   nothing and goes straight to the target. Spending charge makes room again.
## - A hologram charges the sail too, and is destroyed when the target gets it,
##   as any hologram handed to a ship is.
## - Only in a fight. Out of one the drive is already full (EngineCharger fills
##   it on arrival and after a win), and there's nothing to flee.
## - Everything goes through the scenario engine: the charge as
##   ChangeEngineChargeEvents (an engine blackout blocks it), the hand-off as
##   GiveDieToTargetEvents (a Scrambled ship flips the die). The last event
##   waits for every tractor beam to land, and EnemyTurn waits for the queue,
##   so no ship acts on a die still in flight.

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
	if hand.is_empty():
		return
	var faces: Array[int] = []
	for die: Dice in hand:
		faces.append(die.value)
	var plan: Array[int] = charge_plan(faces, Globals.player.engine_charge, Globals.player.max_engine_charge)

	var catching: Array[Dice] = []
	for i: int in hand.size():
		if plan[i] > 0:
			catching.append(hand[i])
		else:
			# No room in the sail: it's just a die handed over.
			engine.queue_event(hand_off(hand[i]))

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
	engine.queue_event(SailSettleEvent.new())
	sail_set.emit(catching)


## [param die] going to the ship it would have been dropped against, through
## the same event every tile's hand-off uses.
static func hand_off(die: Dice) -> GiveDieToTargetEvent:
	var give: GiveDieToTargetEvent = GiveDieToTargetEvent.new()
	give.actor = Globals.player
	give.effect_source = Globals.player
	give.activator_die = die
	give.die_value = die.value
	var target: Enemy = Globals.targeting_computer.target_for(die) \
			if is_instance_valid(Globals.targeting_computer) else null
	if is_instance_valid(target):
		give.targets = [target]
	return give


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
