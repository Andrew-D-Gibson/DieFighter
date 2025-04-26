extends Node2D

@export var tile_scene: PackedScene
@export var dice_scene: PackedScene
@export var bounding_box: CollisionShape2D

@export_category('Components')
@export var dice_sell_area: CanAcceptDice
@export var dice_sell_price_label: RichTextLabel

const DICE_COST := 40
const TILE_SELL_VALUE := 20
const DICE_SELL_VALUE := 10

var shop_tiles: Array[Node2D]
var shop_dice: Array[Node2D]
var sell_zone_tiles: Array[Node2D]
var sell_zone_dice: Array[Node2D]

func _ready() -> void:
	Events.open_shop.connect(_open_shop)
	Events.close_shop.connect(_close_shop)
	#Events.load_scenario.connect(func(_scenario: ScenarioResource):
		#queue_free()
	#)
	
	dice_sell_price_label.text = str(DICE_SELL_VALUE)
	dice_sell_area.die_accepted.connect(_on_dice_sold)


func _open_shop() -> void:
	# Create shop layout
	_create_shop_tiles()
	_create_dice_buy_zone()
	show()


func _close_shop() -> void:
	queue_free()


func _create_shop_tiles() -> void:
	var tile_spacing_x := 26
	var tile_spacing_y := 26
	var start_pos := Vector2(0,0)
	
	for row in range(2):
		for col in range(3):
			var tile = tile_scene.instantiate()
			tile.tile_resource = Globals.reward_manager.possible_tile_rewards.pick_random()
			add_child(tile)
			
			var pos = start_pos + Vector2(col * tile_spacing_x, row * tile_spacing_y)
			tile.global_position = global_position + pos
			tile.draggable.drag_started.connect(Events.show_systems.emit)
			tile.draggable.home_position = tile.global_position
			tile.draggable.emit_reached_new_home = false
			tile.draggable.drag_ended.connect(_on_shop_tile_dragged)
			
			shop_tiles.append(tile)


func _create_dice_buy_zone() -> void:
	var dice = dice_scene.instantiate()
	add_child(dice)
	dice.global_position = global_position + Vector2(-24, 12)
	dice.draggable.home_position = dice.global_position
	dice.draggable.emit_reached_new_home = false
	dice.draggable.drag_started.connect(Events.show_systems.emit)
	dice.draggable.drag_ended.connect(_on_dice_bought)
	
	shop_dice.append(dice)


func _on_shop_tile_dragged(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position = end_position - bounding_box.global_position
	
	# Check if dropped in grid
	if not bounding_box.shape.get_rect().has_point(local_end_position):
		var tile = draggable.get_parent()
		if Globals.player.money >= DICE_COST:
			Globals.player.money -= DICE_COST
			tile.draggable.drag_started.disconnect(Events.show_systems.emit)
			tile.draggable.drag_ended.disconnect(_on_shop_tile_dragged)
			tile.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
			tile.tile_activation_complete.connect(Globals.tile_grid.tile_activation_complete.emit)
			tile.reparent(Globals.tile_grid, true)
			Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)


func _on_dice_bought(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position = end_position - bounding_box.global_position
	
	# Check if dropped in player's dice area
	if not bounding_box.shape.get_rect().has_point(local_end_position):
		var dice = draggable.get_parent()
		if Globals.player.money >= DICE_COST:
			Globals.player.money -= DICE_COST
			dice.reparent(Globals.player, true)
			Globals.player.dice_manager.add(dice)
			Globals.player.num_of_dice += 1


func _on_dice_sold(die: Dice) -> void:
	if len(Globals.player.dice_manager.queue) > 1:
		die.queue_free()
		Globals.player.money += DICE_SELL_VALUE
	else:
		print('Player is attempting to sell last die')
	

func _sell_tile(tile: Node2D) -> void:
	if tile in Globals.tile_grid.tiles:
		Globals.player.money += TILE_SELL_VALUE
		Globals.tile_grid.remove_tile(tile)
		tile.queue_free()


func _sell_dice(dice: Node2D) -> void:
	if dice in Globals.player.dice_manager.dice:
		Globals.player.money += DICE_SELL_VALUE
		Globals.player.dice_manager.remove(dice)
		Globals.player.num_of_dice -= 1
		dice.queue_free() 
