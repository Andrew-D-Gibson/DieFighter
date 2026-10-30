class_name OptionsMenu
extends Node2D
## The options menu: a tab per area, each one or more OptionsPages of rows
## bound to OptionsSettings, plus a hint line, "Reset to defaults" for the
## open tab, and Close. A tab with several pages (Controls: keyboard & mouse,
## controller) switches between them with an OptionsSubTabs row. Opened from
## the main menu, the Game tab also has a Progress section with Erase
## Progress and Unlock All (ProgressTools), for putting the game back to a
## first launch or seeing all of it; each asks first in a ConfirmDialog.
##
## Everything is built in code (_build_pages()) so a new option is one line
## there; the panel is drawn by OptionsFrame to fit however many tabs there
## are. Settings were loaded and applied at startup by the OptionsSettings
## autoload: the menu only shows and changes them.

## Erase Progress or Unlock All has just changed the player's progress, so
## the screen behind can catch up (Continue, for one).
signal progress_changed()

const _SMALL_BUTTON_SCENE: PackedScene = preload("res://Source/Systems/UI/Buttons/small_button.tscn")
const _MEDIUM_BUTTON_SCENE: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_button.tscn")
const _CONFIRM_DIALOG_SCENE: PackedScene = preload("res://Source/Systems/UI/ConfirmDialog/confirm_dialog.tscn")
const _GREEN_BUTTON_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_green.png")
const _RED_BUTTON_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_red.png")
const _PURPLE_BUTTON_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_purple.png")
const _KEYBOARD_ICON: Texture2D = preload("res://Assets/Textures/UI/OptionsMenu/icon_keyboard_mouse.png")
const _CONTROLLER_ICON: Texture2D = preload("res://Assets/Textures/UI/OptionsMenu/icon_controller.png")
## The bottom bar reads like every other confirm/cancel pair in the game: a
## red button that undoes things, a green one that carries on.
const _DEFAULTS_COLOR: Color = Color("#D03656")
const _CLOSE_COLOR: Color = Color("#7ABD33")
## The Progress section's heading and Erase button: these can't be undone.
const _DANGER_COLOR: Color = Color("#D03656")
const _UNLOCK_COLOR: Color = Color("#C552F1")
const _HINT_COLOR: Color = Color("#A5A29D")
## How long the hint line reports a progress tool's result, in seconds.
const _STATUS_TIME: float = 2.5

## The panel, centred on this node, in world pixels.
const PANEL_SIZE: Vector2 = Vector2(256, 140)
const TAB_HEIGHT: float = 12.0
const _BODY_MARGIN: float = 6.0
const _BUTTON_SIZE: Vector2 = Vector2(56, 14)
const _TAB_FONT_SIZE: int = 16
const _TAB_PADDING: float = 10.0
## Between a sub-tab row and its pages.
const _SUB_TAB_GAP: float = 4.0
## The Controls pages break to their second column after this many rows.
const _CONTROLS_COLUMN_ROWS: int = 4

enum Tab {GAME, GRAPHICS, AUDIO, CONTROLS, ACCESSIBILITY}
enum ControlsPage {KEYBOARD, CONTROLLER}

## Per tab: title key, accent colour, widget sprite colour.
const _TABS: Dictionary[Tab, Array] = {
	Tab.GAME: ["OPT_TAB_GAME", Color("#F29C5D"), "orange"],
	Tab.GRAPHICS: ["OPT_TAB_GRAPHICS", Color("#7ABD33"), "green"],
	Tab.AUDIO: ["OPT_TAB_AUDIO", Color("#C552F1"), "purple"],
	Tab.CONTROLS: ["OPT_TAB_CONTROLS", Color("#43A6FC"), "blue"],
	Tab.ACCESSIBILITY: ["OPT_TAB_ACCESSIBILITY", Color("#EED35D"), "yellow"],
}

