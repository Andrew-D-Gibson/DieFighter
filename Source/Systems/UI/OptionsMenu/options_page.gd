class_name OptionsPage
extends HBoxContainer
## One tab of the options menu: rows of labelled controls in one or two
## columns, each bound to an option in OptionsSettings.
##
## Rows are built in code, one call each (see OptionsMenu._build_pages()):
##
##     page.check(OptionsSettings.VSYNC, "OPT_VSYNC", "OPT_VSYNC_HINT")
##     page.next_column()
##     page.choice(OptionsSettings.MAX_FPS, "OPT_FPS_LIMIT", ["30", "60"], [30, 60])
##
## A bound row writes through OptionsSettings.set_option() and is refreshed
## from it (refresh()), so the menu always shows live values, including after
## "Reset to defaults" or a change made elsewhere. Labels and hints are
## translation keys.

## The hovered row's hint, or "" when the mouse leaves it.
signal hint_changed(text: String)

const ROW_HEIGHT: float = 16.0
const WIDGET_WIDTH: float = 40.0

const _HOVER_THUMP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")
const _DROPDOWN_SCENE: PackedScene = preload("res://Source/Systems/UI/Buttons/pixel_dropdown.tscn")
const _TEXTURE_DIR: String = "res://Assets/Textures/UI/OptionsMenu/"

## The page's accent: its tab's colour, and the colour of its controls.
var accent: Color = Color.WHITE
## Which recoloured widget sprites to use: "red", "green", "orange",
## "purple", "blue" or "yellow".
var widget_color: String = "red"

var _columns: Array[VBoxContainer] = []
var _column_index: int = 0
## Option keys this page shows, for "Reset to defaults".
var _keys: Array[StringName] = []
## Called on refresh() to pull each row's value back from OptionsSettings.
var _refreshers: Array[Callable] = []
## Rows that are only usable some of the time: [row, predicate].
var _conditional_rows: Array[Array] = []


func _init(column_count: int = 2) -> void:
	add_theme_constant_override("separation", 12)
	for i: int in range(column_count):
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		add_child(column)
		_columns.append(column)


## --- Building ---

## A checkbox for a bool option.
func check(key: StringName, label_key: String, hint_key: String = "") -> CheckBox:
	var box: CheckBox = CheckBox.new()
	box.flat = true
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_icon_override("checked", _widget_texture("CheckBox/check_box_checked%s.png"))
	box.add_theme_icon_override("unchecked", _widget_texture("CheckBox/check_box_unchecked%s.png"))
	box.add_theme_icon_override("checked_disabled", _widget_texture("CheckBox/check_box_checked%s.png"))
	box.add_theme_icon_override("unchecked_disabled", _widget_texture("CheckBox/check_box_unchecked%s.png"))
	box.toggled.connect(func(on: bool) -> void:
		Events.play_sound.emit(_HOVER_THUMP_SFX)
		OptionsSettings.set_option(key, on))
	_bind(key, func() -> void: box.set_pressed_no_signal(bool(OptionsSettings.get_option(key))))
	# The art has a pixel of air round it; let it hang into the row's margin.
	var holder: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		holder.add_theme_constant_override("margin_" + side, -4)
	holder.add_child(box)
	_add_row(label_key, hint_key, holder, false)
	return box


## A dropdown choosing between [param values], shown as [param labels]
## (translation keys or plain text).
func choice(key: StringName, label_key: String, labels: Array, values: Array, hint_key: String = "") -> PixelDropdown:
	var dropdown: PixelDropdown = _DROPDOWN_SCENE.instantiate()
	dropdown.custom_minimum_size.x = WIDGET_WIDTH
	var items: Array[String] = []
	for label: Variant in labels:
		items.append(str(label))
	dropdown.items = items
	dropdown.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var background: Texture2D = _widget_texture("OptionButton/option_button_%s_background_.png", true)
	dropdown.normal_style = _texture_style(background)
	dropdown.hover_style = dropdown.normal_style
	dropdown.pressed_style = dropdown.normal_style
	dropdown.disabled_style = dropdown.normal_style
	dropdown.arrow_icon = _widget_texture("OptionButton/option_button_%s_arrow.png", true)
	dropdown.font_color = accent
	dropdown.item_selected.connect(func(index: int) -> void: OptionsSettings.set_option(key, values[index]))
	_bind(key, func() -> void: dropdown.select(index_of(values, OptionsSettings.get_option(key))))
	_add_row(label_key, hint_key, dropdown, true)
	return dropdown


