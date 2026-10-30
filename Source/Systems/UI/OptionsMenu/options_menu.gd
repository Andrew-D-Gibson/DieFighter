class_name OptionsMenu
extends Node2D
## The options menu: a tab per area, each an OptionsPage of rows bound to
## OptionsSettings, plus a hint line, "Reset to defaults" for the open tab, and
## Close. Opened from the main menu, the Game tab also has Erase Progress and
## Unlock All (ProgressTools), for putting the game back to a first launch or
## seeing all of it.
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
const _GREEN_BUTTON_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_green.png")
## The bottom bar reads like every other confirm/cancel pair in the game: a
## red button that undoes things, a green one that carries on.
const _DEFAULTS_COLOR: Color = Color("#D03656")
const _CLOSE_COLOR: Color = Color("#7ABD33")

## The panel, centred on this node, in world pixels.
const PANEL_SIZE: Vector2 = Vector2(256, 140)
const TAB_HEIGHT: float = 12.0
const _BODY_MARGIN: float = 6.0
const _BUTTON_SIZE: Vector2 = Vector2(56, 14)
const _TAB_FONT_SIZE: int = 16
const _TAB_PADDING: float = 10.0

enum Tab {GAME, GRAPHICS, AUDIO, CONTROLS, ACCESSIBILITY}

## Per tab: title key, accent colour, widget sprite colour.
const _TABS: Dictionary[Tab, Array] = {
	Tab.GAME: ["OPT_TAB_GAME", Color("#F29C5D"), "orange"],
	Tab.GRAPHICS: ["OPT_TAB_GRAPHICS", Color("#7ABD33"), "green"],
	Tab.AUDIO: ["OPT_TAB_AUDIO", Color("#C552F1"), "purple"],
	Tab.CONTROLS: ["OPT_TAB_CONTROLS", Color("#43A6FC"), "blue"],
	Tab.ACCESSIBILITY: ["OPT_TAB_ACCESSIBILITY", Color("#EED35D"), "yellow"],
}

## Rows by index, not text, so the text can be translated.
const _ANIMATION_SPEEDS: Array = [0.5, 1.0, 2.0, 4.0]
const _FPS_LIMITS: Array = [30, 60, 120, 0] # 0 means unlimited

## How long a progress button waits for the second press that confirms it,
## and how long it then says it's done, in seconds.
const _CONFIRM_WINDOW: float = 3.0
const _DONE_TIME: float = 1.5

## Shows Erase Progress and Unlock All on the Game tab. Only the main menu's
## copy does: mid-run, erasing would pull the save out from under the run.
@export var show_progress_tools: bool = false

var _frame: OptionsFrame
var _tab_buttons: Array[Button] = []
var _pages: Dictionary[Tab, OptionsPage] = {}
var _hint_label: RichTextLabel
var _defaults_button: Button
var _open_tab: Tab = Tab.GAME
## Each progress button -> its text, to put back when it disarms.
var _progress_buttons: Dictionary[Button, String] = {}


func _ready() -> void:
	_build_panel()
	_build_pages()
	_show_tab(Tab.GAME)
	OptionsSettings.option_changed.connect(_on_option_changed)
	get_tree().root.size_changed.connect(_refresh_open_page)
	visibility_changed.connect(_on_visibility_changed)


## --- The options ---

