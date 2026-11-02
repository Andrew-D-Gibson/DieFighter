class_name GhostTarget
extends Resource
## One end of a tutorial ghost-cursor demo: the thing the ghost presses on or
## lets go over, named rather than placed.
##
## Dice float, ships bob, the formation re-centres and the grid's layout comes
## from the ship, so nothing a step points at has a fixed spot on screen. Each
## target is looked up again every frame the ghost is out, and a target that
## isn't there right now (no die the player may drag yet, the map tab's view
## not shown) resolves to [constant UNRESOLVED], which the ghost waits out.

enum Kind {
	## [member node_path], from the running scene's root. For fixed UI such as
	## the End Turn button or a tab. A Control points at its middle, an Area2D
	## at its collision shape.
	NODE,
	## The first die in the hand the player is allowed to drag.
	DIE_IN_HAND,
	## [member tile] on the player's grid (or its upgrade), while it can still
	## take a die: a spent or locked-out tile isn't worth demonstrating.
	GRID_TILE,
	## The first empty, unlocked cell of the player's grid.
	OPEN_GRID_CELL,
	## A tile on offer as salvage: [member tile] if set, else any.
	SALVAGE_TILE,
	## The map's right jump arrow, while the map is up and it takes dice.
	MAP_JUMP_ARROW,
	## The middle of the map's draggable view, while the map is up. For the
	## pan gesture, which has no destination of its own: give each end an
	## [member offset].
	MAP_VIEW,
	## A ship in the fight other than the one targeted.
	OTHER_SHIP,
}

const UNRESOLVED: Vector2 = Vector2(INF, INF)

@export var kind: Kind = Kind.NODE
## NODE: the node, from the scene root (e.g. Systems/Player/DiceQueue/EndTurnButton).
@export var node_path: NodePath
## GRID_TILE / SALVAGE_TILE: which tile.
@export var tile: TileResource
## World pixels added to the looked-up point. Only for gestures that aren't
## aimed at one thing, like panning the map; a target with a node should be
## named, not nudged.
@export var offset: Vector2 = Vector2.ZERO


static func is_resolved(point: Vector2) -> bool:
	return point.is_finite()


## Where this target is on screen now, in world coordinates, or UNRESOLVED.
## [param root] is the scene NODE paths start from.
func resolve(root: Node) -> Vector2:
	var anchor: Vector2 = _anchor(root)
	if not is_resolved(anchor):
		return UNRESOLVED
	return anchor + offset


## The thing itself, for the kinds that name one the player picks up or
## presses (a die, a salvage tile, a node), or null. The ghost carries a
## see-through copy of what a drag starts on.
func resolve_node(root: Node) -> Node:
	match kind:
		Kind.NODE:
			if root == null or node_path.is_empty():
				return null
			return root.get_node_or_null(node_path)
		Kind.DIE_IN_HAND:
			return _die_in_hand()
		Kind.SALVAGE_TILE:
			return _salvage_tile()
	return null


func _anchor(root: Node) -> Vector2:
	match kind:
		Kind.NODE, Kind.DIE_IN_HAND, Kind.SALVAGE_TILE:
			return point_of(resolve_node(root))
		Kind.GRID_TILE:
			return _grid_tile()
		Kind.OPEN_GRID_CELL:
			return _open_grid_cell()
		Kind.MAP_JUMP_ARROW:
			return _map_jump_arrow()
		Kind.MAP_VIEW:
			return _map_view()
		Kind.OTHER_SHIP:
			return _other_ship()
	return UNRESOLVED


## The point on [param node] a pointer aims for, or UNRESOLVED when it's
## missing or hidden: the ghost shouldn't point at something the player can't see.
static func point_of(node: Node) -> Vector2:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return UNRESOLVED
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return UNRESOLVED
	if node is Control:
		return (node as Control).get_global_rect().get_center()
	if node is CollisionObject2D:
		# Its shape is what the mouse has to land on, wherever its origin is.
		for child: Node in node.get_children():
			if child is CollisionShape2D:
				return (child as CollisionShape2D).global_position
	if node is Node2D:
		return (node as Node2D).global_position
	return UNRESOLVED


