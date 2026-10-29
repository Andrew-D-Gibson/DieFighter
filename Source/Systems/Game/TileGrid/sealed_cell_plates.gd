class_name SealedCellPlates
extends Node2D
## The plates drawn over a TileGrid's sealed cells, and the brackets that
## light them up as targets while a Grid Slot is being carried.
##
## Only the look: the grid decides which cells are sealed and tells this node
## whenever that changes (show_cells(), blow_off()). It lives first among the
## grid's children, so the plates draw under the tiles but over the panel art.

## How much bigger the bracket over the sealed cell under the pointer draws.
const _HOVERED_TARGET_SCALE: float = 1.15
const _CELL_OPENED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")
const _TARGET: String = "Target"

var _grid: TileGrid
## The plate over each sealed cell.
var _plates: Dictionary[Vector2i, Sprite2D] = {}
## True while a Grid Slot is being carried, so the sealed cells show as targets.
var _showing_targets: bool = false
var _target_tween: Tween
## The sealed cell under the pointer while targets are showing.
var _hovered: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	_grid = get_parent() as TileGrid
	assert(_grid, "SealedCellPlates belongs under a TileGrid")
	# Runs only while targets are showing.
	set_process(false)


## Puts a plate over each of [param cells] and takes away any others.
func show_cells(cells: Array[Vector2i]) -> void:
	for plate: Sprite2D in _plates.values():
		if is_instance_valid(plate):
			plate.queue_free()
	_plates.clear()
	for cell: Vector2i in cells:
		_plates[cell] = _make_plate(cell)


## The plate over [param cell] pops off the hull after [param delay] seconds
## (a slot opening it flying in), the way a reward choice pops when it's left
## behind: squash, stretch, gone, with sparks where it was.
func blow_off(cell: Vector2i, delay: float = 0.0) -> void:
	var plate: Sprite2D = _plates.get(cell)
	_plates.erase(cell)
	if not is_instance_valid(plate):
		return
	plate.get_node(_TARGET).hide()
	var tween: Tween = plate.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(Events.play_sound.emit.bind(_CELL_OPENED_SFX))
	tween.tween_property(plate, "scale", Vector2(1.3, 0.7), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(plate, "scale", Vector2(0.6, 1.5), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(plate, "scale", Vector2(0.0, 1.8), 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# On the grid rather than here, so the sparks fly over the tiles nearby.
	tween.tween_callback(func() -> void:
		Juice.sparkle(_grid, plate.global_position, Globals.green, 10, 40.0)
		Juice.ring(_grid, plate.global_position, Globals.green)
	)
	tween.tween_callback(plate.queue_free)


## Lights every sealed cell as a place to drop the Grid Slot being carried.
func show_targets(shown: bool) -> void:
	_showing_targets = shown
	_hovered = Vector2i(-1, -1)
	set_process(shown)
	if _target_tween:
		_target_tween.kill()
	for plate: Sprite2D in _plates.values():
		if not is_instance_valid(plate):
			continue
		var target: Sprite2D = plate.get_node(_TARGET)
		target.visible = shown
		target.scale = Vector2.ONE
	if not shown or _plates.is_empty():
		return
	# One tween breathes every bracket together, so they read as one set.
	_target_tween = create_tween().set_loops()
	_target_tween.tween_method(_set_target_alpha, 1.0, 0.45, 0.45) \
		.set_trans(Tween.TRANS_SINE)
	_target_tween.tween_method(_set_target_alpha, 0.45, 1.0, 0.45) \
		.set_trans(Tween.TRANS_SINE)


## Whether [param cell]'s bracket is showing.
func is_target_shown(cell: Vector2i) -> bool:
	var plate: Sprite2D = _plates.get(cell)
	return is_instance_valid(plate) and plate.get_node(_TARGET).visible


func _set_target_alpha(alpha: float) -> void:
	for cell: Vector2i in _plates:
		var plate: Sprite2D = _plates[cell]
		if is_instance_valid(plate):
			plate.get_node(_TARGET).modulate.a = 1.0 if cell == _hovered else alpha


func _process(_delta: float) -> void:
	if not _showing_targets:
		set_process(false)
		return
	var hovered: Vector2i = _grid.locked_cell_at(InputManager.pointer_position(get_viewport()))
	if hovered == _hovered:
		return
	_hovered = hovered
	for cell: Vector2i in _plates:
		var plate: Sprite2D = _plates[cell]
		if is_instance_valid(plate):
			var target: Sprite2D = plate.get_node(_TARGET)
			target.scale = Vector2.ONE * (_HOVERED_TARGET_SCALE if cell == hovered else 1.0)


func _make_plate(cell: Vector2i) -> Sprite2D:
	var plate: Sprite2D = Sprite2D.new()
	plate.texture = _grid.locked_cell_texture
	plate.position = _grid.grid_to_local_pos(cell)
	var target: Sprite2D = Sprite2D.new()
	target.name = _TARGET
	target.texture = _grid.slot_target_texture
	target.visible = _showing_targets
	plate.add_child(target)
	add_child(plate)
	return plate
