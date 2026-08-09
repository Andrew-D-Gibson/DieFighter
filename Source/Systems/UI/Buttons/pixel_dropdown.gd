## A dropdown that stays inside the normal Control/Canvas tree instead of
## opening a separate Window (unlike the built-in OptionButton popup).
## This keeps it pixel-perfect and prevents it from rendering above the
## custom mouse cursor. API intentionally mirrors the subset of OptionButton
## used elsewhere in the project (select, get_item_text, remove_item,
## item_selected) so callers don't need to change.
class_name PixelDropdown
extends Control

signal item_selected(index: int)

@export var items: Array[String] = []
@export var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER

@export var normal_style: StyleBox
@export var hover_style: StyleBox
@export var pressed_style: StyleBox
@export var disabled_style: StyleBox
@export var arrow_icon: Texture2D
@export var font_color: Color = Color.WHITE

var selected: int = -1:
	set(value):
		selected = value
		_update_main_button_text()

@onready var _main_button: Button = $MainButton
@onready var _arrow_icon: TextureRect = $MainButton/ArrowIcon
@onready var _popup_panel: PanelContainer = $PopupPanel
@onready var _item_list: VBoxContainer = $PopupPanel/ItemList
@onready var _click_catcher: Control = $ClickCatcher

var _item_buttons: Array[Button] = []


func _ready() -> void:
	_popup_panel.top_level = true
	_popup_panel.hide()
	_popup_panel.z_index = 100

	_click_catcher.top_level = true
	_click_catcher.hide()
	_click_catcher.z_index = 99
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.gui_input.connect(_on_click_catcher_gui_input)

	if normal_style:
		_main_button.add_theme_stylebox_override("normal", normal_style)
	if hover_style:
		_main_button.add_theme_stylebox_override("hover", hover_style)
	if pressed_style:
		_main_button.add_theme_stylebox_override("pressed", pressed_style)
	if disabled_style:
		_main_button.add_theme_stylebox_override("disabled", disabled_style)
	_main_button.add_theme_color_override("font_color", font_color)
	_main_button.clip_text = true
	_main_button.alignment = alignment
	_main_button.pressed.connect(_on_main_button_pressed)

	_arrow_icon.texture = arrow_icon
	_arrow_icon.visible = arrow_icon != null

	_rebuild_item_buttons()
	_update_main_button_text()


func _rebuild_item_buttons() -> void:
	for child: Button in _item_buttons:
		child.queue_free()
	_item_buttons.clear()

	for i: int in range(items.size()):
		var item_button: Button = Button.new()
		item_button.text = items[i]
		item_button.flat = true
		item_button.focus_mode = Control.FOCUS_NONE
		item_button.add_theme_color_override("font_color", font_color)
		item_button.add_theme_font_size_override("font_size", _main_button.get_theme_font_size("font_size"))
		item_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		if hover_style:
			item_button.add_theme_stylebox_override("hover", hover_style)
		if pressed_style:
			item_button.add_theme_stylebox_override("pressed", pressed_style)
		if hover_style:
			item_button.add_theme_stylebox_override("focus", hover_style)
		item_button.pressed.connect(_on_item_button_pressed.bind(i))
		_item_list.add_child(item_button)
		_item_buttons.append(item_button)


func _update_main_button_text() -> void:
	if not is_node_ready():
		return
	if selected >= 0 and selected < items.size():
		_main_button.text = items[selected]
	else:
		_main_button.text = ""


func _on_main_button_pressed() -> void:
	if _popup_panel.visible:
		_close_popup()
	else:
		_open_popup()


func _open_popup() -> void:
	_click_catcher.global_position = Vector2.ZERO
	_click_catcher.size = get_viewport_rect().size
	_click_catcher.show()

	_popup_panel.global_position = _main_button.global_position + Vector2(0, _main_button.size.y)
	_popup_panel.size = Vector2.ZERO
	_popup_panel.show()
	_popup_panel.move_to_front()


func _close_popup() -> void:
	_popup_panel.hide()
	_click_catcher.hide()


func _on_click_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_popup()


func _on_item_button_pressed(index: int) -> void:
	selected = index
	_close_popup()
	item_selected.emit(index)


## --- OptionButton-compatible API ---

func select(index: int) -> void:
	selected = index


func get_item_text(index: int) -> String:
	if index < 0 or index >= items.size():
		return ""
	return items[index]


func remove_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	items.remove_at(index)
	if selected == index:
		selected = -1
	elif selected > index:
		selected -= 1
	if is_node_ready():
		_rebuild_item_buttons()
		_update_main_button_text()


var item_count: int:
	get:
		return items.size()
