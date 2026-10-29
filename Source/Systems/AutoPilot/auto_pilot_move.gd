class_name AutoPilotMove
extends RefCounted
## One thing the AutoPilot could do right now, through the same entry points a
## player's input reaches: drop a die from the hand on a tile, retarget the
## targeting computer, flip between the systems and map tabs, take a choice
## from a salvage offer, buy from the shop, buy a repair or sell a tile at a
## repair station, drag a tile to another cell out of a fight, or press End
## Turn.
##
## Moves are listed fresh every time the AutoPilot acts and used at once, so
## they hold live node references rather than ids.

## Append only: transcripts and replays name kinds by their position.
enum Kind { PLACE_DIE, TARGET, VIEW_MAP, VIEW_SYSTEMS, END_TURN, CLAIM, BUY, REPAIR, SELL, MOVE_TILE }

var kind: Kind
var die: Dice
var tile: Tile
var enemy: Enemy
## A salvage choice (CLAIM) or shop stock (BUY): a Tile, a Dice or a
## MoneyPickup. For SELL, the grid tile.
var item: Node2D
var price: int = 0
## Where a claimed or bought tile is let go (an open cell) or a Grid Slot
## (a sealed one), or where MOVE_TILE drags its tile. (-1, -1) for a claim
## or purchase lets it go where a player in a hurry would: the first free
## cell, the first sealed one.
var cell: Vector2i = Vector2i(-1, -1)


static func place_die(on_die: Dice, on_tile: Tile) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = Kind.PLACE_DIE
	move.die = on_die
	move.tile = on_tile
	return move


static func target(ship: Enemy) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = Kind.TARGET
	move.enemy = ship
	return move


static func claim(choice: Node2D) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = Kind.CLAIM
	move.item = choice
	return move


static func buy(stock: Node2D, cost: int) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = Kind.BUY
	move.item = stock
	move.price = cost
	return move


static func repair(cost: int) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = Kind.REPAIR
	move.price = cost
	return move


## [param pay] is what the station pays, so a policy can weigh it.
static func sell(grid_tile: Tile, pay: int) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = Kind.SELL
	move.item = grid_tile
	move.tile = grid_tile
	move.price = pay
	return move


## Drags [param grid_tile] to [param to_cell], swapping with any tile there.
static func move_tile(grid_tile: Tile, to_cell: Vector2i) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = Kind.MOVE_TILE
	move.tile = grid_tile
	move.cell = to_cell
	return move


static func end_turn() -> AutoPilotMove:
	return _of_kind(Kind.END_TURN)


static func _of_kind(move_kind: Kind) -> AutoPilotMove:
	var move := AutoPilotMove.new()
	move.kind = move_kind
	return move


## Every move open to the player at this moment. Only dice a player could pick
## up count, and only tiles that would take the die, so a policy choosing at
## random still plays legally. Illegal drops are a separate kind of fuzzing.
static func list_legal() -> Array[AutoPilotMove]:
	var moves: Array[AutoPilotMove] = []
	if Globals.player.can_end_turn():
		moves.append(end_turn())

	var tiles: Array[Tile] = _tiles_taking_dice()
	for hand_die: Dice in dice_in_hand():
		for candidate: Tile in tiles:
			if candidate.activation_refusal(hand_die).is_empty():
				moves.append(place_die(hand_die, candidate))

	if Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
		for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
			if ship != Globals.targeting_computer.targeted_enemy:
				moves.append(target(ship))

	# A tile with no free cell to go to is refused, as a player can see,
	# unless it can upgrade its twin; so is a Grid Slot with no sealed cell
	# left to open.
	for choice: Node2D in _salvage_on_offer():
		if _has_somewhere_to_go(choice):
			moves.append(claim(choice))
	if is_instance_valid(Globals.shop) and Globals.shop.is_visible_in_tree():
		for stock: Node in Globals.shop.item_to_shop_index:
			var cost: int = Globals.shop.price_of(stock)
			if cost >= 0 and cost <= Globals.player.money and _can_pick_up(stock as Node2D) \
			and _has_somewhere_to_go(stock as Node2D):
				moves.append(buy(stock as Node2D, cost))

	moves.append_array(_repair_station_moves())
	moves.append_array(_rearrangements())

	# The map's controls are tiles, but only while its tab is showing.
	moves.append(_of_kind(Kind.VIEW_SYSTEMS if Globals.map.visible else Kind.VIEW_MAP))
	return moves