## Whether [param placed] is [param wanted], or what it upgrades into.
static func is_tile(placed: TileResource, wanted: TileResource) -> bool:
	if placed == null or wanted == null:
		return false
	if placed.resource_path == wanted.resource_path:
		return true
	return wanted.upgraded_version != null \
		and placed.resource_path == wanted.upgraded_version.resource_path


func _die_in_hand() -> Dice:
	if not is_instance_valid(Globals.player) or not Globals.player.dice_manager:
		return null
	for die: Dice in Globals.player.dice_manager.queue:
		if is_instance_valid(die) and die.draggable and die.draggable.dragging_allowed \
				and is_resolved(point_of(die)):
			return die
	return null


func _grid_tile() -> Vector2:
	if not is_instance_valid(Globals.tile_grid):
		return UNRESOLVED
	for placed: Tile in Globals.tile_grid.tile_locations.values():
		if not is_instance_valid(placed) or not is_tile(placed.tile_resource, tile):
			continue
		if placed.uses_remaining == 0 or placed.is_locked_out():
			continue
		if placed.can_accept_dice and not placed.can_accept_dice.enabled:
			continue
		return _drop_point(placed)
	return UNRESOLVED


func _open_grid_cell() -> Vector2:
	var grid: TileGrid = Globals.tile_grid
	if not is_instance_valid(grid) or not grid.is_visible_in_tree():
		return UNRESOLVED
	for cell: Vector2i in grid.get_cells():
		if grid.is_grid_pos_open(cell) and not grid.is_cell_locked(cell):
			return grid.grid_to_global_pos(cell)
	return UNRESOLVED


func _salvage_tile() -> Tile:
	if not is_instance_valid(Globals.reward_manager):
		return null
	for offer: Node in Globals.reward_manager.get_children():
		if not offer is Reward or offer.is_queued_for_deletion():
			continue
		for item: Node2D in (offer as Reward).rewards:
			if not is_instance_valid(item) or not item is Tile:
				continue
			if tile and not is_tile((item as Tile).tile_resource, tile):
				continue
			if is_resolved(point_of(item)):
				return item as Tile
	return null


func _map_jump_arrow() -> Vector2:
	var map: Map = Globals.map
	if not is_instance_valid(map) or not is_instance_valid(map.right_arrow_tile):
		return UNRESOLVED
	var arrow: Tile = map.right_arrow_tile
	if arrow.can_accept_dice and not arrow.can_accept_dice.enabled:
		return UNRESOLVED
	if not arrow.is_visible_in_tree():
		return UNRESOLVED
	return _drop_point(arrow)


func _map_view() -> Vector2:
	var map: Map = Globals.map
	if not is_instance_valid(map) or not map.is_visible_in_tree():
		return UNRESOLVED
	return map.pan_area().get_center()


func _other_ship() -> Vector2:
	if not is_instance_valid(Globals.enemy_manager):
		return UNRESOLVED
	var targeted: Enemy = null
	if is_instance_valid(Globals.targeting_computer):
		targeted = Globals.targeting_computer.targeted_enemy
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if not is_instance_valid(ship) or ship == targeted:
			continue
		var point: Vector2 = point_of(ship.clickable_region) if ship.clickable_region else point_of(ship)
		if is_resolved(point):
			return point
	return UNRESOLVED


## Where a die dropped on [param target] is caught: the middle of its drop zone.
static func _drop_point(target: Tile) -> Vector2:
	if not target.is_visible_in_tree():
		return UNRESOLVED
	if target.can_accept_dice and target.can_accept_dice.collision:
		return target.can_accept_dice.collision.global_position
	return target.global_position
