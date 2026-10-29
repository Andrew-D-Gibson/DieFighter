class_name GridSlot
extends Node2D

## A sealed cell's way in: offered as salvage or sold in a shop, and dropped
## on whichever sealed cell of the grid the player wants opened. The grid
## starts smaller than the ship, so where it grows is the player's call.
##
## Whoever offers it (Reward, Shop) decides whether a drop counts, as they do
## for tiles; the slot itself only lights the targets while it's carried and
## flies into the cell it was given.

@export_category('Components')
@export var draggable: Draggable
@export var clickable: Clickable
@export var sprite: Sprite2D

## How long the slot takes to fly into its cell before the plate blows off.
const _INSTALL_SECONDS: float = 0.18


func _ready() -> void:
	draggable.drag_started.connect(_show_targets.bind(true))
	draggable.drag_ended.connect(func(_draggable: Draggable, _at: Vector2) -> void:
		_show_targets(false)
	)
	clickable.clicked.connect(_show_info)


func _exit_tree() -> void:
	# Freed mid-carry (a jump dismisses the offer), the targets go with it.
	if draggable.state == Draggable.DragState.DRAGGING:
		_show_targets(false)


## Opens [param cell] with this slot: it flies into the cell, the plate pops
## off and the slot is gone. The grid owns it from here, since the offer that
## held it is freed the moment something is taken. The cell opens now, not on
## arrival: the checkpoint that taking it triggers mustn't miss it.
func install(cell: Vector2i) -> void:
	var grid: TileGrid = Globals.tile_grid
	grid.unlock_cell(cell, _INSTALL_SECONDS)
	draggable.dragging_allowed = false
	draggable.state = Draggable.DragState.MOVING_WITH_CODE
	reparent(grid, true)
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", grid.grid_to_global_pos(cell), _INSTALL_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.6, _INSTALL_SECONDS)
	tween.tween_callback(queue_free)


func _show_targets(shown: bool) -> void:
	if is_instance_valid(Globals.tile_grid):
		Globals.tile_grid.plates.show_targets(shown)
	# The player needs to see the grid to pick a cell.
	if shown:
		Events.show_systems.emit()


func _show_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=#%s]%s[/color]" % [Globals.green.to_html(false), tr("GRID_SLOT_NAME")]
	info.texture = sprite.texture
	info.bottom_label_text = tr("GRID_SLOT_DESCRIPTION")
	Events.show_info.emit(info)