func _build_pages() -> void:
	var game: OptionsPage = _pages[Tab.GAME]
	game.choice(OptionsSettings.ANIMATION_SPEED, "OPT_ANIMATION_SPEED",
		["0.5x", "1x", "2x", "4x"], _ANIMATION_SPEEDS, "OPT_ANIMATION_SPEED_HINT")
	var locales: Array[String] = Localization.get_available_locales()
	var locale_names: Array[String] = []
	for locale: String in locales:
		locale_names.append(Localization.get_locale_name(locale))
	game.choice(OptionsSettings.LANGUAGE, "OPT_LANGUAGE", locale_names, locales)
	if show_progress_tools:
		_add_progress_button(game, "OPT_ERASE_PROGRESS", "OPT_ERASE", "OPT_ERASE_PROGRESS_HINT", ProgressTools.erase)
		_add_progress_button(game, "OPT_UNLOCK_ALL", "OPT_UNLOCK", "OPT_UNLOCK_ALL_HINT", ProgressTools.unlock_all)
	game.next_column()
	game.check(OptionsSettings.REGION_ALERTS, "OPT_REGION_ALERTS", "OPT_REGION_ALERTS_HINT")
	# Comfort: background behaviour.
	game.check(OptionsSettings.PAUSE_IN_BACKGROUND, "OPT_PAUSE_IN_BACKGROUND", "OPT_PAUSE_IN_BACKGROUND_HINT")
	# Dice input: asking before a turn ends with dice unplayed.
	game.check(OptionsSettings.CONFIRM_END_TURN, "OPT_CONFIRM_END_TURN", "OPT_CONFIRM_END_TURN_HINT")

	var graphics: OptionsPage = _pages[Tab.GRAPHICS]
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

	var audio: OptionsPage = _pages[Tab.AUDIO]
	audio.slider(OptionsSettings.MASTER_VOLUME, "OPT_GAME_VOLUME")
	audio.slider(OptionsSettings.MUSIC_VOLUME, "OPT_MUSIC_VOLUME")
	audio.slider(OptionsSettings.SFX_VOLUME, "OPT_SFX_VOLUME")
	audio.check(OptionsSettings.MUTE_ALL, "OPT_MUTE_ALL")
	# Comfort: background behaviour.
	audio.check(OptionsSettings.MUTE_IN_BACKGROUND, "OPT_MUTE_IN_BACKGROUND", "OPT_MUTE_IN_BACKGROUND_HINT")

	var controls: OptionsPage = _pages[Tab.CONTROLS]
	# Controls: a row per rebindable action (key, controller), then the cursor.
	for action: StringName in InputBindings.ACTIONS:
		if action == InputBindings.PAD_ONLY[0]:
			controls.next_column()
		var slots: BindingSlots = BindingSlots.new(action, controls.styled_button)
		controls.custom(slots, InputBindings.LABEL_KEYS[action], "OPT_BINDING_HINT",
			InputBindings.option_key(action), slots.refresh)
	var cursor_speed: HSlider = controls.slider(OptionsSettings.CURSOR_SPEED, "OPT_CURSOR_SPEED",
		"OPT_CURSOR_SPEED_HINT", OptionsSettings.CURSOR_SPEEDS.x, OptionsSettings.CURSOR_SPEEDS.y, 0.1)
	# Narrower than on the one-column Audio tab, to fit beside its label.
	cursor_speed.custom_minimum_size.x = OptionsPage.WIDGET_WIDTH
	# Dice input: how dice and tiles are picked up and put down.
	controls.choice(OptionsSettings.DICE_PLACEMENT, "OPT_DICE_PLACEMENT",
		["OPT_DICE_PLACEMENT_DRAG", "OPT_DICE_PLACEMENT_CLICK"],
		[Draggable.PlacementMode.DRAG, Draggable.PlacementMode.CLICK], "OPT_DICE_PLACEMENT_HINT")

	var accessibility: OptionsPage = _pages[Tab.ACCESSIBILITY]
	# Comfort: screenshake, flashing and hit pause.
	accessibility.slider(OptionsSettings.SCREENSHAKE_INTENSITY, "OPT_SCREENSHAKE", "OPT_SCREENSHAKE_HINT")
	accessibility.check(OptionsSettings.REDUCE_FLASHING, "OPT_REDUCE_FLASHING", "OPT_REDUCE_FLASHING_HINT")
	accessibility.check(OptionsSettings.HIT_PAUSE, "OPT_HIT_PAUSE", "OPT_HIT_PAUSE_HINT")
	accessibility.next_column()
	# Colorblind support
	accessibility.check(OptionsSettings.COLOR_SYMBOLS, "OPT_COLOR_SYMBOLS", "OPT_COLOR_SYMBOLS_HINT")
	# Readable font
	accessibility.check(OptionsSettings.READABLE_FONT, "OPT_READABLE_FONT", "OPT_READABLE_FONT_HINT")


