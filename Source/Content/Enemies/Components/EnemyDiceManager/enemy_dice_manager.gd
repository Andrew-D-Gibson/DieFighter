class_name EnemyDiceManager
extends DiceQueue


func _ready() -> void:
	die_added.connect(_update_dice_queue_locations)
	die_removed.connect(_update_dice_queue_locations)
	
	
func add(die: Dice, preserve_value: bool = true, destroy_holographic: bool = true) -> void:
	super(die, preserve_value, destroy_holographic)
	die.scale = Vector2(0.75, 0.75)
		
		
func remove(die: Dice) -> void:
	super(die)
	die.scale = Vector2(1.0, 1.0)
	
	
func _update_dice_queue_locations() -> void:
	for i in range(len(queue)):
		queue[i].draggable.state = Draggable.DragState.ENEMY_HOLDING
		queue[i].draggable.home_position = global_position + Vector2(0, -i * 10)


## Give dice away to other enemies if possible or the player if not	
func give_away_dice() -> void:
	var enemies = Globals.enemy_manager.get_alive_enemies()
	var other_enemies = []
	for enemy in enemies:
		if enemy != get_parent():
			other_enemies.append(enemy)

	for i in range(len(queue)-1, -1, -1):
		var die = queue[i]
		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		
		if len(other_enemies) == 0:
			Globals.player.dice_manager.add(die)
		else:
			other_enemies.pick_random().dice_manager.add(die)
