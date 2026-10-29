class_name Shop
extends Node2D

## The price tag shown under each shelf. Shelves 0-3 hold tiles, 4 the extra
## die, 5 a Grid Slot.
@export var prices: Array[Node2D]
var item_to_shop_index: Dictionary[Node, int]
## What each item on the shelves costs. The tag only displays it.
var _item_prices: Dictionary[Node, int]

@export var dice_scene: PackedScene
@export var grid_slot_scene: PackedScene
@export var bounding_box: CollisionShape2D

const DICE_PRICE: int = 25
## A cell to grow the grid by. Dearer than a tile: it's room for every tile
## the run finds from here on.
const GRID_SLOT_PRICE: int = 30

const _DICE_SHELF: int = 4
const _GRID_SLOT_SHELF: int = 5

## What a tile on the shelf costs, by rarity, inclusive on both ends.
const PRICE_RANGES: Dictionary[TileResource.Rarity, Vector2i] = {
	TileResource.Rarity.COMMON: Vector2i(10, 20),
	TileResource.Rarity.UNCOMMON: Vector2i(15, 25),
	TileResource.Rarity.RARE: Vector2i(25, 35),
}

## Identifies the screen space the open shop panel holds against the enemy
## formation. See [EnemyFormation].
const _FORMATION_KEY: StringName = &"shop"

## Breathing room either side of the panel, so the shopkeeper isn't scraping
## along its edge.
const _FORMATION_PADDING: float = 6.0

## --- Opening ---
## The shop opens in three beats: the shopkeeper slides aside, the panel
## unfolds into the space it cleared, then the stock pops onto the shelves one
## by one. Everything is stocked (and saveable) at once; only the showing waits.

## From the shop opening until the panel starts to unfold: most of the
## formation's slide (EnemyManager.reflow_time), so the panel opens as the
## ship arrives beside it rather than on top of it.
const _OPEN_DELAY: float = 0.45
const _PANEL_OPEN_TIME: float = 0.22
## Between one item popping onto its shelf and the next.
const _STOCK_STAGGER: float = 0.09
## One item's pop: up past full size, then back.
const _STOCK_POP_TIME: float = 0.26
const _STOCK_POP_OVERSHOOT: float = 1.35
const _STOCK_SPARKLE_COLOR: Color = Color("#eed35d")
const _PANEL_OPEN_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")
## Escalates in pitch, so the stock rings up the shelves.
const _STOCK_POP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/shop_stock_pop.tres")

var _reveal_tween: Tween
## Stock held still and out of reach until it pops in, with what its
## Draggable allowed before: [dragging_allowed, floating_enabled].
var _held_for_reveal: Dictionary[Node, Array] = {}


func _ready() -> void:
	Globals.shop = self
	Events.open_shop.connect(_open_shop)
	Events.close_shop.connect(_close_shop)
	Events.jump.connect(_close_shop)
	Events.player_destroyed.connect(_fade_out_for_death)
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

	_end_reveal()
	_clear_stock()
	if saved_stock is Dictionary:
		_restore_stock(saved_stock)
	else:
		_create_shop_tiles()
		_create_dice_buy_zone()
		_create_grid_slot_stock()
	modulate.a = 1.0
	show()
	_claim_formation_space()
	_play_reveal()


func _close_shop() -> void:
	_end_reveal()
	hide()
	if Globals.enemy_manager:
		Globals.enemy_manager.clear_formation_space(_FORMATION_KEY)


