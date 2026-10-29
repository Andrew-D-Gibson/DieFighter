class_name EnemyDiceManager
extends DiceQueue

## A die is about to land with this ship, by any route. Fires before it joins
## the queue, so a listener can change its value and everything that reacts to
## the arrival (the targeting computer's intent highlight) sees the final face.
signal die_arriving(die: Dice)


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


## Give dice away to other enemies or the player randomly. Values are kept
## either way, so killing an enemy returns exactly the die it held.
##
## [param in_hand] is a die this ship took out of the queue to spend (an
## EnemyActionEvent's activator, floating in front of the ship). It goes too,
## unless the chain already handed it on somewhere else.
##
## With [param after_death], the dice hang at the wreck before they cross
## (Dice.hand_off_after_death()). Their new holders take them at once either
## way: only the trip waits.
func give_away_dice(in_hand: Node = null, after_death: bool = false) -> void:
	# A fleeing ship is still alive while it empties its hold, and must not
	# hand its dice to itself: they'd leave with it.
	var recipients: Array[Enemy] = []
	for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
		if enemy.dice_manager != self:
			recipients.append(enemy)

	var dice: Array[Dice] = queue.duplicate()
	if is_instance_valid(in_hand) and in_hand is Dice and not in_hand.is_queued_for_deletion() \
			and (in_hand as Dice).host_queue == self and in_hand not in dice:
		dice.append(in_hand as Dice)

	for i: int in range(len(dice)-1, -1, -1):
		var die: Dice = dice[i]
		TractorBeam.release(die)
		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		
		if recipients.is_empty():
			Globals.player.dice_manager.add(die, true, true)
		else:
			RNGManager.pick_random(RNGManager.Bucket.TARGETING, recipients).dice_manager.add(die, true, true)
		# A hologram is destroyed on arrival rather than handed on.
		if after_death and not die.is_queued_for_deletion():
			die.hand_off_after_death()


## Hands every die straight back to the player with the face it holds: the
## player is reclaiming their own die, not rolling a new one.
func return_dice_to_player() -> void:
	for i: int in range(len(queue)-1, -1, -1):
		var die: Dice = queue[i]
		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		Globals.player.dice_manager.add(die, true, true)