## Tabs split into pages: per page, its sub-tab title key and icon.
const _SUB_TABS: Dictionary[Tab, Array] = {
	Tab.CONTROLS: [
		["OPT_SUBTAB_KEYBOARD", _KEYBOARD_ICON],
		["OPT_SUBTAB_CONTROLLER", _CONTROLLER_ICON],
	],
}

## Rows by index, not text, so the text can be translated.
const _ANIMATION_SPEEDS: Array = [0.5, 1.0, 2.0, 4.0]
const _FPS_LIMITS: Array = [30, 60, 120, 0] # 0 means unlimited

## Shows Erase Progress and Unlock All on the Game tab. Only the main menu's
## copy does: mid-run, erasing would pull the save out from under the run.
@export var show_progress_tools: bool = false

var _frame: OptionsFrame
var _tab_buttons: Array[Button] = []
## Each tab's pages; most have one.
var _pages: Dictionary[Tab, Array] = {}
var _sub_tabs: Dictionary[Tab, OptionsSubTabs] = {}
## Which of its pages each tab shows.
var _open_page: Dictionary[Tab, int] = {}
var _hint_label: RichTextLabel
var _defaults_button: Button
var _open_tab: Tab = Tab.GAME
var _confirm_dialog: ConfirmDialog
## What the confirm dialog runs if confirmed: [action, status key].
var _pending_progress: Array = []
## Bumped by every hint change, so a status message only clears itself.
var _hint_serial: int = 0


func _ready() -> void:
	_build_panel()
	_build_pages()
	_show_tab(Tab.GAME)
	OptionsSettings.option_changed.connect(_on_option_changed)
	get_tree().root.size_changed.connect(_refresh_open_page)
	visibility_changed.connect(_on_visibility_changed)


## --- The options ---

