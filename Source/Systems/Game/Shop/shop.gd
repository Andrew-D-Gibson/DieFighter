class_name Shop
extends Node2D

## The price tag shown under each shelf. Shelves 0-3 hold tiles, 4 the extra
## die or a Grid Slot.
@export var prices: Array[Node2D]
var item_to_shop_index: Dictionary[Node, int]
## What each item on the shelves costs. The tag only displays it.
var _item_prices: Dictionary[Node, int]

@export var dice_scene: PackedScene
@export var grid_slot_scene: PackedScene
@export var bounding_box: CollisionShape2D

## The game's pixel button (no class_name of its own).
const PixelButton: GDScript = preload("res://Source/Systems/UI/Buttons/button.gd")

@export_category("Reroll")
## Swaps every shelf for fresh stock, for credits. Lives on a tab
## above the panel, with its price tag beside it.
@export var reroll_tab: Node2D
@export var reroll_button: PixelButton
## A coin sprite with a RichTextLabel child, as on the shelves.
@export var reroll_price_tag: Node2D
## What the first reroll at a shop costs: under the cheapest tile, so digging
## for a build is a real option with a thin wallet.
@export var base_reroll_cost: int = 8
## Added after each reroll at the same shop (8, 12, 16, ...), so fishing for
## one tile gets dear. The next shop starts cheap again.
@export var reroll_cost_growth: int = 4

## Rerolls bought at this shop. Drives the price, so the save keeps it
## (capture_stock()).
var rerolls_bought: int = 0

const DICE_PRICE: int = 25
## A cell to grow the grid by. Dearer than a tile: it's room for every tile
## the run finds from here on.
const GRID_SLOT_PRICE: int = 30

## Holds the extra die or a Grid Slot, never both, which keeps the panel
## narrow enough to clear the credit readout and the shopkeeper's bubble.
const _EXTRA_SHELF: int = 4
## How often the extra shelf holds a Grid Slot rather than the die, while the
## grid has a sealed cell to open.
const GRID_SLOT_CHANCE: float = 0.5

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

## --- Closing ---
## The opening backwards, and quicker: the stock pops off its shelves last
## first, the panel folds shut, and only then does the shopkeeper slide back
## to centre (or into the fight it just started).

const _STOCK_OUT_STAGGER: float = 0.05
const _STOCK_OUT_TIME: float = 0.14
const _PANEL_CLOSE_TIME: float = 0.18

## --- Rerolling ---
## The shelves empty (the closing's pop, last first) and refill (the
## opening's pop, first first). The extra shelf is rolled again too.

const _MONEY_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/money_tick.tres")

var _restock_tween: Tween

var _reveal_tween: Tween
var _close_tween: Tween
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
	Events.locale_changed.connect(func(_locale: String) -> void: _refresh_reroll())
	Events.set_money.connect(func(_money: int) -> void: _refresh_reroll())
	if reroll_button:
		reroll_button.pressed_within_window.connect(reroll)


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

	_stop_closing()
	_stop_restock()
	_end_reveal()
	_clear_stock()
	if saved_stock is Dictionary:
		_restore_stock(saved_stock)
	else:
		rerolls_bought = 0
		_create_shop_tiles()
		_stock_extra_shelf()
	modulate.a = 1.0
	show()
	_claim_formation_space()
	_play_reveal()
	# Greyed out until the stock has popped in (_end_reveal refreshes it).
	_refresh_reroll()


## Every ship leaving the scenario asks for this too, open shop or not.
func _close_shop() -> void:
	if is_closing():
		return
	_stop_restock()
	_end_reveal()
	if visible:
		_play_close()
	else:
		_finish_closing()


## Whether the shop is open for business: shown, and not on its way out.
func is_open() -> bool:
	return is_visible_in_tree() and not is_closing()


func is_closing() -> bool:
	return _close_tween != null and _close_tween.is_valid()


