class_name OptionsPage
extends VBoxContainer
## One tab of the options menu: rows of labelled controls in one or two
## columns, each bound to an option in OptionsSettings, optionally split into
## headed sections.
##
## Rows are built in code, one call each (see OptionsMenu._build_pages()):
##
##     page.check(OptionsSettings.VSYNC, "OPT_VSYNC", "OPT_VSYNC_HINT")
##     page.next_column()
##     page.choice(OptionsSettings.MAX_FPS, "OPT_FPS_LIMIT", ["30", "60"], [30, 60])
##     page.section("OPT_SECTION_PROGRESS")
##     page.custom(erase_button, "OPT_ERASE_PROGRESS")
##
## A bound row writes through OptionsSettings.set_option() and is refreshed
## from it (refresh()), so the menu always shows live values, including after
## "Reset to defaults" or a change made elsewhere. Labels and hints are
## translation keys.
##
## Within a column every dropdown and button is as wide as the widest, so
## their right edges and their text line up down the page.

## The hovered row's hint, or "" when the mouse leaves it.
signal hint_changed(text: String)

const ROW_HEIGHT: float = 16.0
const WIDGET_WIDTH: float = 40.0
const SECTION_HEIGHT: float = 12.0

const _HOVER_THUMP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")
const _DROPDOWN_SCENE: PackedScene = preload("res://Source/Systems/UI/Buttons/pixel_dropdown.tscn")
const _TEXTURE_DIR: String = "res://Assets/Textures/UI/OptionsMenu/"
## Text on a light (hovered or dragged) slider knob.
const _KNOB_TEXT_LIGHT: Color = Color("#CEF0F1")
## The pixel fonts' glyphs sit low in their line box; this centres them in
## the knob.
const _KNOB_TEXT_RAISE: float = 2.0
## The hovered row's backing, over the panel's fill.
const _HOVER_ALPHA: float = 0.14
## Rows are lined up by width in these; marked by _add_row().
const _EQUAL_WIDTH_META: StringName = &"options_equal_width"

## The page's accent: its tab's colour, and the colour of its controls.
var accent: Color = Color.WHITE
## Which recoloured widget sprites to use: "red", "green", "orange",
## "purple", "blue" or "yellow".
var widget_color: String = "red"

var _column_count: int
## The current section's columns; rows go in _columns[_column_index].
var _columns: Array[VBoxContainer] = []
var _column_index: int = 0
## Every column on the page, for lining widths up.
var _all_columns: Array[VBoxContainer] = []
## Option keys this page shows, for "Reset to defaults".
var _keys: Array[StringName] = []
## Called on refresh() to pull each row's value back from OptionsSettings.
var _refreshers: Array[Callable] = []
## Rows that are only usable some of the time: [row, predicate].
var _conditional_rows: Array[Array] = []
var _hovered_row: Control


func _init(column_count: int = 2) -> void:
	_column_count = column_count
	add_theme_constant_override("separation", 0)
	_start_columns()


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


## A slider for a number option, its value written on the knob.
## [param format] turns the value into that text (a percentage by default).
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
	# Narrower beside a label in a two-column page, but always with room for
	# the knob to travel well past its own width.
	bar.custom_minimum_size.x = WIDGET_WIDTH * (2.0 if _column_count == 1 else 1.6)
	var knob: Texture2D = _widget_texture("slider_knob_%s_dark.png", true)
	bar.add_theme_icon_override("grabber", knob)
	bar.add_theme_icon_override("grabber_highlight", _widget_texture("slider_knob_%s_light.png", true))
	bar.add_theme_icon_override("grabber_disabled", knob)
	bar.add_theme_stylebox_override("grabber_area", _flat_style(accent.darkened(0.4)))
	bar.add_theme_stylebox_override("grabber_area_highlight", _flat_style(accent))

	var readout: Label = Label.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readout.size = knob.get_size()
	readout.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	readout.add_theme_color_override("font_color", accent)
	bar.add_child(readout)
	var place_readout: Callable = func() -> void:
		readout.text = format.call(bar.value)
		readout.position = _grabber_position(bar, knob.get_size())
	# The knob lights up while the mouse is on the slider; so does its text.
	bar.mouse_entered.connect(func() -> void: readout.add_theme_color_override("font_color", _KNOB_TEXT_LIGHT))
	bar.mouse_exited.connect(func() -> void: readout.add_theme_color_override("font_color", accent))
	bar.resized.connect(place_readout)

	bar.value_changed.connect(func(value: float) -> void:
		place_readout.call()
		OptionsSettings.set_option(key, value))
	_bind(key, func() -> void:
		bar.set_value_no_signal(float(OptionsSettings.get_option(key)))
		place_readout.call())
	_add_row(label_key, hint_key, bar, true)
	return bar


## A button that does something rather than holding a value.
func button(label_key: String, text_key: String, on_pressed: Callable, hint_key: String = "") -> Button:
	var pressable: Button = styled_button(text_key)
	# Callers that need the button itself in the handler connect their own.
	if on_pressed.is_valid():
		pressable.pressed.connect(on_pressed)
	_add_row(label_key, hint_key, pressable, true)
	return pressable


