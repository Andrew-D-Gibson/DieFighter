class_name ScenarioLabPicker
extends Control
## The Scenario Lab's full list: every scenario grouped by kind, each with how
## many of its ship states have been seen. Picking one starts a lab run of it.

const _PANEL_SIZE: Vector2 = Vector2(1240, 900)
const _COLUMNS: int = 3

var _list: VBoxContainer
var _summary: Label
var _reset_button: Button
## Reset asks twice: the coverage it wipes may be days of testing.
var _reset_armed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.55)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.gui_input.connect(_on_dimmer_input)
	add_child(dimmer)

	var frame: PanelContainer = ScenarioLabUI.panel(ScenarioLabUI.PANEL_COLOR, 16.0)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -_PANEL_SIZE.x / 2.0
	frame.offset_right = _PANEL_SIZE.x / 2.0
	frame.offset_top = -_PANEL_SIZE.y / 2.0
	frame.offset_bottom = _PANEL_SIZE.y / 2.0
	add_child(frame)

	var content: VBoxContainer = ScenarioLabUI.column(10)
	frame.add_child(content)
	content.add_child(_build_header())

	var scroll: ScrollContainer = ScenarioLabUI.vertical_scroll()
	content.add_child(scroll)
	_list = ScenarioLabUI.column(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	ScenarioLab.coverage_changed.connect(_rebuild)
	visibility_changed.connect(func() -> void:
		if visible:
			_rebuild()
	)
	_rebuild()


func _build_header() -> Control:
	var header: HBoxContainer = ScenarioLabUI.row(12)

	var titles: VBoxContainer = ScenarioLabUI.column(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(ScenarioLabUI.label("SCENARIOS", ScenarioLabUI.TITLE_SIZE))
	_summary = ScenarioLabUI.label("", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR)
	titles.add_child(_summary)
	header.add_child(titles)

	_reset_button = ScenarioLabUI.button("RESET COVERAGE", _on_reset_pressed)
	header.add_child(_reset_button)
	header.add_child(ScenarioLabUI.button("CLOSE", hide, ScenarioLabUI.HEADING_SIZE))
	return header


func _rebuild() -> void:
	if not is_node_ready() or not visible:
		return
	ScenarioLabUI.clear_children(_list)
	_reset_armed = false
	_reset_button.text = "RESET COVERAGE"

	var total: Vector2i = Vector2i.ZERO
	var complete: int = 0
	var grid: GridContainer = null
	var current_category: String = ""
	for i: int in ScenarioLab.scenario_ids.size():
		var id: String = ScenarioLab.scenario_ids[i]
		if ScenarioLab.category(id) != current_category:
			current_category = ScenarioLab.category(id)
			_list.add_child(ScenarioLabUI.label(current_category, ScenarioLabUI.HEADING_SIZE))
			grid = GridContainer.new()
			grid.columns = _COLUMNS
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 6)
			_list.add_child(grid)

		var seen: Vector2i = ScenarioLab.coverage(id)
		total += seen
		if seen.x == seen.y:
			complete += 1
		grid.add_child(_build_entry(i, id, seen))

	_summary.text = "%d scenarios, %d fully seen  |  %d / %d ship states seen" % [
		ScenarioLab.scenario_ids.size(), complete, total.x, total.y
	]


func _build_entry(i: int, id: String, seen: Vector2i) -> Button:
	var entry: Button = ScenarioLabUI.button(
		"%s   %d/%d" % [ScenarioLab.display_name(id), seen.x, seen.y],
		_on_entry_pressed.bind(i)
	)
	entry.custom_minimum_size = Vector2((_PANEL_SIZE.x - 64.0) / _COLUMNS, 44)
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.tooltip_text = id
	var color: Color = ScenarioLabUI.SEEN_COLOR if seen.x == seen.y else ScenarioLabUI.UNSEEN_COLOR
	if ScenarioLab.active and i == ScenarioLab.index:
		color = ScenarioLabUI.CURRENT_COLOR
		entry.text = "> " + entry.text
	entry.add_theme_color_override("font_color", color)
	return entry


func _on_entry_pressed(i: int) -> void:
	hide()
	ScenarioLab.launch(i)


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "REALLY RESET?"
		return
	ScenarioLab.reset_coverage()


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide()