func _build_pages() -> void:
	var game: OptionsPage = _page(Tab.GAME)
	game.choice(OptionsSettings.ANIMATION_SPEED, "OPT_ANIMATION_SPEED",
		["0.5x", "1x", "2x", "4x"], _ANIMATION_SPEEDS, "OPT_ANIMATION_SPEED_HINT")
	var locales: Array[String] = Localization.get_available_locales()
	var locale_names: Array[String] = []
	for locale: String in locales:
		locale_names.append(Localization.get_locale_name(locale))
	game.choice(OptionsSettings.LANGUAGE, "OPT_LANGUAGE", locale_names, locales)
	game.next_column()
	game.check(OptionsSettings.REGION_ALERTS, "OPT_REGION_ALERTS", "OPT_REGION_ALERTS_HINT")
	# Comfort: background behaviour.
	game.check(OptionsSettings.PAUSE_IN_BACKGROUND, "OPT_PAUSE_IN_BACKGROUND", "OPT_PAUSE_IN_BACKGROUND_HINT")
	# Dice input: asking before a turn ends with dice unplayed.
	game.check(OptionsSettings.CONFIRM_END_TURN, "OPT_CONFIRM_END_TURN", "OPT_CONFIRM_END_TURN_HINT")
	if show_progress_tools:
		game.spacer()
		game.section("OPT_SECTION_PROGRESS", _DANGER_COLOR)
		_add_progress_row(game, "OPT_ERASE_PROGRESS", "OPT_ERASE", "OPT_ERASE_PROGRESS_HINT",
			_RED_BUTTON_TEXTURE, _DANGER_COLOR, "OPT_ERASE_CONFIRM", true, ProgressTools.erase, "OPT_PROGRESS_ERASED")
		game.next_column()
		_add_progress_row(game, "OPT_UNLOCK_ALL", "OPT_UNLOCK", "OPT_UNLOCK_ALL_HINT",
			_PURPLE_BUTTON_TEXTURE, _UNLOCK_COLOR, "OPT_UNLOCK_CONFIRM", false, ProgressTools.unlock_all, "OPT_PROGRESS_UNLOCKED")

	var graphics: OptionsPage = _page(Tab.GRAPHICS)
	graphics.check(OptionsSettings.FULLSCREEN, "OPT_FULLSCREEN")
	# In a browser the page owns the window: only fullscreen is ours.
	if OptionsSettings.has_option(OptionsSettings.PIXEL_PERFECT):
		var pixel_perfect: CheckBox = graphics.check(OptionsSettings.PIXEL_PERFECT, "OPT_PIXEL_PERFECT", "OPT_PIXEL_PERFECT_HINT")
		graphics.enable_when(pixel_perfect, OptionsSettings.is_fullscreen)
		var scales: Array = _window_scales()
		var scale_labels: Array = scales.map(func(scale: int) -> String: return "%dx" % scale)
		var window_scale: PixelDropdown = graphics.choice(OptionsSettings.WINDOW_SCALE, "OPT_WINDOW_SCALE",
			scale_labels, scales, "OPT_WINDOW_SCALE_HINT")
		graphics.enable_when(window_scale, func() -> bool: return not OptionsSettings.is_fullscreen())
		graphics.next_column()
		var monitors: Array = range(DisplayServer.get_screen_count())
		var monitor_labels: Array = monitors.map(func(screen: int) -> String: return tr("OPT_MONITOR_N").format({"n": screen + 1}))
		var monitor: PixelDropdown = graphics.choice(OptionsSettings.MONITOR, "OPT_MONITOR", monitor_labels, monitors)
		graphics.enable_when(monitor, func() -> bool: return DisplayServer.get_screen_count() > 1)
		graphics.check(OptionsSettings.VSYNC, "OPT_VSYNC", "OPT_VSYNC_HINT")
	else:
		graphics.next_column()
	graphics.choice(OptionsSettings.MAX_FPS, "OPT_FPS_LIMIT", ["30", "60", "120", "OPT_FPS_UNLIMITED"], _FPS_LIMITS)

	var audio: OptionsPage = _page(Tab.AUDIO)
	audio.slider(OptionsSettings.MASTER_VOLUME, "OPT_GAME_VOLUME")
	audio.slider(OptionsSettings.MUSIC_VOLUME, "OPT_MUSIC_VOLUME")
	audio.slider(OptionsSettings.SFX_VOLUME, "OPT_SFX_VOLUME")
	audio.check(OptionsSettings.MUTE_ALL, "OPT_MUTE_ALL")
	# Comfort: background behaviour.
	audio.check(OptionsSettings.MUTE_IN_BACKGROUND, "OPT_MUTE_IN_BACKGROUND", "OPT_MUTE_IN_BACKGROUND_HINT")

	# Controls: the rebindable actions on two pages, keys and controller
	# buttons, each with the settings only that kind of input has.
	var keyboard: OptionsPage = _page(Tab.CONTROLS, ControlsPage.KEYBOARD)
	_add_binding_rows(keyboard, InputBindings.Kind.KEY, "OPT_BINDING_HINT_KEY")
	# Dice input: how dice and tiles are picked up and put down.
	keyboard.choice(OptionsSettings.DICE_PLACEMENT, "OPT_DICE_PLACEMENT",
		["OPT_DICE_PLACEMENT_DRAG", "OPT_DICE_PLACEMENT_CLICK"],
		[Draggable.PlacementMode.DRAG, Draggable.PlacementMode.CLICK], "OPT_DICE_PLACEMENT_HINT")
	var controller: OptionsPage = _page(Tab.CONTROLS, ControlsPage.CONTROLLER)
	_add_binding_rows(controller, InputBindings.Kind.PAD, "OPT_BINDING_HINT_PAD")
	controller.slider(OptionsSettings.CURSOR_SPEED, "OPT_CURSOR_SPEED",
		"OPT_CURSOR_SPEED_HINT", OptionsSettings.CURSOR_SPEEDS.x, OptionsSettings.CURSOR_SPEEDS.y, 0.1)

	var accessibility: OptionsPage = _page(Tab.ACCESSIBILITY)
	# Comfort: screenshake, flashing and hit pause.
	accessibility.slider(OptionsSettings.SCREENSHAKE_INTENSITY, "OPT_SCREENSHAKE", "OPT_SCREENSHAKE_HINT")
	accessibility.check(OptionsSettings.REDUCE_FLASHING, "OPT_REDUCE_FLASHING", "OPT_REDUCE_FLASHING_HINT")
	accessibility.check(OptionsSettings.HIT_PAUSE, "OPT_HIT_PAUSE", "OPT_HIT_PAUSE_HINT")
	accessibility.next_column()
	# Colorblind support
	accessibility.check(OptionsSettings.COLOR_SYMBOLS, "OPT_COLOR_SYMBOLS", "OPT_COLOR_SYMBOLS_HINT")
	# Readable font
	accessibility.check(OptionsSettings.READABLE_FONT, "OPT_READABLE_FONT", "OPT_READABLE_FONT_HINT")


