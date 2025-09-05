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
	var possible_recipients: Array = []
	for enemy: Enemy in enemies:
		if enemy != get_parent():
			possible_recipients.append(enemy)
			
	possible_recipients.append(Globals.player)

	for i: int in range(len(queue)-1, -1, -1):
		var die: Dice = queue[i]
		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		
		possible_recipients.pick_random().dice_manager.add(die)