## Hides the panel and the stock, then shows them again in the opening's
## three beats (see _OPEN_DELAY).
func _play_reveal() -> void:
	var background: Sprite2D = $Background
	var title: CanvasItem = $RichTextLabel
	background.scale = Vector2(1.0, 0.0)
	background.modulate.a = 0.0
	title.modulate.a = 0.0

	var stock: Array[Node2D] = _stock_in_shelf_order()
	for item: Node2D in stock:
		_hold_for_reveal(item)
	for tag: Node2D in prices:
		tag.scale = Vector2.ZERO

	_reveal_tween = create_tween()
	_reveal_tween.tween_interval(_OPEN_DELAY)
	_reveal_tween.tween_callback(Events.play_sound.emit.bind(_PANEL_OPEN_SFX))
	_reveal_tween.tween_property(background, "scale", Vector2.ONE, _PANEL_OPEN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.parallel().tween_property(background, "modulate:a", 1.0, _PANEL_OPEN_TIME * 0.5)
	_reveal_tween.tween_property(title, "modulate:a", 1.0, _PANEL_OPEN_TIME * 0.5)

	for item: Node2D in stock:
		_reveal_tween.tween_callback(_pop_in.bind(item))
		_reveal_tween.tween_interval(_STOCK_STAGGER)
	# A tag over an empty slot is hidden; one whose stock is gone pops anyway.
	_reveal_tween.tween_interval(_STOCK_POP_TIME)
	_reveal_tween.tween_callback(_end_reveal)


## What's on the shelves, slot by slot: down the left column, down the right,
## then the die.
func _stock_in_shelf_order() -> Array[Node2D]:
	var stock: Array[Node2D] = []
	for item: Node in item_to_shop_index:
		if is_instance_valid(item) and item is Node2D:
			stock.append(item)
	stock.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return item_to_shop_index[a] < item_to_shop_index[b])
	return stock


func _hold_for_reveal(item: Node2D) -> void:
	var draggable: Draggable = item.draggable
	_held_for_reveal[item] = [draggable.dragging_allowed, draggable.floating_enabled]
	draggable.dragging_allowed = false
	item.hide()


## Lets [param item] be bought, as it was before the reveal held it.
func _release_from_reveal(item: Node) -> void:
	if not _held_for_reveal.has(item):
		return
	var allowed: Array = _held_for_reveal[item]
	_held_for_reveal.erase(item)
	if not is_instance_valid(item):
		return
	item.show()
	# In this order: allowing a drag switches floating on as well.
	item.draggable.dragging_allowed = allowed[0]
	item.draggable.floating_enabled = allowed[1]


