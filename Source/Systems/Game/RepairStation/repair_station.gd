class_name RepairStation
extends Node2D
## A friendly dock that patches the hull and buys tiles.
##
## Built like [Shop]: the dock ship's arrival effect opens the panel
## (SCENARIO_CONTROL / OPEN_REPAIR_STATION), turning on it closes it, and a
## jump closes it. Repairs are bought with the button, as often as the player
## can pay and the hull has room. Tiles are sold by dragging them off the grid
## onto the SELL slot, the reverse of dragging stock off the shop's shelves.
##
## Every number the station uses is exported here, so the economy tunes in one
## place (the defaults below, or the instance in repair_station.tscn).

const _MONEY_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/money_tick.tres")
const _ERROR_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/error.tres")
## The game's pixel button (no class_name of its own).
const PixelButton: GDScript = preload("res://Source/Systems/UI/Buttons/button.gd")

## Identifies the screen space the open panel holds against the enemy
## formation, as the shop's does. See [EnemyFormation].
const _FORMATION_KEY: StringName = &"repair_station"
const _FORMATION_PADDING: float = 6.0

@export_category("Repairs")
## Hull restored per repair. A sixth of the starting 32: enough that one repair
## is worth a stop, small enough that a full patch-up takes several.
@export var hull_per_repair: int = 6
## What the first repair at a station costs. Below the cheapest shop tile (10),
## so even a thin wallet can buy one.
@export var base_repair_cost: int = 10
## Added to the price after each repair at the same station, so topping off a
## badly hurt hull costs real money (10, 15, 20, 25, ...) and the next station
## starts cheap again.
@export var repair_cost_growth: int = 5

@export_category("Sales")
## Share of a rarity's average shelf price (Shop.base_price) paid for a tile:
## COMMON 7, UNCOMMON 10, RARE 15. Half, so selling and buying back is a loss
## and selling is a choice rather than a loop.
@export_range(0.0, 1.0) var sell_fraction: float = 0.5
## Tiles the grid must keep. Selling the last one would leave every die with
## nowhere to go but the engine.
@export var min_tiles_kept: int = 1
## Tiles never bought, whatever else holds. The Engine Charger lives off the
## grid and can't be dragged, so it can't reach the slot anyway; it's listed so
## that stays true if it ever moves onto the grid.
@export var unsellable_tiles: Array[TileResource] = []

@export_category("Nodes")
## The whole panel, for the formation and for drops.
@export var bounding_box: CollisionShape2D
## Where a tile is let go of to sell it.
@export var sell_zone: CollisionShape2D
@export var repair_button: PixelButton
@export var title_label: RichTextLabel
## "+6 HULL", or why a repair can't be had.
@export var repair_label: RichTextLabel
## Price tag: a coin sprite with a RichTextLabel child, as on the shop's shelves.
@export var repair_price_tag: Node2D
@export var sell_label: RichTextLabel
## "DROP TILE", or what a lifted tile would fetch.
@export var sell_hint: RichTextLabel
@export var sell_price_tag: Node2D

## Repairs bought at this station. Drives the price, so a mid-scenario save
## keeps it (capture_state()).
var repairs_bought: int = 0

## The grid tile being dragged right now, whose price the slot shows.
var _lifted_tile: Tile


func _ready() -> void:
	Globals.repair_station = self
	Events.open_repair_station.connect(_open_station)
	Events.close_repair_station.connect(_close_station)
	Events.jump.connect(_close_station)
	Events.start_scenario.connect(_reopen_saved_station)
	Events.locale_changed.connect(func(_locale: String) -> void: _refresh())
	Events.set_money.connect(func(_money: int) -> void: _refresh())
	if repair_button:
		repair_button.pressed_within_window.connect(repair)


# ── Economy ────────────────────────────────────────────────────────────────────

func repair_cost() -> int:
	return base_repair_cost + repair_cost_growth * repairs_bought


## Hull the next repair would actually restore: the full amount, or what's
## missing if that's less.
func repair_amount() -> int:
	var health: Health = Globals.player.health
	return clampi(health.max_health - health.health, 0, hull_per_repair)


