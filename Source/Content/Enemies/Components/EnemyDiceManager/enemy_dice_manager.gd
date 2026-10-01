class_name EnemyDiceManager
extends DiceQueue

## A die is about to land with this ship, by any route. Fires before it joins
## the queue, so a listener can change its value and everything that reacts to
## the arrival (the targeting computer's intent highlight) sees the final face.
signal die_arriving(die: Dice)


func _ready() -> void:
	die_added.connect(_update_dice_queue_locations)
	die_removed.connect(_update_dice_queue_locations)


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
	die.scale = Vector2(0.75, 0.75)
		
		
func remove(die: Dice) -> void:
	super(die)
	die.scale = Vector2(1.0, 1.0)
	
	
func _update_dice_queue_locations() -> void:
	var dice_spacing: int = 10
	for i: int in range(len(queue)):
		queue[i].draggable.state = Draggable.DragState.ENEMY_HOLDING
		queue[i].draggable.home_position = global_position + Vector2(
			floor(i / 5.0) * dice_spacing, 
			-(i % 5) * dice_spacing
		)


## Give dice away to other enemies or the player randomly
func give_away_dice() -> void:
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()

	for i: int in range(len(queue)-1, -1, -1):
		var die: Dice = queue[i]
		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		
		if len(enemies) == 0:
			Globals.player.dice_manager.add(die, false, true)
		else:
			RNGManager.pick_random(RNGManager.Bucket.TARGETING, enemies).dice_manager.add(die, true, true)