## A row per action that [param kind] of input can bind, breaking to the
## second column after _CONTROLS_COLUMN_ROWS.
func _add_binding_rows(page: OptionsPage, kind: InputBindings.Kind, hint_key: String) -> void:
	var rows: int = 0
	for action: StringName in InputBindings.ACTIONS:
		if kind == InputBindings.Kind.KEY and action in InputBindings.PAD_ONLY:
			continue
		if rows == _CONTROLS_COLUMN_ROWS:
			page.next_column()
		var kinds: Array[InputBindings.Kind] = [kind]
		var slots: BindingSlots = BindingSlots.new(action, page.styled_button, kinds)
		page.custom(slots, InputBindings.LABEL_KEYS[action], hint_key,
			InputBindings.option_key(action), slots.refresh)
		rows += 1


## A Progress row: [param label_key] beside a sprite button reading
## [param text_key]. Pressing it asks [param confirm_key] first, then runs
## [param action] and reports [param status_key] on the hint line.
func _add_progress_row(page: OptionsPage, label_key: String, text_key: String, hint_key: String,
		texture: Texture2D, color: Color, confirm_key: String, destructive: bool,
		action: Callable, status_key: String) -> void:
	var pressable: Button = _MEDIUM_BUTTON_SCENE.instantiate()
	pressable.hover_text_color = color
	pressable.pressed_within_window.connect(func() -> void:
		_pending_progress = [action, status_key]
		_confirm_dialog.open(tr(confirm_key), destructive, text_key))
	page.custom(pressable, label_key, hint_key, &"", Callable(), false)
	pressable.set_button_text(text_key)
	set_button_texture(pressable, texture)


## The window scales offered here: those that fit on this display.
func _window_scales() -> Array:
	var largest: int = OptionsSettings.largest_window_scale()
	return OptionsSettings.WINDOW_SCALES.filter(func(scale: int) -> bool: return scale <= largest)


## --- Layout ---