## A slider for a number option. [param format] turns the value into the
## text shown beside it (a percentage by default).
func slider(key: StringName, label_key: String, hint_key: String = "", min_value: float = 0.0,
		max_value: float = 1.0, step: float = 0.01, format: Callable = Callable()) -> HSlider:
	if not format.is_valid():
		format = func(value: float) -> String: return "%d%%" % roundi(value * 100.0)
	var bar: HSlider = HSlider.new()
	bar.min_value = min_value
	bar.max_value = max_value
	bar.step = step
	bar.focus_mode = Control.FOCUS_NONE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size.x = WIDGET_WIDTH * 2.0
	bar.add_theme_icon_override("grabber", _widget_texture("slider_knob_%s_dark.png", true))
	bar.add_theme_icon_override("grabber_highlight", _widget_texture("slider_knob_%s_light.png", true))
	bar.add_theme_icon_override("grabber_disabled", _widget_texture("slider_knob_%s_dark.png", true))
	bar.add_theme_stylebox_override("grabber_area", _flat_style(accent.darkened(0.4)))
	bar.add_theme_stylebox_override("grabber_area_highlight", _flat_style(accent))

	var readout: RichTextLabel = _new_label("")
	readout.custom_minimum_size.x = 18
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.size_flags_horizontal = Control.SIZE_SHRINK_END
	readout.add_theme_color_override("default_color", accent)

	bar.value_changed.connect(func(value: float) -> void:
		readout.text = format.call(value)
		OptionsSettings.set_option(key, value))
	_bind(key, func() -> void:
		bar.set_value_no_signal(float(OptionsSettings.get_option(key)))
		readout.text = format.call(bar.value))

	var widget: HBoxContainer = HBoxContainer.new()
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget.add_child(bar)
	widget.add_child(readout)
	_add_row(label_key, hint_key, widget, true)
	return bar


## A button that does something rather than holding a value (open the key
## bindings, reset the save).
func button(label_key: String, text_key: String, on_pressed: Callable, hint_key: String = "") -> Button:
	var pressable: Button = Button.new()
	pressable.text = text_key
	pressable.focus_mode = Control.FOCUS_NONE
	pressable.custom_minimum_size.x = WIDGET_WIDTH
	var background: Texture2D = _widget_texture("OptionButton/option_button_%s_background_.png", true)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		pressable.add_theme_stylebox_override(state, _texture_style(background))
	pressable.add_theme_color_override("font_color", accent)
	pressable.add_theme_color_override("font_hover_color", Color.WHITE)
	pressable.pressed.connect(on_pressed)
	_add_row(label_key, hint_key, pressable, true)
	return pressable


## A button styled like button()'s but not put in a row, for widgets that
## hold several (BindingSlots).
func styled_button(text_key: String = "") -> Button:
	var pressable: Button = Button.new()
	pressable.text = text_key
	pressable.focus_mode = Control.FOCUS_NONE
	var background: Texture2D = _widget_texture("OptionButton/option_button_%s_background_.png", true)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		pressable.add_theme_stylebox_override(state, _texture_style(background))
	pressable.add_theme_color_override("font_color", accent)
	pressable.add_theme_color_override("font_hover_color", Color.WHITE)
	pressable.add_theme_color_override("font_disabled_color", accent.darkened(0.5))
	return pressable


