class_name Shop
extends Node2D

## The price tag shown under each slot. Slots 0-3 hold tiles, 4 the extra die.
@export var prices: Array[Node2D]
var item_to_shop_index: Dictionary[Node, int]
## What each item on the shelves costs. The tag only displays it.
var _item_prices: Dictionary[Node, int]

@export var dice_scene: PackedScene
@export var bounding_box: CollisionShape2D

const DICE_PRICE: int = 25

## Identifies the screen space the open shop panel holds against the enemy
## formation. See [EnemyFormation].
const _FORMATION_KEY: StringName = &"shop"

## Breathing room either side of the panel, so the shopkeeper isn't scraping
## along its edge.
const _FORMATION_PADDING: float = 6.0


func _ready() -> void:
	Globals.shop = self
	Events.open_shop.connect(_open_shop)
	Events.close_shop.connect(_close_shop)
	Events.jump.connect(_close_shop)
	Events.start_scenario.connect(_reopen_saved_shop)


## Continuing a save taken in an open shop. Normally the shopkeeper's arrival
## effect opens the shop, but restored ships don't replay arrival effects
## (see Enemy._skip_next_enter_effects), so the save reopens it itself.
func _reopen_saved_shop() -> void:
	if Globals.state_manager and Globals.state_manager.get_restore().get("shop") is Dictionary:
		_open_shop()


func _open_shop() -> void:
	# Continuing a save taken in this shop puts back what was left on the
	# shelves, rather than restocking it and re-offering what was bought.
	var saved_stock: Variant = null
	if Globals.state_manager:
		saved_stock = Globals.state_manager.get_restore().get("shop")

	_clear_stock()
	if saved_stock is Dictionary:
		_restore_stock(saved_stock)
	else:
		_create_shop_tiles()
		_create_dice_buy_zone()
	show()
	_claim_formation_space()


func _close_shop() -> void:
	hide()
	if Globals.enemy_manager:
		Globals.enemy_manager.clear_formation_space(_FORMATION_KEY)


## The panel covers the middle of the screen, which is exactly where a lone
## shopkeeper would otherwise be standing. Tell the formation to stand clear
## and it slides out from behind the panel — and back to centre when the shop
## closes.
func _claim_formation_space() -> void:
	if not Globals.enemy_manager or not bounding_box:
		return

	var panel: Rect2 = bounding_box.shape.get_rect()
	var centre_x: float = bounding_box.global_position.x
	Globals.enemy_manager.reserve_formation_space(
		_FORMATION_KEY,
		centre_x + panel.position.x - _FORMATION_PADDING,
		centre_x + panel.end.x + _FORMATION_PADDING
	)


func _get_possible_shop_tiles() -> Array[TileResource]:
	var shop_tile_resources: Array[TileResource] = []
	for item: Node in item_to_shop_index:
		if item is Tile:
			shop_tile_resources.append(item.tile_resource)

	# Tiles the player doesn't own yet, minus what's already on the shelves.
	var possible_tile_rewards: Array[TileResource] = Globals.reward_manager.get_possible_tile_rewards()
	return Utils.array_while_excluding(possible_tile_rewards, shop_tile_resources)
	
	
## Drawn from REWARDS, which is seeded per scenario, so a shop reloaded from
## its seed shows the same prices. (It used to draw from RUN, which also meant
## every shop visited shifted the rolls for every sector generated after it.)
func _get_randomized_price(rarity: TileResource.Rarity) -> int:
	match rarity:
		TileResource.Rarity.COMMON:
			return RNGManager.randi_range(RNGManager.Bucket.REWARDS, 10, 20)
		TileResource.Rarity.UNCOMMON:
			return RNGManager.randi_range(RNGManager.Bucket.REWARDS, 15, 25)
		TileResource.Rarity.RARE:
			return RNGManager.randi_range(RNGManager.Bucket.REWARDS, 25, 35)
		_:
			return 0


func _create_shop_tiles() -> void:
	for row: int in range(2):
		for col: int in range(2):
			var shop_index: int = (col*2) + row
			
			var possible_shop_tiles: Array[TileResource] = _get_possible_shop_tiles()
			if len(possible_shop_tiles) == 0:
				prices[shop_index].visible = false
				continue
			
			# Rarity-weighted here too, so a shop's four slots aren't a
			# uniformly random slice of the whole tile list. Price still scales
			# with rarity on top of this.
			var chosen_resource: TileResource = \
				Globals.reward_manager.pick_weighted_tile_reward(possible_shop_tiles)
			if chosen_resource == null:
				prices[shop_index].visible = false
				continue
			var tile: Tile = _place_shop_tile(shop_index, chosen_resource)
			_set_price(tile, _get_randomized_price(tile.tile_resource.rarity))


