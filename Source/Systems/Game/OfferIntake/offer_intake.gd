class_name OfferIntake
extends RefCounted
## Taking something on offer into the ship: whether it can land where the
## player let it go, and handing it over when it does. Salvage (Reward) and
## the Shop both offer tiles, dice and Grid Slots, and an item has to follow
## the same rules from either. The offer decides the rest: what taking costs,
## what it announces, and what happens to everything left behind.


## Why [param item] can't be taken by letting go of it at
## [param drop_position], or "" if it can. Checked before anything changes
## hands, so a refused item just drifts back to its offer.
static func refusal(item: Node, drop_position: Vector2) -> String:
	var grid: TileGrid = Globals.tile_grid
	# A tile needs a free cell, unless it's let go on a twin it upgrades.
	if item is Tile and not grid.has_free_cell() and not grid.merge_target_at(item, drop_position):
		return "GRID FULL"
	# A slot opens the sealed cell it's dropped on, and only that.
	if item is GridSlot and not grid.is_cell_locked(grid.locked_cell_at(drop_position)):
		return TranslationServer.translate(&"ERROR_PICK_SEALED_CELL")
	return ""


## Makes [param item] the player's, let go at [param drop_position]: a tile
## onto the grid (or into its twin), a die into the hand, a Grid Slot into
## the sealed cell under it, money into the account. Only once refusal() has
## come back empty.
static func take(item: Node, drop_position: Vector2) -> void:
	if item is Tile:
		Globals.tile_grid.receive_tile(item, drop_position)
	elif item is Dice:
		item.reparent(Globals.player, true)
		Globals.player.dice_manager.add(item)
		Globals.player.num_of_dice += 1
	elif item is GridSlot:
		(item as GridSlot).install(Globals.tile_grid.locked_cell_at(drop_position))
	elif item is MoneyPickup:
		(item as MoneyPickup).claim()