func perform() -> void:
	match kind:
		Kind.PLACE_DIE:
			# The moment a real drag lets go: Dice._check_for_acceptor offers
			# the die to every acceptor under the drop point.
			die.draggable.drag_ended.emit(die.draggable, tile.can_accept_dice.collision.global_position)
		Kind.TARGET:
			Globals.targeting_computer.target_enemy(enemy)
		# The tab buttons call these same MainViewer handlers.
		Kind.VIEW_MAP:
			Events.show_map.emit()
		Kind.VIEW_SYSTEMS:
			Events.show_systems.emit()
		Kind.END_TURN:
			Globals.player.end_turn()
		# Dragged out of the offer or off the shelf and let go: a tile over
		# the grid, a Grid Slot over a sealed cell, anything else over the hand.
		Kind.CLAIM, Kind.BUY:
			var draggable: Draggable = item.get("draggable")
			draggable.drag_ended.emit(draggable, _drop_point_for(item, cell))
		# The button's own handler.
		Kind.REPAIR:
			Globals.repair_station.repair()
		# Dragged off the grid and let go over the SELL slot.
		Kind.SELL:
			tile.draggable.drag_ended.emit(tile.draggable, Globals.repair_station.sell_zone_centre())
		# Picked up off the grid and let go over another cell.
		Kind.MOVE_TILE:
			tile.draggable.drag_ended.emit(tile.draggable, Globals.tile_grid.grid_to_global_pos(cell))


## A readable, replay-stable record of the move for the transcript.
func describe() -> Dictionary:
	match kind:
		Kind.PLACE_DIE:
			return {
				"move": "place_die",
				"face": die.value,
				"holographic": die.holographic,
				"tile": tile.tile_resource.tile_name,
				"cell": _tile_cell(tile),
			}
		Kind.TARGET:
			return {"move": "target", "ship": AutoPilotSnapshot.ship_label(enemy)}
		Kind.REPAIR:
			return {"move": "repair", "price": price}
		Kind.SELL:
			return {"move": "sell", "item": item_name(tile), "price": price, "cell": _tile_cell(tile)}
		Kind.MOVE_TILE:
			return {"move": "move_tile", "item": item_name(tile), "from": _tile_cell(tile),
				"cell": "%d,%d" % [cell.x, cell.y]}
		Kind.CLAIM, Kind.BUY:
			var entry: Dictionary = {"move": Kind.keys()[kind].to_lower(), "item": item_name(item)}
			if kind == Kind.BUY:
				entry["price"] = price
			if cell != Vector2i(-1, -1):
				entry["cell"] = "%d,%d" % [cell.x, cell.y]
			return entry
	return {"move": Kind.keys()[kind].to_lower()}


## A tile by name, a die, a grid slot, or credits by amount.
static func item_name(thing: Node) -> String:
	if thing is Tile:
		return DebugLogFormat.label(thing).trim_prefix("[").trim_suffix("]")
	if thing is MoneyPickup:
		return "%d credits" % (thing as MoneyPickup).amount
	if thing is GridSlot:
		return "grid slot"
	return "die"


## A repair, if one can be had, and every tile the station would buy, while
## its panel is open. Selling needs the grid on show, as it does for a player.
static func _repair_station_moves() -> Array[AutoPilotMove]:
	var moves: Array[AutoPilotMove] = []
	var station: RepairStation = Globals.repair_station
	if not is_instance_valid(station) or not station.is_visible_in_tree():
		return moves
	if station.repair_refusal().is_empty():
		moves.append(repair(station.repair_cost()))
	if not Globals.tile_grid.is_visible_in_tree():
		return moves
	for cell: Vector2i in Globals.tile_grid.tile_locations:
		var grid_tile: Tile = Globals.tile_grid.tile_locations[cell]
		if _can_pick_up(grid_tile) and station.sale_refusal(grid_tile).is_empty():
			moves.append(sell(grid_tile, station.sell_price(grid_tile.tile_resource)))
	return moves


