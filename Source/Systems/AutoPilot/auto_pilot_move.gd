class_name AutoPilotMove
extends RefCounted
## One thing the AutoPilot could do right now, through the same entry points a
## player's input reaches: drop a die from the hand on a tile, retarget the
## targeting computer, flip between the systems and map tabs, or press End Turn.
##
## Moves are listed fresh every time the AutoPilot acts and used at once, so
## they hold live node references rather than ids.

enum Kind { PLACE_DIE, TARGET, VIEW_MAP, VIEW_SYSTEMS, END_TURN }

var kind: Kind
var die: Dice
var tile: Tile
var enemy: Enemy


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
	return {"move": Kind.keys()[kind].to_lower()}


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
