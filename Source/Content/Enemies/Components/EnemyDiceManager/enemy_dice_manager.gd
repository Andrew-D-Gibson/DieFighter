class_name EnemyDiceManager
extends DiceQueue

## A die is about to land with this ship, by any route. Fires before it joins
## the queue, so a listener can change its value and everything that reacts to
## the arrival (the targeting computer's intent highlight) sees the final face.
signal die_arriving(die: Dice)

## Why a ship is giving its dice away, which decides who may take them and
## how they get there. See give_away_dice().
enum Departure {
	STAYING,    ## Handing them out mid-fight (GIVE_DIE_AWAY)
	FLEEING,    ## Leaving the board under its own power
	DESTROYED,  ## Blown up: the dice leave the wreck in a volley
}

## How far apart a destroyed ship's dice leave its wreck, so a full hold
## reads as a volley of beams, one per die, rather than one die or a clump.
const DEATH_VOLLEY_STAGGER_SECONDS: float = 0.07

## How many dice this ship has sent off since it was destroyed: each one's
## place in the volley.
var _dice_sent_from_wreck: int = 0


func _ready() -> void:
	# Whatever was moving the die on its way here (a dying ship's death
	# sequence, a tractor beam cut short, a reroll) may have left it tilted or
	# at another holder's size.
	die_received.connect(func(die: Dice) -> void: die.reset_visual_state())
	die_added.connect(update_dice_locations)
	die_removed.connect(update_dice_locations)


func add(die: Dice, preserve_value: bool = true, destroy_holographic: bool = true) -> void:
	# A ship putting back a die it already held (Charge Bore keeping its shot)
	# hasn't received anything new. A hologram is destroyed rather than queued,
	# and a die that will be rerolled on arrival keeps no face to change.
	var arriving: bool = die.host_queue != self \
		and not (die.holographic and destroy_holographic) \
		and preserve_value
	if arriving:
		die_arriving.emit(die)
	super(die, preserve_value, destroy_holographic)

		
func remove(die: Dice) -> void:
	super(die)
	die.scale = Vector2(1.0, 1.0)
	
	
func update_dice_locations() -> void:
	var dice_spacing: int = 10
	for i: int in range(len(queue)):
		queue[i].draggable.state = Draggable.DragState.ENEMY_HOLDING
		queue[i].draggable.home_position = global_position + Vector2(
			floor(i / 5.0) * dice_spacing, 
			-(i % 5) * dice_spacing
		)


## Gives every die away, each to a random heir (heirs_for_dice()), or to the
## player when there is none. Values are kept either way, so killing an enemy
## returns exactly the die it held.
##
## [param in_hand] is a die this ship took out of the queue to spend (an
## EnemyActionEvent's activator, floating in front of the ship). It goes too,
## unless the chain already handed it on somewhere else.
##
## A [param departure] of DESTROYED sends the dice off the wreck in a quick
## volley, each on its own tractor beam from its new holder
## (Dice.hand_off_after_death()). Their new holders take them at once either
## way: only the trip waits.
func give_away_dice(in_hand: Node = null, departure: Departure = Departure.STAYING) -> void:
	var heirs: Array[Enemy] = heirs_for_dice(departure != Departure.STAYING)
	var after_death: bool = departure == Departure.DESTROYED

	var dice: Array[Dice] = queue.duplicate()
	if is_instance_valid(in_hand) and in_hand is Dice and not in_hand.is_queued_for_deletion() \
			and (in_hand as Dice).host_queue == self and in_hand not in dice:
		dice.append(in_hand as Dice)

	for i: int in range(len(dice)-1, -1, -1):
		_pass_on(dice[i], heirs, after_death)


## Sends on a die that was on its way to this ship when it was destroyed (the
## shot that killed it, handed over a moment after the death): to the same
## heirs as the rest of its dice, as the next beam in the same volley.
func pass_on_after_death(die: Dice) -> void:
	_pass_on(die, heirs_for_dice(true), true)


## The ships that may take this ship's dice: every other ship still on the
## board, provided the fight goes on. If no hostile ship is left, the fight is
## over, and the dice go home to the player instead: a ship that isn't hostile
## (the civilian a dead pirate was preying on) would only send them back once
## combat_finished fires, and the dice would set off toward it and then turn
## round. This ship counts toward the fight unless it is [param leaving] (dead
## or fleeing): a ship handing dice out mid-fight is still in it.
##
## Read it after the scenario has reacted to this ship leaving (Enemy._on_death
## and FleeEvent announce enemy_left first): the loss can end the fight (the
## last pirate down) or start one (an escort turning on the player).
func heirs_for_dice(leaving: bool) -> Array[Enemy]:
	var heirs: Array[Enemy] = []
	var fight_goes_on: bool = false
	for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
		# A ship giving its dice away must not hand them to itself.
		var is_self: bool = enemy.dice_manager == self
		if enemy.is_hostile() and not (is_self and leaving):
			fight_goes_on = true
		# "You" inherits nothing: a die only reaches it aimed (FateSelf).
		if not is_self and not FateSelf.is_self(enemy):
			heirs.append(enemy)
	if not fight_goes_on:
		heirs.clear()
	return heirs


func _pass_on(die: Dice, heirs: Array[Enemy], after_death: bool) -> void:
	TractorBeam.release(die)
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	if heirs.is_empty():
		Globals.player.dice_manager.add(die, true, true)
	else:
		var heir: Enemy = RNGManager.pick_random(RNGManager.Bucket.TARGETING, heirs)
		heir.dice_manager.add(die, true, true)

	# A hologram is destroyed on arrival rather than handed on.
	if not after_death or die.is_queued_for_deletion():
		return
	var landing: float = die.hand_off_after_death(_dice_sent_from_wreck * DEATH_VOLLEY_STAGGER_SECONDS)
	_dice_sent_from_wreck += 1
	# Nothing else starts until the last die has landed, or the next action
	# plays out while the player is still watching to see who got what. The
	# engine already holds for the crossing home on enemy_destroyed; a beam
	# can take longer.
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		engine.hold_next_chain(landing + ScenarioEngine.DEATH_BEAT_PADDING_SECONDS / Globals.animation_speed)


## Hands every die straight back to the player with the face it holds: the
## player is reclaiming their own die, not rolling a new one.
func return_dice_to_player() -> void:
	for i: int in range(len(queue)-1, -1, -1):
		var die: Dice = queue[i]
		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		Globals.player.dice_manager.add(die, true, true)