## Plays the closing's three beats (see _STOCK_OUT_STAGGER). The stock stops
## being for sale the moment it starts.
func _play_close() -> void:
	var stock: Array[Node2D] = _stock_in_shelf_order()
	stock.reverse()
	for item: Node2D in stock:
		item.draggable.dragging_allowed = false

	_close_tween = create_tween()
	for item: Node2D in stock:
		_close_tween.tween_callback(_pop_out.bind(item))
		_close_tween.tween_interval(_STOCK_OUT_STAGGER)
	_close_tween.tween_interval(_STOCK_OUT_TIME)
	_close_tween.tween_callback(Events.play_sound.emit.bind(_PANEL_OPEN_SFX))
	_close_tween.tween_property($RichTextLabel, "modulate:a", 0.0, _PANEL_CLOSE_TIME * 0.5)
	if reroll_tab:
		_close_tween.parallel().tween_property(reroll_tab, "modulate:a", 0.0, _PANEL_CLOSE_TIME * 0.5)
	_close_tween.tween_property($Background, "scale", Vector2(1.0, 0.0), _PANEL_CLOSE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_close_tween.parallel().tween_property($Background, "modulate:a", 0.0, _PANEL_CLOSE_TIME)
	_close_tween.tween_callback(_finish_closing)


## Pops [param stocked] and its price tag off the shelf: a swell, then gone.
## Untyped, since a jump frees the die on offer partway through the closing,
## and a freed node won't pass as a typed argument.
func _pop_out(stocked: Variant) -> void:
	if not is_instance_valid(stocked) or not item_to_shop_index.has(stocked):
		return
	var item: Node2D = stocked
	var tag: Node2D = prices[item_to_shop_index[item]]
	for node: Node2D in [item, tag]:
		var tween: Tween = (node as Dice).create_flourish_tween() if node is Dice else node.create_tween()
		tween.tween_property(node, "scale", Vector2.ONE * 1.2, _STOCK_OUT_TIME * 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", Vector2.ZERO, _STOCK_OUT_TIME * 0.65) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Juice.sparkle(self, item.global_position, _STOCK_SPARKLE_COLOR, 4, 14.0)


## The shop shut: hidden, put back to its resting look for next time, and
## the formation's gap handed back.
func _finish_closing() -> void:
	_close_tween = null
	hide()
	_end_reveal()
	if Globals.enemy_manager:
		Globals.enemy_manager.clear_formation_space(_FORMATION_KEY)


## Cuts a closing short, for a shop opening again before it finished.
func _stop_closing() -> void:
	if _close_tween:
		_close_tween.kill()
		_close_tween = null


## Hides the panel and the stock, then shows them again in the opening's
## three beats (see _OPEN_DELAY).
func _play_reveal() -> void:
	var background: Sprite2D = $Background
	var title: CanvasItem = $RichTextLabel
	background.scale = Vector2(1.0, 0.0)
	background.modulate.a = 0.0
	title.modulate.a = 0.0
	if reroll_tab:
		reroll_tab.modulate.a = 0.0

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
	if reroll_tab:
		_reveal_tween.parallel().tween_property(reroll_tab, "modulate:a", 1.0, _PANEL_OPEN_TIME * 0.5)

	for item: Node2D in stock:
		_reveal_tween.tween_callback(_pop_in.bind(item))
		_reveal_tween.tween_interval(_STOCK_STAGGER)
	# A tag over an empty slot is hidden; one whose stock is gone pops anyway.
	_reveal_tween.tween_interval(_STOCK_POP_TIME)
	_reveal_tween.tween_callback(_end_reveal)


## What's on the shelves, slot by slot: down the left column, down the right,
## then the extra shelf.
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
	if reroll_tab:
		reroll_tab.modulate.a = 1.0
	for tag: Node2D in prices:
		tag.scale = Vector2.ONE
	for item: Node in _held_for_reveal.keys():
		_release_from_reveal(item)
	for item: Node in item_to_shop_index:
		if is_instance_valid(item) and item is Node2D:
			(item as Node2D).scale = Vector2.ONE
	_refresh_reroll()


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


## [param also_excluded]: tiles kept off the shelves besides those on them,
## such as the stock a reroll just cleared.
func _get_possible_shop_tiles(also_excluded: Array[TileResource] = []) -> Array[TileResource]:
	var shop_tile_resources: Array[TileResource] = also_excluded.duplicate()
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


## [param cleared]: the stock a reroll just took away, kept off the new
## shelves unless nothing else is left to offer.
func _create_shop_tiles(cleared: Array[TileResource] = []) -> void:
	for row: int in range(2):
		for col: int in range(2):
			var shop_index: int = (col*2) + row
			
			var possible_shop_tiles: Array[TileResource] = _get_possible_shop_tiles(cleared)
			if possible_shop_tiles.is_empty():
				possible_shop_tiles = _get_possible_shop_tiles()
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
	return {"tiles": tiles, "dice": dice_for_sale, "slot": slot_for_sale, "rerolls": rerolls_bought}


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
	rerolls_bought = int(stock.get("rerolls", 0))

	for entry: Variant in stock.get("tiles", []):
		var path: String = ContentRegistry.get_tile_path(str(entry["tile"]))
		if path == "":
			continue
		var tile: Tile = _place_shop_tile(int(entry["slot"]), ResourceLoader.load(path))
		_set_price(tile, int(entry["price"]))

	# One or the other: a save from before the shelves were merged may claim
	# both, and they'd stack on the one shelf.
	if stock.get("dice", false):
		_create_dice_buy_zone()
	elif stock.get("slot", false):
		_create_grid_slot_stock()


## Rolls what the extra shelf holds. Drawn from REWARDS like the prices, so a
## shop reloaded from its seed offers the same thing.
func _stock_extra_shelf() -> void:
	if Globals.tile_grid.has_locked_cell() \
	and RNGManager.randf(RNGManager.Bucket.REWARDS) < GRID_SLOT_CHANCE:
		_create_grid_slot_stock()
	else:
		_create_dice_buy_zone()


func _create_dice_buy_zone() -> void:
	var dice: Dice = dice_scene.instantiate()
	add_child(dice)
	dice.global_position = global_position + Vector2(46, -16)
	dice.draggable.home_position = dice.global_position
	dice.draggable.drag_started.connect(Events.show_systems.emit)
	dice.draggable.drag_ended.connect(_on_shop_item_dragged)
	
	_stock(dice, _EXTRA_SHELF)
	_set_price(dice, DICE_PRICE)


## Shelves a Grid Slot while the grid has a sealed cell to open.
func _create_grid_slot_stock() -> void:
	prices[_EXTRA_SHELF].visible = false
	if not Globals.tile_grid.has_locked_cell():
		return
	var slot: GridSlot = grid_slot_scene.instantiate()
	add_child(slot)
	slot.global_position = global_position + Vector2(46, -12)
	slot.draggable.home_position = slot.global_position
	slot.draggable.drag_ended.connect(_on_shop_item_dragged)

	_stock(slot, _EXTRA_SHELF)
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
		# A drag that outlives its shelf (the shop restocked mid-drag, or is
		# closing) sells nothing.
		if not _item_prices.has(item) or is_closing():
			return
		var price: int = _item_prices[item]
		# Nowhere for it to go: refused before any money changes hands, and
		# it drifts back to its shelf.
		var refusal: String = OfferIntake.refusal(item, end_position)
		if not refusal.is_empty():
			Events.error_text_popup.emit(refusal, end_position)
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
			OfferIntake.take(item, end_position)
			Events.reward_picked.emit()


# ── Rerolling ─────────────────────────────────────────────────────────────────

func reroll_cost() -> int:
	return base_reroll_cost + reroll_cost_growth * rerolls_bought


## Whether the shelves are mid-swap: the old stock popping off, or the new
## popping on.
func is_restocking() -> bool:
	return _restock_tween != null and _restock_tween.is_valid()


## Why a reroll can't be bought right now, or "" if it can. "busy" covers the
## shop still opening, closing or restocking, and anything in hand: a carried
## shelf tile would otherwise land on the button and try to sell.
func reroll_refusal() -> String:
	if not is_open() or is_revealing() or is_restocking() or Draggable.holding() != null:
		return "busy"
	if Globals.player.money < reroll_cost():
		return tr("REPAIR_NO_CREDITS")
	return ""


## Pays for a reroll and swaps every shelf for fresh stock. False, and
## nothing paid, if reroll_refusal() objects.
func reroll() -> bool:
	if not reroll_refusal().is_empty():
		return false

	Globals.player.money -= reroll_cost()
	rerolls_bought += 1
	Events.play_sound.emit(_MONEY_SFX)
	if reroll_button:
		Juice.ring(self, reroll_button.global_position + reroll_button.size / 2.0, Globals.green, 16.0)

	# What's still on the shelves, last first, as the closing pops it.
	var outgoing: Array[Node2D] = _stock_in_shelf_order()
	var cleared: Array[TileResource] = []
	for item: Node2D in outgoing:
		if item is Tile:
			cleared.append((item as Tile).tile_resource)
		item.draggable.dragging_allowed = false
	outgoing.reverse()

	_restock_tween = create_tween()
	for item: Node2D in outgoing:
		_restock_tween.tween_callback(_pop_out.bind(item))
		_restock_tween.tween_interval(_STOCK_OUT_STAGGER)
	_restock_tween.tween_interval(_STOCK_OUT_TIME)
	_restock_tween.tween_callback(_refill_shelves.bind(cleared))
	_refresh_reroll()
	return true


## The second half of a reroll: the old stock goes, new stock is shelved out
## of sight, and it pops in one by one as the opening's does.
func _refill_shelves(cleared: Array[TileResource]) -> void:
	for item: Node in item_to_shop_index.keys():
		if is_instance_valid(item) and item.get_parent() == self:
			item.queue_free()
		_forget(item)
	for tag: Node2D in prices:
		tag.visible = false
	_create_shop_tiles(cleared)
	_stock_extra_shelf()

	var incoming: Array[Node2D] = _stock_in_shelf_order()
	for item: Node2D in incoming:
		_hold_for_reveal(item)
		prices[item_to_shop_index[item]].scale = Vector2.ZERO

	# The same checkpoint a purchase takes, so a Continue keeps the new stock
	# and the rising price.
	Events.reward_picked.emit()

	_reveal_tween = create_tween()
	for item: Node2D in incoming:
		_reveal_tween.tween_callback(_pop_in.bind(item))
		_reveal_tween.tween_interval(_STOCK_STAGGER)
	_reveal_tween.tween_interval(_STOCK_POP_TIME)
	_reveal_tween.tween_callback(_end_reveal)


## Cuts a reroll short (the shop closing or reopening): the old stock is
## dropped from the books, so nothing half-popped can still be bought.
func _stop_restock() -> void:
	if _restock_tween:
		_restock_tween.kill()
		_restock_tween = null


func _refresh_reroll() -> void:
	if not reroll_button or not is_instance_valid(Globals.player):
		return
	var affordable: bool = Globals.player.money >= reroll_cost()
	reroll_button.set_button_text(tr("SHOP_REROLL_BUTTON"))
	reroll_button.disabled = not reroll_refusal().is_empty()
	reroll_button.update_ui()
	if reroll_price_tag:
		var label: RichTextLabel = reroll_price_tag.get_child(0) as RichTextLabel
		label.text = str(reroll_cost())
		label.add_theme_color_override("default_color", Globals.white if affordable else Globals.red)