static func _has_somewhere_to_go(thing: Node2D) -> bool:
	if thing is Tile:
		return Globals.tile_grid.has_free_cell() or AutoPilotBuild.twin_for((thing as Tile).tile_resource) != null
	if thing is GridSlot:
		return Globals.tile_grid.has_locked_cell()
	return true


## Every drag of a grid tile to another cell, out of a fight with the grid on
## show: tiles are locked in place for as long as a fight lasts.
static func _rearrangements() -> Array[AutoPilotMove]:
	var moves: Array[AutoPilotMove] = []
	var grid: TileGrid = Globals.tile_grid
	if Tile.grid_locked() or not grid.is_visible_in_tree():
		return moves
	var cells: Array[Vector2i] = grid.get_cells()
	for from: Vector2i in grid.tile_locations:
		var grid_tile: Tile = grid.tile_locations[from]
		if not _can_pick_up(grid_tile):
			continue
		for to: Vector2i in cells:
			if to != from:
				moves.append(move_tile(grid_tile, to))
	return moves


## Choices in the salvage offers on show.
static func _salvage_on_offer() -> Array[Node2D]:
	var choices: Array[Node2D] = []
	if not is_instance_valid(Globals.reward_manager):
		return choices
	for child: Node in Globals.reward_manager.get_children():
		var offer: Reward = child as Reward
		if not offer or not offer.can_take():
			continue
		for choice: Node2D in offer.rewards:
			if _can_pick_up(choice):
				choices.append(choice)
	return choices


static func _can_pick_up(thing: Node2D) -> bool:
	if not is_instance_valid(thing) or thing.is_queued_for_deletion() or not thing.is_visible_in_tree():
		return false
	var draggable: Draggable = thing.get("draggable")
	return draggable != null and draggable.dragging_allowed \
		and draggable.state == Draggable.DragState.DEFAULT


## Where a player would let go of [param thing]: a tile on [param at] if it's
## an open, empty cell or its twin, else the first empty cell, else its twin
## (list_legal() offers no tile with neither); a Grid Slot on [param at] if
## it's sealed, else the first sealed cell; anything else on the hand. All
## are well clear of the offer and the shelves.
static func _drop_point_for(thing: Node2D, at: Vector2i = Vector2i(-1, -1)) -> Vector2:
	var grid: TileGrid = Globals.tile_grid
	if thing is Tile:
		var resource: TileResource = (thing as Tile).tile_resource
		var there: Tile = grid.tile_locations.get(at)
		var takes_it: bool = grid.is_grid_pos_valid(at) \
			and (there == null or (is_instance_valid(there) and there.can_merge(resource)))
		if not takes_it:
			at = grid.find_available_grid_pos()
			if not grid.is_grid_pos_valid(at):
				at = grid.find_tile_pos(AutoPilotBuild.twin_for(resource))
		return grid.grid_to_global_pos(at)
	if thing is GridSlot:
		if not grid.is_cell_locked(at):
			at = grid.get_locked_cells()[0]
		return grid.grid_to_global_pos(at)
	return Globals.player.dice_manager.global_position


## The dice a player could pick up right now.
static func dice_in_hand() -> Array[Dice]:
	var dice: Array[Dice] = []
	for hand_die: Dice in Globals.player.dice_manager.queue:
		if is_instance_valid(hand_die) and hand_die.draggable.dragging_allowed \
		and hand_die.draggable.state == Draggable.DragState.DEFAULT:
			dice.append(hand_die)
	return dice


static func _tiles_taking_dice() -> Array[Tile]:
	var tiles: Array[Tile] = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for acceptor: CanAcceptDice in tree.get_nodes_in_group("CanAcceptDice"):
		var owner_tile: Tile = acceptor.owner as Tile
		if owner_tile and acceptor.enabled and acceptor.is_visible_in_tree():
			tiles.append(owner_tile)
	return tiles


## Grid cell for a grid tile; the map's controls and anything else off the
## grid are told apart by name.
static func _tile_cell(on_tile: Tile) -> String:
	var cell: Vector2i = Globals.tile_grid.find_tile_pos(on_tile)
	if cell == Vector2i(-1, -1):
		return "off_grid"
	return "%d,%d" % [cell.x, cell.y]
