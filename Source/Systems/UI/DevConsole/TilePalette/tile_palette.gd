extends Control
## Dev-only palette of every tile and die value, opposite the dev console.
##
## Entries are drag sources rather than buttons: pressing one spawns the real
## [Tile] or [Dice] in the world already attached to the cursor, so the drop is
## handled by the same [Draggable] plumbing a shop purchase goes through. That
## keeps the palette from needing its own placement rules.

const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7.ttf")

const _TILE_RESOURCE_DIR: String = "res://Source/Content/Tiles/TileResources/"

const _DICE_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Textures/Dice/Regular/dice1.png"),
	preload("res://Assets/Textures/Dice/Regular/dice2.png"),
	preload("res://Assets/Textures/Dice/Regular/dice3.png"),
	preload("res://Assets/Textures/Dice/Regular/dice4.png"),
	preload("res://Assets/Textures/Dice/Regular/dice5.png"),
	preload("res://Assets/Textures/Dice/Regular/dice6.png"),
]

const _PANEL_WIDTH: float = 560.0
const _MARGIN: float = 16.0
const _TILE_COLUMNS: int = 3
const _TILE_THUMB_SIZE: float = 96.0
const _DIE_THUMB_SIZE: float = 64.0

const _PANEL_COLOR: Color = Color(0.144, 0.3416, 0.6, 0.843137)
const _ENTRY_COLOR: Color = Color(0.09, 0.22, 0.42, 0.85)

## Tile names are authored with BBCode colour tags for the info panel, which a
## plain Label would render verbatim.
static var _bbcode_regex: RegEx = RegEx.create_from_string("\\[/?[^\\]]*\\]")

var _panel: PanelContainer
var _show_button: Button
var _collapsed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_panel()
	_build_show_button()
	_set_collapsed(false)

	visible = false
	Events.dev_console_toggled.connect(_on_dev_console_toggled)


func _on_dev_console_toggled(is_open: bool) -> void:
	visible = is_open


# ── Layout ───────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Palette"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -(_PANEL_WIDTH + _MARGIN)
	_panel.offset_right = -_MARGIN
	_panel.offset_top = _MARGIN
	_panel.offset_bottom = -_MARGIN
	_panel.add_theme_stylebox_override("panel", _make_style(_PANEL_COLOR))
	add_child(_panel)

	var padding := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		padding.add_theme_constant_override(side, 12)
	_panel.add_child(padding)

	var column := VBoxContainer.new()
	padding.add_child(column)

	column.add_child(_build_header())
	column.add_child(_make_label("DICE", 32))
	column.add_child(_build_dice_row())
	column.add_child(HSeparator.new())
	column.add_child(_make_label("TILES", 32))
	column.add_child(_build_tile_list())