func _build_panel() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.027451, 0.0117647, 0.054902, 0.827451)
	dim.position = -Globals.SCREEN_SIZE / 2.0
	dim.size = Globals.SCREEN_SIZE
	add_child(dim)

	var panel_rect: Rect2 = Rect2(-PANEL_SIZE / 2.0, PANEL_SIZE)
	_frame = OptionsFrame.new()
	add_child(_frame)
	_frame.body_rect = Rect2(panel_rect.position + Vector2(0, TAB_HEIGHT), panel_rect.size - Vector2(0, TAB_HEIGHT))

	_build_tabs(panel_rect)

	var body: Rect2 = _frame.body_rect.grow(-_BODY_MARGIN)
	var bottom_bar_top: float = body.end.y - _BUTTON_SIZE.y
	var pages_rect: Rect2 = Rect2(body.position, Vector2(body.size.x, bottom_bar_top - 12 - body.position.y))
	for tab: Tab in _TABS:
		_pages[tab] = []
		_open_page[tab] = 0
		var rect: Rect2 = pages_rect
		var sub_tabs: Array = _SUB_TABS.get(tab, [])
		if not sub_tabs.is_empty():
			var bar: OptionsSubTabs = OptionsSubTabs.new(_TABS[tab][1])
			bar.position = rect.position
			bar.size = Vector2(rect.size.x, OptionsSubTabs.HEIGHT)
			for entry: Array in sub_tabs:
				bar.add_tab(entry[0], entry[1])
			bar.selected.connect(_show_page.bind(tab))
			add_child(bar)
			_sub_tabs[tab] = bar
			rect = rect.grow_side(SIDE_TOP, -(OptionsSubTabs.HEIGHT + _SUB_TAB_GAP))
		for i: int in range(maxi(1, sub_tabs.size())):
			var page: OptionsPage = OptionsPage.new(1 if tab == Tab.AUDIO else 2)
			page.accent = _TABS[tab][1]
			page.widget_color = _TABS[tab][2]
			page.position = rect.position
			page.size = rect.size
			page.hint_changed.connect(_on_hint_changed)
			add_child(page)
			_pages[tab].append(page)

	_hint_label = RichTextLabel.new()
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("default_color", _HINT_COLOR)
	_hint_label.position = Vector2(body.position.x, bottom_bar_top - 12)
	_hint_label.size = Vector2(body.size.x, 12)
	add_child(_hint_label)

	_defaults_button = _add_bottom_button("OPT_DEFAULTS", Vector2(body.position.x, bottom_bar_top), _on_defaults_pressed)
	_defaults_button.mouse_entered.connect(func() -> void: _on_hint_changed(tr("OPT_DEFAULTS_HINT")))
	_defaults_button.mouse_exited.connect(func() -> void: _on_hint_changed(""))
	_defaults_button.hover_text_color = _DEFAULTS_COLOR
	var close_button: Button = _add_bottom_button("OPT_CLOSE", Vector2(body.end.x - _BUTTON_SIZE.x, bottom_bar_top), _on_close_button_pressed)
	close_button.hover_text_color = _CLOSE_COLOR
	set_button_texture(close_button, _GREEN_BUTTON_TEXTURE)

	_confirm_dialog = _CONFIRM_DIALOG_SCENE.instantiate()
	add_child(_confirm_dialog)
	_confirm_dialog.hide()
	_confirm_dialog.confirmed.connect(_on_progress_confirmed)
	_confirm_dialog.cancelled.connect(func() -> void: _pending_progress = [])


func _build_tabs(panel_rect: Rect2) -> void:
	for tab: Tab in _TABS:
		var button: Button = _SMALL_BUTTON_SCENE.instantiate()
		button.get_node("AnimatedSprite2D").sprite_frames = null
		button.hover_text_color = _TABS[tab][1]
		add_child(button)
		button.set_button_text(_TABS[tab][0])
		button.pressed_within_window.connect(_show_tab.bind(tab))
		_tab_buttons.append(button)
	_layout_tabs(panel_rect)


