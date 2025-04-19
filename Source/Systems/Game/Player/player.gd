class_name Player
extends Node2D

@export var time_between_die_spawns: float = 0.2

@export_category('Graphics')
@export var dice_queue_spacing: int = 14

@export_category('Components')
@export var dice_queue: DiceQueue
@export var health: Health
@export var end_turn_button: Control

var num_of_dice: int
@export var dice_scene: PackedScene

@export var money_indicator: MoneyIndicator
var money: int:
	set(value):
		money = value
		Events.set_money.emit(money)


func _ready() -> void:
	Globals.player = self
	health.death.connect(Events.game_over.emit)
	health.health_damaged.connect(Events.player_health_hit.emit)
	health.shields_damaged.connect(Events.player_shields_hit.emit)
	
	dice_queue.die_added.connect(func() -> void:
		_update_dice_queue_locations()
		_make_newest_die_draggable()
		_check_for_end_of_turn()
	)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	
	Globals.tile_grid.tile_activation_complete.connect(_check_for_end_of_turn)
	
	end_turn_button.get_child(1).clicked.connect(end_turn)
	end_turn_button.visible = false

	Events.start_scenario.connect(_start_scenario)
	Events.enemy_turn_over.connect(_start_player_turn)
	Events.load_game_save.connect(_load_game_save)


func _load_game_save(game_save: GameSaveResource) -> void:
	health.max_health = game_save.player_max_health
	health.health = game_save.player_health
	health.shields = game_save.player_defense
	num_of_dice = game_save.num_of_dice
	money = game_save.money


# Update the dice desired locations in the world
func _update_dice_queue_locations() -> void:
	for i: int in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.home_position = global_position + dice_queue.position + Vector2(i * dice_queue_spacing, 0)


func _make_newest_die_draggable() -> void:
	if dice_queue.queue[-1].draggable.state != Draggable.DragState.DRAGGING:
		dice_queue.queue[-1].draggable.state = Draggable.DragState.DEFAULT
		

func _process(_delta: float) -> void:
	# Handle rearranging dice in the queue
	for die in get_children():
		if die is not Dice:
			continue
			
		if die.draggable.state == Draggable.DragState.DRAGGING:
			var current_queue_position = dice_queue.queue.find(die)
			
			if current_queue_position == -1:
				dice_queue.add(die)
			
			var dice_queue_mouse_pos = get_global_mouse_position() - dice_queue.global_position
			

			# Create a rectangle that encompasses the current displayed dice queue
			var dice_queue_bounding_rect: Rect2 = Rect2(
				-dice_queue_spacing/2.0, # x
				-dice_queue_spacing/2.0, # y
				(len(dice_queue.queue) - 1) * dice_queue_spacing, # width
				dice_queue_spacing, # height
			)

			if dice_queue_bounding_rect.has_point(dice_queue_mouse_pos):
				# Determine which queue position the mouse is hovering over
				var hovered_queue_position = int(dice_queue_mouse_pos.x / dice_queue_spacing)

				# Make sure we limit the hovered location to the end of the queue
				hovered_queue_position = min(hovered_queue_position, len(dice_queue.queue)-1)
				
				# Switch the positions of the two dice, then update their locations
				if current_queue_position != hovered_queue_position:
					dice_queue.remove(die)
					dice_queue.queue.insert(hovered_queue_position, die)
					_update_dice_queue_locations()
			
			elif current_queue_position != len(dice_queue.queue)-1:
				dice_queue.remove(die)
				dice_queue.add(die)


func _check_for_end_of_turn() -> void:
	if len(dice_queue.queue) == 0:
		end_turn_button.visible = true
	else:
		end_turn_button.visible = false


func reroll_dice() -> void:
	for die in dice_queue.queue:
		if die:
			die.reroll_with_tween()		
			await get_tree().create_timer(0.1).timeout


func _start_player_turn() -> void:
	reroll_dice()
	
	for die in dice_queue.queue:
		die.draggable.state = Draggable.DragState.DEFAULT


func _delete_existing_dice() -> void:
	for die in get_tree().get_nodes_in_group('Dice'):
		die.queue_free()
	dice_queue.queue = []
	

func spawn_dice(num_to_spawn: int = num_of_dice) -> void:
	for i in range(num_to_spawn):
		await get_tree().create_timer(time_between_die_spawns).timeout
		
		var new_die = dice_scene.instantiate()
		new_die.global_position = global_position + Vector2(600, 0)
		add_child(new_die)
		dice_queue.add(new_die)
		
	_update_dice_queue_locations()
	
	
func _start_scenario() -> void:
	_delete_existing_dice()
	spawn_dice()


func end_turn() -> void:
	end_turn_button.visible = false
	Events.player_turn_over.emit()