## A row whose button changes the player's progress for good, so the first
## press only arms it ("Sure?") and a second, within _CONFIRM_WINDOW, does
## [param action].
func _add_progress_button(page: OptionsPage, label_key: String, text_key: String,
		hint_key: String, action: Callable) -> void:
	var button: Button = page.button(label_key, text_key, Callable(), hint_key)
	button.pressed.connect(_on_progress_pressed.bind(button, action))
	_progress_buttons[button] = text_key


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
	for tab: Tab in _TABS:
		var page: OptionsPage = OptionsPage.new(1 if tab == Tab.AUDIO else 2)
		page.accent = _TABS[tab][1]
		page.widget_color = _TABS[tab][2]
		page.position = body.position
		page.size = Vector2(body.size.x, bottom_bar_top - 12 - body.position.y)
		page.hint_changed.connect(_on_hint_changed)
		add_child(page)
		_pages[tab] = page

	_hint_label = RichTextLabel.new()
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("default_color", Color("#A5A29D"))
	_hint_label.position = Vector2(body.position.x, bottom_bar_top - 12)
	_hint_label.size = Vector2(body.size.x, 12)
	add_child(_hint_label)

	_defaults_button = _add_bottom_button("OPT_DEFAULTS", Vector2(body.position.x, bottom_bar_top), _on_defaults_pressed)
	_defaults_button.mouse_entered.connect(func() -> void: _on_hint_changed(tr("OPT_DEFAULTS_HINT")))
	_defaults_button.mouse_exited.connect(func() -> void: _on_hint_changed(""))
	_defaults_button.hover_text_color = _DEFAULTS_COLOR
	var close_button: Button = _add_bottom_button("OPT_CLOSE", Vector2(body.end.x - _BUTTON_SIZE.x, bottom_bar_top), _on_close_button_pressed)
	close_button.hover_text_color = _CLOSE_COLOR
	_set_button_texture(close_button, _GREEN_BUTTON_TEXTURE)


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
static func _set_button_texture(button: Button, texture: Texture2D) -> void:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, button.custom_minimum_size)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_frame(&"default", atlas)
	button.get_node("AnimatedSprite2D").sprite_frames = frames


## --- Behaviour ---

func _show_tab(tab: Tab) -> void:
	_disarm_progress_buttons()
	_open_tab = tab
	for each: Tab in _pages:
		_pages[each].visible = each == tab
	_frame.active_tab = tab
	_hint_label.text = ""
	_pages[tab].refresh()


func _refresh_open_page() -> void:
	if visible:
		_pages[_open_tab].refresh()


func _on_option_changed(key: StringName, _value: Variant) -> void:
	if key == OptionsSettings.READABLE_FONT:
		_layout_tabs(Rect2(-PANEL_SIZE / 2.0, PANEL_SIZE))
	# One option can change what another may do (fullscreen and the window
	# scale), so the whole page is re-read.
	_refresh_open_page()


func _on_visibility_changed() -> void:
	_disarm_progress_buttons()
	if visible:
		# Options can change while the menu is shut (the dev console, the
		# window going fullscreen from its title bar).
		_pages[_open_tab].refresh()


func _on_hint_changed(text: String) -> void:
	_hint_label.text = text


func _on_defaults_pressed() -> void:
	OptionsSettings.reset_options(_pages[_open_tab].option_keys())


func _on_progress_pressed(button: Button, action: Callable) -> void:
	if not button.has_meta(&"armed_at"):
		var armed_at: int = Time.get_ticks_msec()
		button.set_meta(&"armed_at", armed_at)
		button.text = "OPT_SURE"
		await get_tree().create_timer(_CONFIRM_WINDOW).timeout
		# Unless it was pressed again, or disarmed and armed afresh, meanwhile.
		if button.get_meta(&"armed_at", -1) == armed_at:
			_disarm(button)
		return
	_disarm(button)
	action.call()
	progress_changed.emit()
	button.text = "OPT_DONE"
	await get_tree().create_timer(_DONE_TIME).timeout
	if not button.has_meta(&"armed_at"):
		button.text = _progress_buttons[button]


func _disarm(button: Button) -> void:
	button.remove_meta(&"armed_at")
	button.text = _progress_buttons[button]


func _disarm_progress_buttons() -> void:
	for button: Button in _progress_buttons:
		_disarm(button)


func _on_close_button_pressed() -> void:
	OptionsSettings.save_options_settings()
	hide()
