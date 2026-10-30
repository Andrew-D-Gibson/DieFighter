class_name OptionsSubTabs
extends HBoxContainer
## A row of side-by-side toggles that switches between pages within one
## options tab (the Controls tab's Keyboard & Mouse and Controller pages).
## Each is a little pixel panel with an icon and a title; the chosen one is
## filled with the tab's colour.

signal selected(index: int)

const HEIGHT: float = 12.0
const _GAP: int = 4
const _TEXT_LIGHT: Color = Color("#CEF0F1")
const _ICON_GAP: float = 3.0
## Pixel-font capitals sit below the middle of their ascent; this lifts them
## to the box's centre.
const _TEXT_RAISE: float = 1.0

var accent: Color = Color.WHITE
var _buttons: Array[Button] = []
var _group: ButtonGroup = ButtonGroup.new()


func _init(page_accent: Color) -> void:
	accent = page_accent
	custom_minimum_size.y = HEIGHT
	add_theme_constant_override("separation", _GAP)


## Adds a toggle titled [param title_key] (a translation key) with
## [param icon] before the title.
func add_tab(title_key: String, icon: Texture2D) -> Button:
	var index: int = _buttons.size()
	# The button only takes the clicks; _draw() paints it, so the icon and
	# title can be centred together (a Button pins its icon to one end).
	var toggle: Button = Button.new()
	toggle.toggle_mode = true
	toggle.button_group = _group
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.flat = true
	toggle.set_meta(&"title_key", title_key)
	toggle.set_meta(&"icon", icon)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		toggle.add_theme_stylebox_override(state, empty)
	toggle.toggled.connect(func(on: bool) -> void:
		if on:
			selected.emit(index)
		queue_redraw())
	toggle.mouse_entered.connect(queue_redraw)
	toggle.mouse_exited.connect(queue_redraw)
	add_child(toggle)
	_buttons.append(toggle)
	if index == 0:
		toggle.set_pressed_no_signal(true)
	return toggle


## Shows [param index] as the chosen one, without announcing it.
func select(index: int) -> void:
	_buttons[index].set_pressed_no_signal(true)
	queue_redraw()


func _notification(what: int) -> void:
	# A language or font change re-measures the titles.
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	for toggle: Button in _buttons:
		var rect: Rect2 = Rect2(toggle.position, toggle.size)
		var ink: Color
		if toggle.button_pressed:
			OptionsFrame.draw_box(self, rect, accent, accent.darkened(0.6))
			ink = _TEXT_LIGHT
		else:
			var hovered: bool = toggle.is_hovered()
			OptionsFrame.draw_box(self, rect, accent if hovered else accent.darkened(0.45))
			ink = accent if hovered else accent.darkened(0.25)

		var icon: Texture2D = toggle.get_meta(&"icon")
		var title: String = tr(toggle.get_meta(&"title_key"))
		var title_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var width: float = icon.get_width() + _ICON_GAP + title_size.x
		var left: float = roundf(rect.get_center().x - width / 2.0)
		draw_texture(icon, Vector2(left, roundf(rect.get_center().y - icon.get_height() / 2.0)), ink)
		# Baseline so the capitals centre on the box, as the game's labels do.
		var baseline: float = roundf(rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0) - _TEXT_RAISE
		draw_string(font, Vector2(left + icon.get_width() + _ICON_GAP, baseline), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
