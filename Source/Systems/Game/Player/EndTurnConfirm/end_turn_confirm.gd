class_name EndTurnConfirm
extends CanvasLayer
## Asks before the player ends their turn with dice they could still play.
##
## Only the player's own End Turn press comes through here
## (Player.request_end_turn()). The AutoPilot, the tutorial and anything else
## ending the turn in code call Player.end_turn() and are never stopped.

## The Game/confirm_end_turn option. Static, so the options registry can read
## and set it before any Player exists.
static var enabled: bool = true

## What confirming runs: the player's end_turn, as handed to request().
var _end_turn: Callable

@onready var _dialog: ConfirmDialog = $ConfirmDialog


func _ready() -> void:
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.cancelled.connect(_on_cancelled)


## Ends the turn through [param end_turn], asking first if [param player]
## still holds a die some tile would take. A second request while asking
## confirms, so pressing End Turn twice ends the turn.
func request(player: Player, end_turn: Callable) -> void:
	if is_asking():
		_confirm()
		return
	if not enabled or playable_dice(player).is_empty():
		end_turn.call()
		return
	_end_turn = end_turn
	# A die picked up by a click would take the next click as its drop, and
	# the dialog's buttons would never get it.
	for die: Dice in player.dice_manager.queue:
		if is_instance_valid(die) and die.draggable.is_carried():
			die.draggable.put_back()
	_dialog.open(tr("CONFIRM_END_TURN_UNUSED_DICE"))


func is_asking() -> bool:
	return _dialog.visible


## The dice in [param player]'s hand that a tile on the grid would take right
## now. Only grid tiles count, not the map's jump controls, and whichever tab
## is showing: the player can always switch back to their systems.
static func playable_dice(player: Player) -> Array[Dice]:
	var playable: Array[Dice] = []
	var grid: TileGrid = Globals.tile_grid
	if not is_instance_valid(grid):
		return playable
	for die: Dice in player.dice_manager.queue:
		if not is_instance_valid(die) or not die.draggable.dragging_allowed:
			continue
		for tile: Tile in grid.tile_locations.values():
			if _would_take(tile, die):
				playable.append(die)
				break
	return playable


static func _would_take(tile: Tile, die: Dice) -> bool:
	return is_instance_valid(tile) and tile.tile_resource != null \
		and tile.can_accept_dice != null and tile.can_accept_dice.enabled \
		and tile.activation_refusal(die).is_empty()


## Escape backs out rather than opening the pause menu over the question.
func _input(event: InputEvent) -> void:
	if is_asking() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dialog.hide()
		_on_cancelled()


func _confirm() -> void:
	_dialog.hide()
	_on_confirmed()


func _on_confirmed() -> void:
	var end_turn: Callable = _end_turn
	_end_turn = Callable()
	if end_turn.is_valid():
		end_turn.call()


func _on_cancelled() -> void:
	_end_turn = Callable()