## Puts a tile for sale in the given slot. Slots run down each column:
## slot = col * 2 + row.
func _place_shop_tile(shop_index: int, tile_resource: TileResource) -> Tile:
	var tile_spacing_x: int = 46
	var tile_spacing_y: int = 27
	var start_pos: Vector2 = Vector2(-50,-13.5)
	var col: int = shop_index / 2
	var row: int = shop_index % 2

	var tile: Tile = Globals.tile_grid.create_tile(tile_resource)
	tile.on_offer = true
	add_child(tile)

	var pos: Vector2 = start_pos + Vector2(col * tile_spacing_x, row * tile_spacing_y)
	tile.global_position = global_position + pos
	tile.draggable.drag_started.connect(Events.show_systems.emit)
	tile.draggable.home_position = tile.global_position
	tile.draggable.drag_ended.connect(_on_shop_item_dragged)

	_stock(tile, shop_index)
	return tile


## What [param item] costs, or -1 if it isn't on the shelves.
func price_of(item: Node) -> int:
	return _item_prices.get(item, -1)


func _set_price(item: Node, price: int) -> void:
	_item_prices[item] = price
	var tag: Node2D = prices[item_to_shop_index[item]]
	tag.visible = true
	tag.get_child(0).text = str(price)


## What's still for sale, for the save: each unsold tile with its slot and
## price, and whether the extra die is still on offer.
func capture_stock() -> Dictionary:
	var tiles: Array = []
	var dice_for_sale: bool = false
	for item: Node in item_to_shop_index:
		if not is_instance_valid(item) or item.get_parent() != self:
			continue
		var shop_index: int = item_to_shop_index[item]
		if not prices[shop_index].visible:
			continue
		if item is Tile:
			tiles.append({
				"slot": shop_index,
				"tile": ContentRegistry.get_tile_id(item.tile_resource.resource_path),
				"price": _item_prices[item],
			})
		elif item is Dice:
			dice_for_sale = true
	return {"tiles": tiles, "dice": dice_for_sale}


## Frees whatever the last shop left unsold. Closing only hides the panel, so
## without this every shop visit stacked another set of hidden tiles and dice
## under this node.
func _clear_stock() -> void:
	for item: Node in item_to_shop_index:
		if is_instance_valid(item) and item.get_parent() == self:
			item.queue_free()
	item_to_shop_index = {}
	_item_prices = {}


## Inverse of capture_stock(). Slots that were sold stay empty.
func _restore_stock(stock: Dictionary) -> void:
	for price_node: Node2D in prices:
		price_node.visible = false

	for entry: Variant in stock.get("tiles", []):
		var path: String = ContentRegistry.get_tile_path(str(entry["tile"]))
		if path == "":
			continue
		var tile: Tile = _place_shop_tile(int(entry["slot"]), ResourceLoader.load(path))
		_set_price(tile, int(entry["price"]))

	if stock.get("dice", false):
		_create_dice_buy_zone()


func _create_dice_buy_zone() -> void:
	var dice: Dice = dice_scene.instantiate()
	add_child(dice)
	dice.global_position = global_position + Vector2(46, -16)
	dice.draggable.home_position = dice.global_position
	dice.draggable.drag_started.connect(Events.show_systems.emit)
	dice.draggable.drag_ended.connect(_on_shop_item_dragged)
	
	_stock(dice, 4)
	_set_price(dice, DICE_PRICE)


## Shelves [param item] in [param shop_index]. An item can leave without being
## bought (a jump frees the die on offer, which isn't the player's), and is
## taken off the books when it does: a freed key in a typed dictionary
## breaks every later pass over it.
func _stock(item: Node, shop_index: int) -> void:
	item_to_shop_index[item] = shop_index
	item.tree_exiting.connect(_forget.bind(item), CONNECT_ONE_SHOT)


func _forget(item: Node) -> void:
	item_to_shop_index.erase(item)
	_item_prices.erase(item)


func _on_shop_item_dragged(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position: Vector2 = end_position - bounding_box.global_position
	
	if not bounding_box.shape.get_rect().has_point(local_end_position):
		var item: Node = draggable.get_parent()
		# A drag that outlives its shelf (the shop restocked mid-drag) sells
		# nothing.
		if not _item_prices.has(item):
			return
		var price: int = _item_prices[item]

		if Globals.player.money >= price:
			Globals.player.money -= price
			
			item.draggable.drag_started.disconnect(Events.show_systems.emit)
			item.draggable.drag_ended.disconnect(_on_shop_item_dragged)
			# Sold: it's the player's now, and off the shelves for good. (The
			# reparent below fires the one-shot _forget again, harmlessly.)
			prices[item_to_shop_index[item]].visible = false
			_forget(item)
			
			if item is Tile:
				Globals.tile_grid.receive_tile(item, end_position)

			elif item is Dice:
				item.reparent(Globals.player, true)
				Globals.player.dice_manager.add(item)
				Globals.player.num_of_dice += 1

			Events.reward_picked.emit()