## Lays the tabs out across the panel's top, each as wide as its title, with
## the leftover width shared out between them. Again whenever the font
## changes, which changes the titles' widths.
func _layout_tabs(panel_rect: Rect2) -> void:
	var font: Font = _frame.get_theme_default_font()
	var widths: Array[float] = []
	var total: float = 0.0
	for tab: Tab in _TABS:
		var width: float = ceilf(font.get_string_size(tr(_TABS[tab][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _TAB_FONT_SIZE).x + _TAB_PADDING)
		widths.append(width)
		total += width
	var gap: float = floorf((panel_rect.size.x - total) / maxf(1.0, _TABS.size() - 1))

	var rects: Array[Rect2] = []
	var colors: Array[Color] = []
	var x: float = panel_rect.position.x
	for tab: Tab in _TABS:
		var width: float = widths[tab]
		# The last tab ends flush with the panel.
		if tab == _TABS.size() - 1:
			width = panel_rect.end.x - x
		var rect: Rect2 = Rect2(x, panel_rect.position.y, width, TAB_HEIGHT)
		rects.append(rect)
		colors.append(_TABS[tab][1])

		var button: Button = _tab_buttons[tab]
		button.custom_minimum_size = rect.size
		button.position = rect.position
		button.size = rect.size
		x += width + gap
	_frame.tab_rects = rects
	_frame.tab_colors = colors


func _add_bottom_button(text_key: String, at: Vector2, on_pressed: Callable) -> Button:
	var button: Button = _MEDIUM_BUTTON_SCENE.instantiate()
	button.position = at
	add_child(button)
	button.set_button_text(text_key)
	button.pressed_within_window.connect(on_pressed)
	return button


## Swaps a button scene's sprite (the scenes come in red) for one of the other
## coloured textures, cut to the button's own size.
static func set_button_texture(button: Button, texture: Texture2D) -> void:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, button.custom_minimum_size)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_frame(&"default", atlas)
	button.get_node("AnimatedSprite2D").sprite_frames = frames


## --- Behaviour ---

func _page(tab: Tab, index: int = 0) -> OptionsPage:
	return _pages[tab][index]


func _shown_page() -> OptionsPage:
	return _page(_open_tab, _open_page[_open_tab])


func _show_tab(tab: Tab) -> void:
	_open_tab = tab
	for each: Tab in _pages:
		if _sub_tabs.has(each):
			_sub_tabs[each].visible = each == tab
	_frame.active_tab = tab
	_show_page(_open_page[tab], tab)


func _show_page(index: int, tab: Tab) -> void:
	_open_page[tab] = index
	for each: Tab in _pages:
		for i: int in range(_pages[each].size()):
			_page(each, i).visible = each == tab and i == index
	_on_hint_changed("")
	_shown_page().refresh()


func _refresh_open_page() -> void:
	if visible:
		_shown_page().refresh()


func _on_option_changed(key: StringName, _value: Variant) -> void:
	if key == OptionsSettings.READABLE_FONT:
		_layout_tabs(Rect2(-PANEL_SIZE / 2.0, PANEL_SIZE))
	# One option can change what another may do (fullscreen and the window
	# scale), so the whole page is re-read.
	_refresh_open_page()


func _on_visibility_changed() -> void:
	if not visible:
		_confirm_dialog.hide()
		_pending_progress = []
	else:
		# Options can change while the menu is shut (the dev console, the
		# window going fullscreen from its title bar).
		_shown_page().refresh()


func _on_hint_changed(text: String) -> void:
	_hint_serial += 1
	_hint_label.text = text
	_hint_label.add_theme_color_override("default_color", _HINT_COLOR)


func _on_defaults_pressed() -> void:
	# Every page of the tab: Controls resets keyboard and controller alike.
	var keys: Array[StringName] = []
	for page: OptionsPage in _pages[_open_tab]:
		keys.append_array(page.option_keys())
	OptionsSettings.reset_options(keys)


func _on_progress_confirmed() -> void:
	if _pending_progress.is_empty():
		return
	var action: Callable = _pending_progress[0]
	var status_key: String = _pending_progress[1]
	_pending_progress = []
	action.call()
	progress_changed.emit()
	_show_status(tr(status_key), _CLOSE_COLOR)


## Puts [param text] on the hint line for a moment, unless the hint changes
## first.
func _show_status(text: String, color: Color) -> void:
	_on_hint_changed(text)
	_hint_label.add_theme_color_override("default_color", color)
	var serial: int = _hint_serial
	await get_tree().create_timer(_STATUS_TIME).timeout
	if serial == _hint_serial:
		_on_hint_changed("")


func _on_close_button_pressed() -> void:
	OptionsSettings.save_options_settings()
	hide()