## Pops [param item] onto its shelf, with its price tag, a few sparks and a
## blip that climbs with each one.
func _pop_in(item: Node2D) -> void:
	if not is_instance_valid(item) or not item_to_shop_index.has(item):
		return
	_release_from_reveal(item)
	var tag: Node2D = prices[item_to_shop_index[item]]
	for node: Node2D in [item, tag]:
		var rest: Vector2 = Vector2.ONE
		node.scale = Vector2.ZERO
		# A die's flourish tween, which handing it over kills: one bought
		# mid-pop would otherwise go on being resized in the player's hand.
		var tween: Tween = (node as Dice).create_flourish_tween() if node is Dice else node.create_tween()
		tween.tween_property(node, "scale", rest * _STOCK_POP_OVERSHOOT, _STOCK_POP_TIME * 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", rest, _STOCK_POP_TIME * 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	Juice.sparkle(self, item.global_position, _STOCK_SPARKLE_COLOR, 5, 18.0)
	Events.play_sound.emit(_STOCK_POP_SFX)


## Whether some stock is still waiting to pop onto its shelf: out of sight
## and out of reach until it does.
func is_revealing() -> bool:
	return not _held_for_reveal.is_empty()


## Skips to the end of the opening, whatever beat it's on: the panel open,
## every price tag and item at full size and buyable. Also the cleanup when
## the shop closes or restocks mid-opening.
func _end_reveal() -> void:
	if _reveal_tween:
		_reveal_tween.kill()
		_reveal_tween = null
	$Background.scale = Vector2.ONE
	$Background.modulate.a = 1.0
	$RichTextLabel.modulate.a = 1.0
	for tag: Node2D in prices:
		tag.scale = Vector2.ONE
	for item: Node in _held_for_reveal.keys():
		_release_from_reveal(item)
	for item: Node in item_to_shop_index:
		if is_instance_valid(item) and item is Node2D:
			(item as Node2D).scale = Vector2.ONE


## The death sequence wants the whole screen, so the panel gets out of its way
## before the first blast. The formation keeps its gap: a shopkeeper sliding to
## centre mid-explosion would pull the eye.
func _fade_out_for_death() -> void:
	if visible:
		Utils.fade_out_panel(self)


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

	# Every offerable tile, owned ones included, minus what's on the shelves.
	var possible_tile_rewards: Array[TileResource] = Globals.reward_manager.get_possible_tile_rewards()
	return Utils.array_while_excluding(possible_tile_rewards, shop_tile_resources)
	
	
## Drawn from REWARDS, which is seeded per scenario, so a shop reloaded from
## its seed shows the same prices. (It used to draw from RUN, which also meant
## every shop visited shifted the rolls for every sector generated after it.)
func _get_randomized_price(rarity: TileResource.Rarity) -> int:
	if not PRICE_RANGES.has(rarity):
		return 0
	var price_range: Vector2i = PRICE_RANGES[rarity]
	return RNGManager.randi_range(RNGManager.Bucket.REWARDS, price_range.x, price_range.y)


## The middle of a rarity's shelf price, with no roll: what a tile of that
## rarity is worth on average. The repair station pays a share of this for a
## tile sold to it, so a resale value never depends on the dice.
static func base_price(rarity: TileResource.Rarity) -> int:
	if not PRICE_RANGES.has(rarity):
		return 0
	var price_range: Vector2i = PRICE_RANGES[rarity]
	return (price_range.x + price_range.y) / 2


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
	var start_pos: Vector2 = Vector2(-67,-13.5)
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
## price, and whether the extra die and the Grid Slot are still on offer.
func capture_stock() -> Dictionary:
	var tiles: Array = []
	var dice_for_sale: bool = false
	var slot_for_sale: bool = false
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
		elif item is GridSlot:
			slot_for_sale = true
	return {"tiles": tiles, "dice": dice_for_sale, "slot": slot_for_sale}


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
	if stock.get("slot", false):
		_create_grid_slot_stock()


func _create_dice_buy_zone() -> void:
	var dice: Dice = dice_scene.instantiate()
	add_child(dice)
	dice.global_position = global_position + Vector2(63, -16)
	dice.draggable.home_position = dice.global_position
	dice.draggable.drag_started.connect(Events.show_systems.emit)
	dice.draggable.drag_ended.connect(_on_shop_item_dragged)
	
	_stock(dice, _DICE_SHELF)
	_set_price(dice, DICE_PRICE)


## Shelves a Grid Slot while the grid has a sealed cell to open.
func _create_grid_slot_stock() -> void:
	prices[_GRID_SLOT_SHELF].visible = false
	if not Globals.tile_grid.has_locked_cell():
		return
	var slot: GridSlot = grid_slot_scene.instantiate()
	add_child(slot)
	slot.global_position = global_position + Vector2(29, -12)
	slot.draggable.home_position = slot.global_position
	slot.draggable.drag_ended.connect(_on_shop_item_dragged)

	_stock(slot, _GRID_SLOT_SHELF)
	_set_price(slot, GRID_SLOT_PRICE)


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
	_held_for_reveal.erase(item)


func _on_shop_item_dragged(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position: Vector2 = end_position - bounding_box.global_position
	
	if not bounding_box.shape.get_rect().has_point(local_end_position):
		var item: Node = draggable.get_parent()
		# A drag that outlives its shelf (the shop restocked mid-drag) sells
		# nothing.
		if not _item_prices.has(item):
			return
		var price: int = _item_prices[item]
		# No cell for it: refused before any money changes hands, and it
		# drifts back to its shelf.
		if item is Tile and not Globals.tile_grid.has_free_cell() \
		and not Globals.tile_grid.merge_target_at(item, end_position):
			Events.error_text_popup.emit("GRID FULL", end_position)
			return
		var slot_cell: Vector2i = Globals.tile_grid.locked_cell_at(end_position)
		if item is GridSlot and not Globals.tile_grid.is_cell_locked(slot_cell):
			Events.error_text_popup.emit(tr("ERROR_PICK_SEALED_CELL"), end_position)
			return

		if Globals.player.money >= price:
			Globals.player.money -= price
			
			if item.draggable.drag_started.is_connected(Events.show_systems.emit):
				item.draggable.drag_started.disconnect(Events.show_systems.emit)
			item.draggable.drag_ended.disconnect(_on_shop_item_dragged)
			# Sold: it's the player's now, and off the shelves for good. (The
			# reparent below fires the one-shot _forget again, harmlessly.)
			prices[item_to_shop_index[item]].visible = false
			# Bought before its pop (the AutoPilot doesn't wait for one): it
			# mustn't arrive still hidden.
			_release_from_reveal(item)
			_forget(item)
			
			if item is Tile:
				Globals.tile_grid.receive_tile(item, end_position)

			elif item is Dice:
				item.reparent(Globals.player, true)
				Globals.player.dice_manager.add(item)
				Globals.player.num_of_dice += 1

			elif item is GridSlot:
				item.install(slot_cell)

			Events.reward_picked.emit()
