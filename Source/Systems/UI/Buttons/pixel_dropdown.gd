## A dropdown whose list is drawn in the game's own canvas.
##
## Godot's OptionButton opens its list in a popup Window. That window is drawn
## at the screen's resolution rather than through the game camera's zoom, so
## the pixel font in it gets resampled and comes out blurry, and being a window
## it covers everything, the custom mouse cursor included. This keeps the list
## as ordinary Controls in the same canvas as the menu that owns it: it scales
## with the rest of the pixel art, and the cursor draws over it like anything
## else.
##
## Looks come from the theme's OptionButton and PopupMenu entries unless
## overridden, so it matches the rest of the UI with no setup. The API mirrors
## the subset of OptionButton the project uses (select, get_item_text,
## remove_item, item_count, item_selected), plus add_item and clear for lists
## built in code.
class_name PixelDropdown
extends Control

signal item_selected(index: int)

@export var items: Array[String] = []:
	set(value):
		items = value
		_update_main_button_text()

@export var selected: int = -1:
	set(value):
		selected = value
		_update_main_button_text()

@export var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER

@export var normal_style: StyleBox
@export var hover_style: StyleBox
@export var pressed_style: StyleBox
@export var disabled_style: StyleBox
@export var arrow_icon: Texture2D
@export var font_color: Color = Color.WHITE

## Background of the open list. Defaults to the theme's PopupMenu panel.
@export var list_style: StyleBox

## Row under the mouse in the open list.
@export var item_hover_color: Color = Color.html('#343330')

## How far from the button the list opens, in pixels.
const _LIST_GAP: float = 1.0

var item_count: int:
	get:
		return items.size()

@onready var _main_button: Button = $MainButton

## The open list and the full-screen catcher behind it. Both only exist while
## the list is open. See _open_popup() for where they live.
var _popup_panel: PanelContainer
var _click_catcher: Control


func _ready() -> void:
	_style_main_button()
	_update_main_button_text()
	update_minimum_size()


## Sized by its button, like an OptionButton, so it lines up with the rest of
## a row instead of collapsing to whatever minimum the scene gave it.
func _get_minimum_size() -> Vector2:
	if not _main_button:
		return Vector2.ZERO
	return _main_button.get_combined_minimum_size()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			# The list isn't under this node, so it doesn't vanish with it:
			# close it when the dropdown goes, on a tab switch or the menu
			# closing. Checked a frame later, once the whole subtree has
			# settled on being hidden.
			_close_if_hidden.call_deferred()
		NOTIFICATION_EXIT_TREE:
			_close_popup()


## --- OptionButton-compatible API ---

func select(index: int) -> void:
	selected = index


func get_item_text(index: int) -> String:
	if index < 0 or index >= items.size():
		return ""
	return items[index]


func add_item(text: String) -> void:
	items.append(text)


func remove_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	items.remove_at(index)
	if selected == index:
		selected = -1
	elif selected > index:
		selected -= 1
	_update_main_button_text()


func clear() -> void:
	items.clear()
	selected = -1


## --- Internals ---

## The closed dropdown is laid out the way OptionButton does it: the value's
## text, and the arrow pinned to the right-hand edge.
func _style_main_button() -> void:
	var styles: Dictionary[String, StyleBox] = {
		"normal": normal_style,
		"hover": hover_style,
		"pressed": pressed_style,
		"disabled": disabled_style,
		"focus": pressed_style,
	}
	for style_name: String in styles:
		var style: StyleBox = styles[style_name]
		if not style:
			style = get_theme_stylebox(style_name, "OptionButton")
		_main_button.add_theme_stylebox_override(style_name, style)

	_main_button.add_theme_color_override("font_color", font_color)
	_main_button.clip_text = true
	_main_button.alignment = alignment
	_main_button.icon = arrow_icon if arrow_icon else get_theme_icon("arrow", "OptionButton")
	_main_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_main_button.pressed.connect(_on_main_button_pressed)


func _update_main_button_text() -> void:
	if not is_node_ready():
		return
	if selected >= 0 and selected < items.size():
		_main_button.text = items[selected]
	else:
		_main_button.text = ""


