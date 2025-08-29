extends Node2D

@export var prices: Array[Node2D]
var item_to_shop_index: Dictionary[Node, int]

@export var tile_scene: PackedScene
@export var dice_scene: PackedScene
@export var bounding_box: CollisionShape2D

const DICE_PRICE := 25

var shop_tiles: Array[Node2D]


func _ready() -> void:
	Events.open_shop.connect(_open_shop)
	Events.close_shop.connect(_close_shop)
	Events.jump.connect(_close_shop)


func _open_shop() -> void:
	# Create shop layout
	_create_shop_tiles()
	_create_dice_buy_zone()
	show()


func _close_shop() -> void:
	hide()


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
	var tile_spacing_x: int = 46
	var tile_spacing_y: int = 27
	var start_pos: Vector2 = Vector2(-50,-13.5)
	
	item_to_shop_index = {}
	shop_tiles.clear()  # Clear the shop tiles array to prevent accumulation from previous sessions
	
	for row: int in range(2):
		for col: int in range(2):
			var shop_index: int = (col*2) + row
			
			var possible_shop_tiles: Array[TileResource] = _get_possible_shop_tiles()
			if len(possible_shop_tiles) == 0:
				prices[shop_index].visible = false
				continue
			
			var tile: Tile = tile_scene.instantiate()
			tile.tile_resource = possible_shop_tiles.pick_random()
			add_child(tile)
			
			var pos: Vector2 = start_pos + Vector2(col * tile_spacing_x, row * tile_spacing_y)
			tile.global_position = global_position + pos
			tile.draggable.drag_started.connect(Events.show_systems.emit)
			tile.draggable.home_position = tile.global_position
			tile.draggable.emit_reached_new_home = false
			tile.draggable.drag_ended.connect(_on_shop_item_dragged)
			
			shop_tiles.append(tile)
			
			
			item_to_shop_index[tile] = shop_index
			var price: int = _get_randomized_price(tile.tile_resource.rarity)
			prices[shop_index].visible = true
			prices[shop_index].get_child(0).text = str(price)


func _create_dice_buy_zone() -> void:
	var dice: Dice = dice_scene.instantiate()
	add_child(dice)
	dice.global_position = global_position + Vector2(46, -16)
	dice.draggable.home_position = dice.global_position
	dice.draggable.emit_reached_new_home = false
	dice.draggable.drag_started.connect(Events.show_systems.emit)
	dice.draggable.drag_ended.connect(_on_shop_item_dragged)
	
	item_to_shop_index[dice] = 4
	
	prices[4].visible = true
	prices[4].get_child(0).text = str(DICE_PRICE)


func _on_shop_item_dragged(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position: Vector2 = end_position - bounding_box.global_position
	
	if not bounding_box.shape.get_rect().has_point(local_end_position):
		var item: Node = draggable.get_parent()
		
		## TODO: there is a bug here with accessing stuff, and a visual bug too
		var price = int(prices[item_to_shop_index[item]].get_child(0).text)
		
		if Globals.player.money >= price:
			Globals.player.money -= price
			
			item.draggable.drag_started.disconnect(Events.show_systems.emit)
			item.draggable.drag_ended.disconnect(_on_shop_item_dragged)
			
			if item is Tile:
				item.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
				item.reparent(Globals.tile_grid, true)
				Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)
				
			elif item is Dice:
				item.reparent(Globals.player, true)
				Globals.player.dice_manager.add(item)
				Globals.player.num_of_dice += 1
			
			prices[item_to_shop_index[item]].visible = false
