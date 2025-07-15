extends Node2D

@export var prices: Array[Node2D]
var tile_to_shop_index: Dictionary[Tile, int]

@export var tile_scene: PackedScene
@export var dice_scene: PackedScene
@export var bounding_box: CollisionShape2D

const DICE_PRICE := 25

var shop_tiles: Array[Node2D]
var shop_dice: Array[Node2D]



func _ready() -> void:
	Events.open_shop.connect(_open_shop)
	Events.close_shop.connect(_close_shop)


func _open_shop() -> void:
	# Create shop layout
	_create_shop_tiles()
	_create_dice_buy_zone()
	show()


func _close_shop() -> void:
	queue_free()


func _get_possible_shop_tiles() -> Array[TileResource]:
	# Get an array of tile resources already in the shop
	var shop_tile_resources = []
	for tile in shop_tiles:
		shop_tile_resources.append(tile.tile_resource)
		
	# Get an array of the possible rewards not already owned by the player
	var possible_tile_rewards = Globals.reward_manager.get_possible_tile_rewards()
		
	# Filter the possible rewards, removing the tile resources already in the shop
	return Utils.array_while_excluding(possible_tile_rewards, shop_tile_resources)
	
	
func _get_randomized_price(rarity: TileResource.Rarity) -> int:
	match rarity:
		TileResource.Rarity.COMMON:
			return randi_range(10, 20)
		TileResource.Rarity.UNCOMMON:
			return randi_range(15, 25)
		TileResource.Rarity.RARE:
			return randi_range(25, 35)
		_:
			return 0
		


func _create_shop_tiles() -> void:
	var tile_spacing_x := 46
	var tile_spacing_y := 27
	var start_pos := Vector2(-50,-13.5)
	
	tile_to_shop_index = {}
	
	for row in range(2):
		for col in range(2):
			var possible_shop_tiles = _get_possible_shop_tiles()
			if len(possible_shop_tiles) == 0:
				break
			
			var tile = tile_scene.instantiate()
			tile.tile_resource = possible_shop_tiles.pick_random()
			add_child(tile)
			
			var pos = start_pos + Vector2(col * tile_spacing_x, row * tile_spacing_y)
			tile.global_position = global_position + pos
			tile.draggable.drag_started.connect(Events.show_systems.emit)
			tile.draggable.home_position = tile.global_position
			tile.draggable.emit_reached_new_home = false
			tile.draggable.drag_ended.connect(_on_shop_tile_dragged)
			
			shop_tiles.append(tile)
			
			var shop_index = (col*2) + row
			tile_to_shop_index[tile as Tile] = shop_index
			var price = _get_randomized_price(tile.tile_resource.rarity)
			prices[shop_index].visible = true
			prices[shop_index].get_child(0).text = str(price)


func _create_dice_buy_zone() -> void:
	var dice = dice_scene.instantiate()
	add_child(dice)
	dice.global_position = global_position + Vector2(46, -16)
	dice.draggable.home_position = dice.global_position
	dice.draggable.emit_reached_new_home = false
	dice.draggable.drag_started.connect(Events.show_systems.emit)
	dice.draggable.drag_ended.connect(_on_dice_bought)
	
	prices[4].visible = true
	prices[4].get_child(0).text = str(DICE_PRICE)
	
	shop_dice.append(dice)


func _on_shop_tile_dragged(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position = end_position - bounding_box.global_position
	
	if not bounding_box.shape.get_rect().has_point(local_end_position):
		var tile = draggable.get_parent()
		var price = int(prices[tile_to_shop_index[tile as Tile]].get_child(0).text)
		
		if Globals.player.money >= price:
			Globals.player.money -= price
			tile.draggable.drag_started.disconnect(Events.show_systems.emit)
			tile.draggable.drag_ended.disconnect(_on_shop_tile_dragged)
			tile.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
			tile.tile_activation_complete.connect(Globals.tile_grid.tile_activation_complete.emit)
			tile.reparent(Globals.tile_grid, true)
			Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)
			
			prices[tile_to_shop_index[tile as Tile]].visible = false


func _on_dice_bought(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position = end_position - bounding_box.global_position
	
	if not bounding_box.shape.get_rect().has_point(local_end_position):
		var dice = draggable.get_parent()
		if Globals.player.money >= DICE_PRICE:
			Globals.player.money -= DICE_PRICE
			dice.reparent(Globals.player, true)
			Globals.player.dice_manager.add(dice)
			dice.draggable.drag_started.connect(Events.hide_comms.emit)
			Globals.player.num_of_dice += 1
			
			prices[4].visible = false