## Why the next repair can't be bought right now, or "" if it can.
func repair_refusal() -> String:
	if repair_amount() <= 0:
		return tr("REPAIR_HULL_FULL")
	if Globals.player.money < repair_cost():
		return tr("REPAIR_NO_CREDITS")
	return ""


## Buys one repair. False, and nothing paid, if repair_refusal() objects.
func repair() -> bool:
	if not repair_refusal().is_empty():
		_refuse(repair_refusal(), repair_button.global_position if repair_button else global_position)
		return false

	var healed: int = repair_amount()
	Globals.player.money -= repair_cost()
	repairs_bought += 1
	Globals.player.health.change_health(healed)
	_play_repair_feedback(healed)
	# The same checkpoint a shop purchase takes, so a Continue keeps both the
	# hull and the rising price.
	Events.reward_picked.emit()
	_refresh()
	return true


## What the station pays for a tile of [param resource]'s rarity.
func sell_price(resource: TileResource) -> int:
	return floori(Shop.base_price(resource.rarity) * sell_fraction)


## Why [param tile] can't be sold right now, or "" if it can.
func sale_refusal(tile: Tile) -> String:
	var grid: TileGrid = Globals.tile_grid
	if not is_instance_valid(tile) or not grid or not grid.is_grid_pos_valid(grid.find_tile_pos(tile)):
		return tr("SELL_NOT_FOR_SALE")
	if tile.tile_resource in unsellable_tiles or not tile.tile_resource.dragging_allowed:
		return tr("SELL_NOT_FOR_SALE")
	if grid.tile_locations.size() <= min_tiles_kept:
		return tr("SELL_LAST_TILE")
	# A tile whose chain is still resolving would vanish from under it.
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine and (engine.currently_processing_queue or not engine.event_queue.is_empty()):
		return tr("SELL_TILE_BUSY")
	return ""


## Sells [param tile] off the grid. False, and nothing changes hands, if
## sale_refusal() objects.
func sell(tile: Tile) -> bool:
	var refusal: String = sale_refusal(tile)
	if not refusal.is_empty():
		_refuse(refusal, tile.global_position if is_instance_valid(tile) else global_position)
		return false

	var price: int = sell_price(tile.tile_resource)
	Globals.tile_grid.remove_tile(tile)
	Globals.player.money += price
	_play_sale_feedback(price)
	Events.reward_picked.emit()
	_refresh()
	return true


## What a mid-scenario save keeps of an open station.
func capture_state() -> Dictionary:
	return {"repairs": repairs_bought}


# ── Opening and closing ────────────────────────────────────────────────────────

## Continuing a save taken at an open station. Restored ships don't replay
## their arrival effects (see Enemy._skip_next_enter_effects), so the save
## reopens it, as the shop's does.
func _reopen_saved_station() -> void:
	if Globals.state_manager and Globals.state_manager.get_restore().get("repair_station") is Dictionary:
		_open_station()


func _open_station() -> void:
	repairs_bought = 0
	if Globals.state_manager:
		var saved: Variant = Globals.state_manager.get_restore().get("repair_station")
		if saved is Dictionary:
			repairs_bought = int(saved.get("repairs", 0))

	_listen_to_the_grid(true)
	show()
	_claim_formation_space()
	_refresh()


func _close_station() -> void:
	hide()
	_listen_to_the_grid(false)
	_lifted_tile = null
	if Globals.enemy_manager:
		Globals.enemy_manager.clear_formation_space(_FORMATION_KEY)


## Only an open station watches the grid, so a tile dragged off it anywhere
## else is just put back.
func _listen_to_the_grid(listen: bool) -> void:
	var grid: TileGrid = Globals.tile_grid
	if not is_instance_valid(grid):
		return
	if listen and not grid.tile_dropped_off_grid.is_connected(_on_tile_dropped_off_grid):
		grid.tile_dropped_off_grid.connect(_on_tile_dropped_off_grid)
		grid.tile_lifted.connect(_on_tile_lifted)
		Globals.player.health.health_set.connect(_refresh)
	elif not listen and grid.tile_dropped_off_grid.is_connected(_on_tile_dropped_off_grid):
		grid.tile_dropped_off_grid.disconnect(_on_tile_dropped_off_grid)
		grid.tile_lifted.disconnect(_on_tile_lifted)
		if is_instance_valid(Globals.player) and Globals.player.health.health_set.is_connected(_refresh):
			Globals.player.health.health_set.disconnect(_refresh)


