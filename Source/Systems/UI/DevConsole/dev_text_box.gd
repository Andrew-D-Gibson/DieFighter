class_name DevTextBox
extends HBoxContainer
## The text field every dev tool shares: the console's command bar and the
## tile palette's search bar look and behave the same.
##
## Two things a bare LineEdit gets wrong here. It swallows the console key, so
## a focused field types a backtick instead of closing the dev tools. And its
## built-in clear button is a tiny theme icon at this UI scale, so the field
## carries its own X button instead.

signal text_changed(new_text: String)
signal text_submitted(submitted_text: String)

const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7.ttf")
const _FONT_SIZE: int = 40
const _HEIGHT: float = 64.0
const _FIELD_COLOR: Color = Color(0.09, 0.22, 0.42, 0.85)
const _HOVER_COLOR: Color = Color(0.16, 0.36, 0.62, 0.9)
const _FOCUS_BORDER_COLOR: Color = Color(0.55, 0.78, 1.0, 0.9)
const _CONSOLE_KEY: String = "`"

@export var placeholder_text: String = ""

var line_edit: LineEdit
var clear_button: Button


func _init() -> void:
	add_theme_constant_override("separation", 6)

	line_edit = LineEdit.new()
	line_edit.name = "LineEdit"
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.custom_minimum_size = Vector2(0, _HEIGHT)
	line_edit.context_menu_enabled = false
	line_edit.caret_blink = true
	_apply_font(line_edit)
	line_edit.add_theme_stylebox_override("normal", _make_style(false))
	line_edit.add_theme_stylebox_override("focus", _make_style(true))
	line_edit.add_theme_stylebox_override("read_only", _make_style(false))
	line_edit.gui_input.connect(_on_line_edit_gui_input)
	line_edit.text_changed.connect(_on_line_edit_text_changed)
	line_edit.text_submitted.connect(func(submitted: String) -> void: text_submitted.emit(submitted))
	add_child(line_edit)

	clear_button = Button.new()
	clear_button.name = "ClearButton"
	clear_button.text = "X"
	clear_button.tooltip_text = "Clear"
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.custom_minimum_size = Vector2(_HEIGHT, _HEIGHT)
	_apply_font(clear_button)
	clear_button.add_theme_stylebox_override("normal", _make_style(false))
	clear_button.add_theme_stylebox_override("hover", _make_style(false, _HOVER_COLOR))
	clear_button.add_theme_stylebox_override("pressed", _make_style(true))
	clear_button.pressed.connect(clear)
	add_child(clear_button)


func _ready() -> void:
	line_edit.placeholder_text = placeholder_text


## Empties the field, tells listeners as if the user had deleted the text, and
## leaves the field focused so the next search or command can be typed at once.
func clear() -> void:
	line_edit.text = ""
	text_changed.emit("")
	line_edit.grab_focus()


## Runs before the LineEdit's own handling, so accepting the console key here
## stops it being typed.
func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action(&"DevConsole") and event.is_pressed():
		line_edit.accept_event()
		if not event.is_echo():
			Events.dev_console_close_requested.emit()


## Backstop for a backtick that arrives some other way (a paste, or a layout
## where it isn't the console key): it never belongs in a command or search.
func _on_line_edit_text_changed(new_text: String) -> void:
	if new_text.contains(_CONSOLE_KEY):
		var caret: int = line_edit.caret_column
		line_edit.text = new_text.replace(_CONSOLE_KEY, "")
		line_edit.caret_column = mini(caret, line_edit.text.length())
		Events.dev_console_close_requested.emit()
		new_text = line_edit.text
	text_changed.emit(new_text)


func _apply_font(control: Control) -> void:
	control.add_theme_font_override("font", _FONT)
	control.add_theme_font_size_override("font_size", _FONT_SIZE)


func _make_style(focused: bool, color: Color = _FIELD_COLOR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if focused:
		style.set_border_width_all(2)
		style.border_color = _FOCUS_BORDER_COLOR
	return style