func _on_main_button_pressed() -> void:
	if _popup_panel:
		_close_popup()
	else:
		_open_popup()


## Builds the list as the last children of the scene this dropdown belongs to
## (the options menu, say) rather than under the dropdown itself. Godot hands a
## click to Controls in tree order, not draw order, so a list nested inside
## one tab would lose clicks to anything later in the menu that it happens to
## cover (the Close button). Last in the menu, it is first in line.
func _open_popup() -> void:
	var host: Node = owner if owner else get_parent()
	var visible_rect: Rect2 = _visible_canvas_rect()

	# Covers the whole screen, so a click anywhere else closes the list
	# instead of reaching whatever is underneath.
	_click_catcher = Control.new()
	_click_catcher.top_level = true
	_click_catcher.z_index = 99
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.gui_input.connect(_on_click_catcher_gui_input)
	host.add_child(_click_catcher)
	_click_catcher.global_position = visible_rect.position
	_click_catcher.size = visible_rect.size

	# Top level keeps whatever container `host` happens to be from laying the
	# list out, and it from inheriting the host's transform.
	_popup_panel = PanelContainer.new()
	_popup_panel.top_level = true
	_popup_panel.z_index = 100
	_popup_panel.add_theme_stylebox_override(
		"panel", list_style if list_style else get_theme_stylebox("panel", "PopupMenu")
	)
	_popup_panel.custom_minimum_size.x = _main_button.size.x
	_popup_panel.add_child(_build_item_list())
	host.add_child(_popup_panel)
	_popup_panel.reset_size()

	# Open downward, or upward when the list would run off the bottom of the
	# screen. Whole pixels only: anything else smears under the camera zoom.
	var origin: Vector2 = _main_button.global_position
	var position_below: Vector2 = origin + Vector2(0, _main_button.size.y + _LIST_GAP)
	if position_below.y + _popup_panel.size.y > visible_rect.end.y:
		position_below.y = origin.y - _LIST_GAP - _popup_panel.size.y
	_popup_panel.global_position = position_below.round()


func _build_item_list() -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)

	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = item_hover_color
	hover.anti_aliasing = false
	_set_row_margins(hover)
	var normal: StyleBoxEmpty = StyleBoxEmpty.new()
	_set_row_margins(normal)

	# The same radio marks the native list used, so the current value reads
	# at a glance.
	var checked: Texture2D = get_theme_icon("radio_checked", "PopupMenu")
	var unchecked: Texture2D = get_theme_icon("radio_unchecked", "PopupMenu")

	for i: int in range(items.size()):
		var row: Button = Button.new()
		row.text = items[i]
		row.icon = checked if i == selected else unchecked
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", get_theme_font_size("font_size", "PopupMenu"))
		row.add_theme_stylebox_override("normal", normal)
		row.add_theme_stylebox_override("hover", hover)
		row.add_theme_stylebox_override("pressed", hover)
		row.add_theme_stylebox_override("hover_pressed", hover)
		row.pressed.connect(_on_item_button_pressed.bind(i))
		list.add_child(row)
	return list


func _set_row_margins(style: StyleBox) -> void:
	style.content_margin_left = 3
	style.content_margin_right = 5
	style.content_margin_top = 0
	style.content_margin_bottom = 0


func _close_popup() -> void:
	if is_instance_valid(_popup_panel):
		_popup_panel.queue_free()
	if is_instance_valid(_click_catcher):
		_click_catcher.queue_free()
	_popup_panel = null
	_click_catcher = null


func _close_if_hidden() -> void:
	if is_inside_tree() and not is_visible_in_tree():
		_close_popup()


## The part of this canvas currently on screen, in the same coordinates as
## global_position.
func _visible_canvas_rect() -> Rect2:
	return get_canvas_transform().affine_inverse() * get_viewport_rect()


func _on_click_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_popup()


func _on_item_button_pressed(index: int) -> void:
	selected = index
	_close_popup()
	item_selected.emit(index)