## The panel sits mid-screen, where the dock ship would otherwise park.
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


# ── Selling by drag ────────────────────────────────────────────────────────────

func _on_tile_lifted(tile: Tile) -> void:
	_lifted_tile = tile
	# Whatever the drop does, the slot goes back to its prompt afterwards.
	tile.draggable.drag_ended.connect(_on_lifted_tile_dropped, CONNECT_ONE_SHOT)
	_refresh()


func _on_lifted_tile_dropped(_draggable: Draggable, _end_position: Vector2) -> void:
	_lifted_tile = null
	_refresh()


func _on_tile_dropped_off_grid(tile: Tile, global_drop_pos: Vector2) -> void:
	if not visible or not is_in_sell_zone(global_drop_pos):
		return
	sell(tile)


func is_in_sell_zone(global_pos: Vector2) -> bool:
	if not sell_zone:
		return false
	return sell_zone.shape.get_rect().has_point(global_pos - sell_zone.global_position)


## A point in the middle of the SELL slot, where a player lets go of a tile.
func sell_zone_centre() -> Vector2:
	return sell_zone.global_position if sell_zone else global_position


# ── Display ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not visible or not is_instance_valid(Globals.player):
		return
	if title_label:
		title_label.text = tr("REPAIR_TITLE")
	if sell_label:
		sell_label.text = tr("SELL_TITLE")

	var refusal: String = repair_refusal()
	if repair_button:
		repair_button.set_button_text(tr("REPAIR_BUTTON"))
		repair_button.disabled = not refusal.is_empty()
		repair_button.update_ui()
	if repair_label:
		var full: bool = repair_amount() <= 0
		repair_label.text = tr("REPAIR_HULL_FULL") if full \
			else tr("REPAIR_HULL_AMOUNT").format({"amount": repair_amount()})
		repair_label.add_theme_color_override("default_color", Globals.white if full else Globals.green)
	_set_tag(repair_price_tag, str(repair_cost()),
		Globals.white if Globals.player.money >= repair_cost() else Globals.red)

	if is_instance_valid(_lifted_tile):
		var sale_refused: String = sale_refusal(_lifted_tile)
		if sale_refused.is_empty():
			sell_hint.text = ""
			_set_tag(sell_price_tag, "+" + str(sell_price(_lifted_tile.tile_resource)), Globals.green)
		else:
			sell_hint.text = sale_refused
			sell_price_tag.visible = false
	else:
		sell_hint.text = tr("SELL_DROP_TILE")
		sell_price_tag.visible = false


func _set_tag(tag: Node2D, text: String, color: Color) -> void:
	if not tag:
		return
	tag.visible = true
	var label: RichTextLabel = tag.get_child(0) as RichTextLabel
	label.text = text
	label.add_theme_color_override("default_color", color)


func _refuse(text: String, at: Vector2) -> void:
	Events.error_text_popup.emit(text, at)
	Events.play_sound.emit(_ERROR_SFX)


func _play_repair_feedback(healed: int) -> void:
	Events.play_sound.emit(_MONEY_SFX)
	if Globals.player.is_inside_tree():
		var anchor: Vector2 = Globals.player.get_juice_anchor()
		Juice.sparkle(self, anchor, Globals.green, 10, 40.0, true)
		Juice.callout_at(self, anchor, "+" + str(healed), Globals.green)
	if repair_button:
		Juice.ring(self, repair_button.global_position + repair_button.size / 2.0, Globals.green, 18.0)


func _play_sale_feedback(price: int) -> void:
	Events.play_sound.emit(_MONEY_SFX)
	var slot: Vector2 = sell_zone_centre()
	Juice.ring(self, slot, Globals.yellow, 16.0)
	Juice.sparkle(self, slot, Globals.yellow, 10, 40.0, true)
	Juice.callout_at(self, slot, "+" + str(price), Globals.yellow)
