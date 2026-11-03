extends "res://test/helpers/die_fighter_test.gd"
## Where PixelDropdown opens its list: under the button when there's room,
## and never off the screen, however long the list or wherever the button.

const DROPDOWN_SCENE: PackedScene = preload("res://Source/Systems/UI/Buttons/pixel_dropdown.tscn")

var host: Control
var dropdown: PixelDropdown


func before_each() -> void:
	super()
	host = Control.new()
	add_child_autofree(host)
	dropdown = DROPDOWN_SCENE.instantiate()
	dropdown.size = Vector2(40, 16)
	host.add_child(dropdown)


func _give_items(count: int, selected: int) -> void:
	var items: Array[String] = []
	for i: int in range(count):
		items.append("Item %d" % i)
	dropdown.items = items
	dropdown.select(selected)


func _open_at(y_fraction: float) -> PanelContainer:
	var screen: Rect2 = dropdown._visible_canvas_rect()
	dropdown.global_position = Vector2(screen.get_center().x, screen.position.y + screen.size.y * y_fraction)
	dropdown._open_popup()
	return dropdown._popup_panel


func _assert_on_screen(panel: PanelContainer) -> void:
	var screen: Rect2 = dropdown._visible_canvas_rect()
	assert_true(screen.encloses(panel.get_global_rect()),
		"list %s should be inside the screen %s" % [panel.get_global_rect(), screen])


func test_short_list_opens_under_the_button() -> void:
	_give_items(4, 1)
	var panel: PanelContainer = _open_at(0.25)
	await wait_process_frames(2)

	var button: Rect2 = dropdown._main_button.get_global_rect()
	assert_gt(panel.global_position.y, button.end.y - 0.5)
	_assert_on_screen(panel)


func test_short_list_near_the_bottom_opens_over_the_button() -> void:
	_give_items(4, 1)
	var panel: PanelContainer = _open_at(0.95)
	await wait_process_frames(2)

	var button: Rect2 = dropdown._main_button.get_global_rect()
	assert_lt(panel.get_global_rect().end.y, button.position.y + 0.5)
	_assert_on_screen(panel)


## The bug this guards: a list too tall for either side used to flip upward
## and run off the top, hiding its first entries.
func test_list_too_tall_for_either_side_stays_on_screen_with_the_value_on_the_button() -> void:
	var rows_per_screen: int = _rows_per_screen()
	_give_items(rows_per_screen * 3 / 4, rows_per_screen * 3 / 8)
	var panel: PanelContainer = _open_at(0.5)
	await wait_process_frames(2)

	_assert_on_screen(panel)
	var rows: Array[Node] = panel.find_children("*", "Button", true, false)
	var current_row: Button = rows[dropdown.selected]
	var button: Rect2 = dropdown._main_button.get_global_rect()
	assert_almost_eq(current_row.get_global_rect().get_center().y, button.get_center().y, 1.0)


func test_list_taller_than_the_screen_wraps_into_columns() -> void:
	_give_items(_rows_per_screen() * 3, 0)
	var panel: PanelContainer = _open_at(0.5)
	await wait_process_frames(2)

	_assert_on_screen(panel)
	var columns: Array[Node] = panel.find_children("*", "VBoxContainer", true, false)
	assert_gt(columns.size(), 2)


func test_escape_closes_the_list_without_changing_the_value() -> void:
	_give_items(4, 2)
	_open_at(0.25)
	watch_signals(dropdown)

	var escape: InputEventAction = InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	dropdown._unhandled_input(escape)

	assert_null(dropdown._popup_panel)
	assert_eq(dropdown.selected, 2)
	assert_signal_not_emitted(dropdown, "item_selected")


func _rows_per_screen() -> int:
	_give_items(1, 0)
	var panel: PanelContainer = _open_at(0.5)
	var row_height: float = panel.find_children("*", "Button", true, false)[0].get_combined_minimum_size().y
	dropdown._close_popup()
	return floori(dropdown._visible_canvas_rect().size.y / row_height)


## A list text says more while choosing; the closed button keeps the item's
## own text. A row can have its own font, a note stays in the list's font
## beside it, and clear() forgets all three.
func test_list_text_font_and_note_apply_to_the_open_list_only() -> void:
	_give_items(3, 1)
	var font: FontVariation = FontVariation.new()
	dropdown.set_item_list_text(1, "Item 1 long")
	dropdown.set_item_font(2, font, 12)
	dropdown.set_item_font(0, font, 12)
	dropdown.set_item_note(0, "(note)")
	var rows: Array[Button] = dropdown._build_rows()
	assert_eq(rows[1].text, "Item 1 long")
	assert_eq(dropdown._main_button.text, "Item 1", "the button shows the plain item")
	assert_eq(rows[2].get_theme_font("font"), font)
	assert_eq(rows[2].get_theme_font_size("font_size"), 12)
	assert_false(rows[1].has_theme_font_override("font"))
	var parts: Array[Node] = rows[0].find_children("*", "Label", true, false)
	assert_eq(parts.size(), 2, "text and note as two parts")
	assert_eq((parts[0] as Label).text, "Item 0")
	assert_eq((parts[0] as Label).get_theme_font("font"), font)
	assert_eq((parts[1] as Label).text, "(note)")
	assert_eq((parts[1] as Label).get_theme_font("font"), dropdown.get_theme_font("font", "Button"))
	assert_eq(dropdown.list_row_text(0), "Item 0 (note)")
	assert_gt(rows[0].get_combined_minimum_size().x, 0.0, "the row is as wide as its parts")
	for row: Button in rows:
		row.free()
	dropdown.clear()
	_give_items(3, 1)
	rows = dropdown._build_rows()
	assert_eq(rows[1].text, "Item 1")
	assert_eq(rows[0].text, "Item 0")
	assert_false(rows[2].has_theme_font_override("font"))
	for row: Button in rows:
		row.free()