## Any other control, for rows the helpers above don't cover. Bind it to an
## option with [param refresh] (called whenever the menu re-reads options)
## and [param key] (so "Reset to defaults" resets it).
func custom(control: Control, label_key: String = "", hint_key: String = "",
		key: StringName = &"", refresh: Callable = Callable()) -> Control:
	if key != &"" or refresh.is_valid():
		_bind(key, refresh)
	return _add_row(label_key, hint_key, control, true)


## Plain text, for a note or a heading.
func note(text_key: String) -> RichTextLabel:
	var label: RichTextLabel = _new_label(text_key)
	label.add_theme_color_override("default_color", accent)
	_current_column().add_child(label)
	return label


## Further rows go in the next column.
func next_column() -> void:
	_column_index = mini(_column_index + 1, _columns.size() - 1)


## Greys [param row_widget]'s row out (and stops it taking input) whenever
## [param usable] returns false. Rechecked on refresh().
func enable_when(row_widget: Control, usable: Callable) -> void:
	var row: Control = row_widget
	while row and not row.has_meta(&"options_row"):
		row = row.get_parent() as Control
	_conditional_rows.append([row if row else row_widget, usable])


## --- Reading back ---

## The option keys this page shows, for "Reset to defaults".
func option_keys() -> Array[StringName]:
	return _keys.duplicate()


## Pulls every row's value from OptionsSettings and rechecks which rows are
## usable.
func refresh() -> void:
	for refresher: Callable in _refreshers:
		refresher.call()
	for entry: Array in _conditional_rows:
		_set_row_enabled(entry[0], entry[1].call())


## Where [param value] sits in [param values], comparing numbers by value so
## a saved 60.0 still finds 60. -1 if it isn't there.
static func index_of(values: Array, value: Variant) -> int:
	for i: int in range(values.size()):
		var candidate: Variant = values[i]
		if (candidate is int or candidate is float) and (value is int or value is float):
			if is_equal_approx(float(candidate), float(value)):
				return i
		elif typeof(candidate) == typeof(value) and candidate == value:
			return i
	return -1


## --- Internals ---

func _current_column() -> VBoxContainer:
	return _columns[_column_index]


func _bind(key: StringName, refresh_row: Callable) -> void:
	if key != &"" and OptionsSettings.has_option(key) and not _keys.has(key):
		_keys.append(key)
	if refresh_row.is_valid():
		_refreshers.append(refresh_row)


func _add_row(label_key: String, hint_key: String, widget: Control, fixed_width: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_meta(&"options_row", true)
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	if label_key != "":
		var label: RichTextLabel = _new_label(label_key)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("default_color", accent)
		label.set_meta(&"options_label", true)
		row.add_child(label)
	if fixed_width and widget.custom_minimum_size.x == 0.0:
		widget.custom_minimum_size.x = WIDGET_WIDTH
	widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if label_key == "":
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(widget)
	if hint_key != "":
		row.mouse_entered.connect(func() -> void: hint_changed.emit(tr(hint_key)))
		row.mouse_exited.connect(func() -> void: hint_changed.emit(""))
	_current_column().add_child(row)
	return row


func _set_row_enabled(row: Control, enabled: bool) -> void:
	row.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.35)
	for child: Node in row.find_children("*", "", true, false):
		if child is BaseButton:
			(child as BaseButton).disabled = not enabled
		elif child is PixelDropdown:
			(child as PixelDropdown).disabled = not enabled
		elif child is Slider:
			(child as Slider).editable = enabled


func _new_label(text_key: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.text = text_key
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label


## [param pattern] has a %s for the colour. Red's checkbox files have no
## suffix; [param named] patterns always spell the colour out.
func _widget_texture(pattern: String, named: bool = false) -> Texture2D:
	var suffix: String = widget_color if named else ("" if widget_color == "red" else "_" + widget_color)
	return load(_TEXTURE_DIR + pattern % suffix)


static func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 2.0)
	return style


static func _flat_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.anti_aliasing = false
	return style