## A button styled like button()'s but not put in a row, for widgets that
## hold their own (BindingSlots).
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
## and [param key] (so "Reset to defaults" resets it). [param equal_width]
## lines its width up with the column's dropdowns and buttons.
func custom(control: Control, label_key: String = "", hint_key: String = "",
		key: StringName = &"", refresh: Callable = Callable(), equal_width: bool = true) -> Control:
	if key != &"" or refresh.is_valid():
		_bind(key, refresh)
	return _add_row(label_key, hint_key, control, equal_width)


## Further rows go under a full-width heading, in a fresh set of columns.
## [param color] tints the heading (the page's accent by default), so a
## section with weightier buttons can look it.
func section(title_key: String, color: Color = Color.TRANSPARENT) -> void:
	var tint: Color = accent if color == Color.TRANSPARENT else color
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size.y = SECTION_HEIGHT
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: RichTextLabel = _new_label(title_key)
	title.add_theme_color_override("default_color", tint)
	title.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(title)
	var rule: ColorRect = ColorRect.new()
	rule.color = tint.darkened(0.45)
	rule.custom_minimum_size.y = 1
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_END
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sits on the text's baseline rather than the box's floor.
	var rule_holder: MarginContainer = MarginContainer.new()
	rule_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_holder.add_theme_constant_override("margin_bottom", 3)
	rule_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_holder.add_child(rule)
	header.add_child(rule_holder)
	add_child(header)
	_start_columns()


## Pushes whatever follows to the page's bottom edge.
func spacer() -> void:
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)


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
	_conditional_rows.append([_row_of(row_widget), usable])


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
	_line_up_widths()


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

func _draw() -> void:
	if not is_instance_valid(_hovered_row) or not _hovered_row.is_visible_in_tree():
		return
	var rect: Rect2 = get_global_transform().affine_inverse() * _hovered_row.get_global_rect()
	# A little past the row's ends, so the label and widget sit inside it.
	rect = rect.grow_individual(2, 0, 2, 0)
	draw_rect(rect, Color(accent, _HOVER_ALPHA))
	draw_rect(Rect2(rect.position, Vector2(1, rect.size.y)), accent)


func _start_columns() -> void:
	var block: HBoxContainer = HBoxContainer.new()
	block.add_theme_constant_override("separation", 12)
	block.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(block)
	_columns.clear()
	for i: int in range(_column_count):
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		block.add_child(column)
		_columns.append(column)
		_all_columns.append(column)
	_column_index = 0


func _current_column() -> VBoxContainer:
	return _columns[_column_index]


func _bind(key: StringName, refresh_row: Callable) -> void:
	if key != &"" and OptionsSettings.has_option(key) and not _keys.has(key):
		_keys.append(key)
	if refresh_row.is_valid():
		_refreshers.append(refresh_row)


func _add_row(label_key: String, hint_key: String, widget: Control, equal_width: bool) -> HBoxContainer:
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
	if equal_width and not widget is Slider:
		widget.set_meta(_EQUAL_WIDTH_META, true)
		widget.custom_minimum_size.x = maxf(widget.custom_minimum_size.x, WIDGET_WIDTH)
	widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if label_key == "":
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif not widget is Slider:
		# Hard against the column's right edge, at its own width: the label
		# takes up the slack, so widgets line up down the column.
		widget.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(widget)
	row.mouse_entered.connect(_on_row_entered.bind(row, hint_key))
	row.mouse_exited.connect(_on_row_exited.bind(row))
	_current_column().add_child(row)
	return row


func _on_row_entered(row: Control, hint_key: String) -> void:
	_hovered_row = row
	queue_redraw()
	if hint_key != "":
		hint_changed.emit(tr(hint_key))


func _on_row_exited(row: Control) -> void:
	if _hovered_row != row:
		return
	_hovered_row = null
	queue_redraw()
	hint_changed.emit("")


## Makes every marked widget in a column as wide as the widest one wants to
## be. Again on every refresh, as a language or font change changes widths.
func _line_up_widths() -> void:
	for column: VBoxContainer in _all_columns:
		var widgets: Array[Control] = []
		var widest: float = WIDGET_WIDTH
		for row: Node in column.get_children():
			for child: Node in row.get_children():
				if child is Control and child.has_meta(_EQUAL_WIDTH_META):
					widgets.append(child)
					widest = maxf(widest, _natural_width(child))
		for widget: Control in widgets:
			widget.custom_minimum_size.x = widest


## How wide [param widget] wants to be with nothing cut off.
static func _natural_width(widget: Control) -> float:
	if widget is PixelDropdown:
		return (widget as PixelDropdown).content_width()
	return widget.get_minimum_size().x


## Where an HSlider draws its grabber, as Slider does: the knob's left edge
## slides from the bar's left end to its right end less the knob's width.
## Raised by _KNOB_TEXT_RAISE for text, whose glyphs sit low in their line.
static func _grabber_position(bar: HSlider, knob_size: Vector2) -> Vector2:
	var ratio: float = 0.0 if is_nan(bar.get_as_ratio()) else bar.get_as_ratio()
	return Vector2(roundf(ratio * (bar.size.x - knob_size.x)), roundf((bar.size.y - knob_size.y) / 2.0) - _KNOB_TEXT_RAISE)


func _row_of(widget: Control) -> Control:
	var row: Control = widget
	while row and not row.has_meta(&"options_row"):
		row = row.get_parent() as Control
	return row if row else widget


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