func _build_header() -> Control:
	var header := HBoxContainer.new()

	var title := _make_label("DEV PALETTE", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hide_button := Button.new()
	hide_button.text = "HIDE"
	hide_button.add_theme_font_override("font", _FONT)
	hide_button.add_theme_font_size_override("font_size", 28)
	hide_button.pressed.connect(_set_collapsed.bind(true))
	header.add_child(hide_button)

	return header


func _build_dice_row() -> Control:
	var row := HBoxContainer.new()
	for value: int in range(1, 7):
		var entry: Control = _make_entry(_DICE_TEXTURES[value - 1], "", _DIE_THUMB_SIZE)
		entry.tooltip_text = "Drag a %d out into the cockpit" % value
		entry.gui_input.connect(_on_dice_entry_input.bind(value))
		row.add_child(entry)
	return row


func _build_tile_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var grid := GridContainer.new()
	grid.columns = _TILE_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for tile_resource: TileResource in _load_tile_resources():
		var entry: Control = _make_entry(
			_get_tile_thumbnail(tile_resource), _plain_tile_name(tile_resource), _TILE_THUMB_SIZE
		)
		entry.gui_input.connect(_on_tile_entry_input.bind(tile_resource))
		grid.add_child(entry)

	return scroll


func _build_show_button() -> void:
	_show_button = Button.new()
	_show_button.name = "ShowPalette"
	_show_button.text = "TILES"
	_show_button.anchor_left = 1.0
	_show_button.anchor_right = 1.0
	_show_button.offset_left = -(140.0 + _MARGIN)
	_show_button.offset_right = -_MARGIN
	_show_button.offset_top = _MARGIN
	_show_button.offset_bottom = _MARGIN + 56.0
	_show_button.add_theme_font_override("font", _FONT)
	_show_button.add_theme_font_size_override("font_size", 32)
	_show_button.pressed.connect(_set_collapsed.bind(false))
	add_child(_show_button)


func _set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_panel.visible = not _collapsed
	_show_button.visible = _collapsed


# ── Entry construction ───────────────────────────────────────────────────────

func _make_entry(texture: Texture2D, label_text: String, thumb_size: float) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_STOP
	entry.add_theme_stylebox_override("panel", _make_style(_ENTRY_COLOR))
	entry.mouse_entered.connect(func() -> void: entry.modulate = Color(1.4, 1.4, 1.4))
	entry.mouse_exited.connect(func() -> void: entry.modulate = Color.WHITE)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(box)

	var thumbnail := TextureRect.new()
	thumbnail.texture = texture
	# Tile and die art is 12-24px, so it has to be blown up without smearing.
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumbnail.custom_minimum_size = Vector2(thumb_size, thumb_size)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(thumbnail)

	if not label_text.is_empty():
		var label := _make_label(label_text, 24)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(thumb_size + 32.0, 0)
		box.add_child(label)

	return entry


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(6)
	return style


# ── Content lookup ───────────────────────────────────────────────────────────

func _load_tile_resources() -> Array[TileResource]:
	var resources: Array[TileResource] = []

	var dir: DirAccess = DirAccess.open(_TILE_RESOURCE_DIR)
	if not dir:
		push_warning("TilePalette: could not open " + _TILE_RESOURCE_DIR)
		return resources

	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res: Resource = ResourceLoader.load(_TILE_RESOURCE_DIR + file_name)
		if res is TileResource:
			resources.append(res)

	resources.sort_custom(
		func(a: TileResource, b: TileResource) -> bool:
			return _plain_tile_name(a) < _plain_tile_name(b)
	)
	return resources


func _plain_tile_name(tile_resource: TileResource) -> String:
	return _bbcode_regex.sub(tile_resource.tile_name, "", true).strip_edges()


func _get_tile_thumbnail(tile_resource: TileResource) -> Texture2D:
	if tile_resource.textures and tile_resource.textures.has_animation('default'):
		return tile_resource.textures.get_frame_texture('default', 0)
	return null


# ── Dragging out of the palette ──────────────────────────────────────────────

func _on_tile_entry_input(event: InputEvent, tile_resource: TileResource) -> void:
	if not _is_drag_start(event):
		return
	accept_event()

	if not Globals.tile_grid:
		push_warning("TilePalette: no tile grid to drag a tile into.")
		return

	var tile: Tile = Globals.tile_grid.create_tile(tile_resource)
	# Spawned beside the grid rather than inside it so that the drop can hand the
	# tile over with TileGrid.receive_tile(), exactly as the shop does.
	Globals.tile_grid.get_parent().add_child(tile)
	tile.draggable.drag_ended.connect(_on_dragged_tile_dropped, CONNECT_ONE_SHOT)

	_grab_with_cursor(tile.draggable)


func _on_dice_entry_input(event: InputEvent, value: int) -> void:
	if not _is_drag_start(event):
		return
	accept_event()

	if not Globals.player:
		push_warning("TilePalette: no player to drag a die out of.")
		return

	var die: Dice = Globals.player.dice_scene.instantiate()
	die.value = value
	# Player._process adopts any dragging die into the queue, so the die only has
	# to be parented to the player to become a real part of this turn's hand.
	Globals.player.add_child(die)

	_grab_with_cursor(die.draggable)


func _is_drag_start(event: InputEvent) -> bool:
	return event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT


## Puts a freshly spawned node under the cursor in the same state Draggable sets
## up when a drag begins normally, so its own release handling finishes the drop.
func _grab_with_cursor(draggable: Draggable) -> void:
	var node: Node2D = draggable.get_parent()
	var cursor_position: Vector2 = node.get_global_mouse_position()

	node.global_position = cursor_position
	node.z_index += 10
	node.scale = Vector2(1.3, 1.3)

	draggable.home_position = cursor_position
	draggable.emit_reached_new_home = false
	draggable.state = Draggable.DragState.DRAGGING

	Globals.mouse_is_dragging_something = true


func _on_dragged_tile_dropped(draggable: Draggable, end_position: Vector2) -> void:
	var tile: Tile = draggable.get_parent()
	var grid: TileGrid = Globals.tile_grid

	# The grid can go away mid-drag if the scene changes under the palette.
	if not is_instance_valid(grid):
		tile.queue_free()
		return

	var drop_pos: Vector2i = grid.global_pos_to_grid(end_position)

	# The grid only takes an incoming tile if some cell is free, since an occupied
	# drop cell shunts its current occupant elsewhere. On a full grid, treat a
	# drop onto a cell as a deliberate replacement instead of stranding the new
	# tile in the middle of the cockpit with no home.
	if not grid.is_grid_pos_valid(grid.find_available_grid_pos()):
		if grid.is_grid_pos_valid(drop_pos) and not grid.is_grid_pos_open(drop_pos):
			var displaced: Tile = grid.tile_locations[drop_pos]
			grid.tile_locations.erase(drop_pos)
			displaced.queue_free()
		else:
			tile.queue_free()
			return

	grid.receive_tile(tile, end_position)
