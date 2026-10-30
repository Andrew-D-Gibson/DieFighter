extends Node
## Persists the player's options (plus the launch counter and whether the
## tutorial has been played) to a ConfigFile and applies them at startup.
##
## An autoload so settings take effect when the game boots. It used to live
## inside the OptionsMenu scene, so nothing was applied — window size, volume,
## animation speed — until a menu containing it happened to be instanced.
##
## Every option is registered once, in _register_options(): its default, how
## to read its live value and how to apply a new one. Saving, loading, the
## options menu and its "Reset to defaults" all work from that list, so a new
## option is one register() call here plus one row in OptionsMenu.
##
## An option's live value stays wherever the game reads it (Globals, the
## AudioServer, the window): the registry only knows how to get and set it.
## So code that changes one directly (the dev console, the window's title
## bar) is still saved correctly.
##
## Player progress kept here (the launch counter, tutorial_completed) isn't
## registered: it has no menu row and Defaults never touches it.

## Emitted after an option is set through set_option() or reset_options().
signal option_changed(key: StringName, value: Variant)

const _SETTINGS_PATH: String = "user://options_settings.cfg"

const _PROGRESS_SECTION: String = "Progress"
const _TUTORIAL_COMPLETED: String = "tutorial_completed"
## The Game-section key of the old Show Tutorial option, read once to migrate.
const _LEGACY_SHOW_TUTORIAL: String = "show_tutorial"

## --- Option keys ---
## "Section/name", the section and key each is saved under, grouped by the
## options menu tab that shows it. Renaming a key loses what players saved
## under it, so a few keep a section that isn't their tab's.

# Game
const ANIMATION_SPEED: StringName = &"Game/animation_speed"
const LANGUAGE: StringName = &"Game/language"
const REGION_ALERTS: StringName = &"Game/region_alerts"
const PAUSE_IN_BACKGROUND: StringName = &"Game/pause_in_background"
const CONFIRM_END_TURN: StringName = &"Game/confirm_end_turn"

# Graphics
const FULLSCREEN: StringName = &"Graphics/fullscreen"
const PIXEL_PERFECT: StringName = &"Graphics/pixel_perfect"
const WINDOW_SCALE: StringName = &"Graphics/window_scale"
const MONITOR: StringName = &"Graphics/monitor"
const VSYNC: StringName = &"Graphics/vsync"
const MAX_FPS: StringName = &"Graphics/max_fps"
## Window scales offered, in screen multiples of Globals.SCREEN_SIZE.
const WINDOW_SCALES: Array[int] = [2, 4, 6, 8, 9, 10, 12]

# Audio
const MASTER_VOLUME: StringName = &"Audio/master_volume"
const MUSIC_VOLUME: StringName = &"Audio/music_volume"
const SFX_VOLUME: StringName = &"Audio/sfx_volume"
const MUTE_ALL: StringName = &"Audio/mute_all"
const MUTE_IN_BACKGROUND: StringName = &"Audio/mute_in_background"

# Controls (plus a binding per action: InputBindings.option_key())
const CURSOR_SPEED: StringName = &"Controls/cursor_speed"
## The Cursor Speed slider's range, as a multiplier on the controller
## pointer's speed.
const CURSOR_SPEEDS: Vector2 = Vector2(0.5, 2.0)
const DICE_PLACEMENT: StringName = &"Controls/dice_placement"

# Accessibility
const SCREENSHAKE_INTENSITY: StringName = &"Accessibility/screenshake"
## The old on/off screenshake, from when it was a Graphics checkbox. Still
## saved, derived from the intensity, so older settings files migrate (see
## _register_accessibility_options()).
const SCREENSHAKE: StringName = &"Graphics/screenshake"
const REDUCE_FLASHING: StringName = &"Accessibility/reduce_flashing"
const HIT_PAUSE: StringName = &"Accessibility/hit_pause"
const COLOR_SYMBOLS: StringName = &"Accessibility/color_symbols"
const READABLE_FONT: StringName = &"Accessibility/readable_font"

## --- Window recovery ---

## How much of a restored window has to land on a screen for it to count as
## where the player left it. Less, and it was left on a monitor that's gone
## (or off the edge of one that's shrunk), so it's brought back.
const _MIN_ON_SCREEN_SHARE: float = 0.5
## The scale a brought-back window takes when its screen can't say how big
## it is.
const _FALLBACK_WINDOW_SCALE: int = 4
## The buses the volume options set. project.godot names the layout by uid,
## and when the uid cache can't resolve it Godot quietly starts with only
## Master, so the Music and SFX sliders snap back. This file is the fallback.
const _BUS_LAYOUT_PATH: String = "res://default_bus_layout.tres"


class _Option:
	var default: Variant
	var read: Callable
	var write: Callable
	## False for options whose state is saved some other way (the window
	## scale, kept as the window's exact size and position).
	var persist: bool


var pixel_perfect_scaler: PixelPerfectScaler
var background_focus: BackgroundFocus

## In registration order, which is also the order they're applied on load:
## the monitor before the window goes fullscreen on it, and so on.
var _options: Dictionary[StringName, _Option] = {}


func _ready() -> void:
	pixel_perfect_scaler = PixelPerfectScaler.new()
	add_child(pixel_perfect_scaler)
	background_focus = BackgroundFocus.new()
	add_child(background_focus)
	_register_options()
	Events.save_options_config.connect(save_options_settings)
	load_options_settings()


## --- Registry ---

## Adds an option. [param read] returns its live value; [param write] applies
## a new one. Defaults should be what a first launch ought to get.
func register(key: StringName, default: Variant, read: Callable, write: Callable, persist: bool = true) -> void:
	assert(key.count("/") == 1, "Option keys are Section/name: " + key)
	var option: _Option = _Option.new()
	option.default = default
	option.read = read
	option.write = write
	option.persist = persist
	_options[key] = option


## Whether [param key] is offered here. Window options aren't in a browser.
func has_option(key: StringName) -> bool:
	return _options.has(key)


func get_option(key: StringName) -> Variant:
	return _options[key].read.call()


func get_default(key: StringName) -> Variant:
	return _options[key].default


func set_option(key: StringName, value: Variant) -> void:
	var option: _Option = _options[key]
	option.write.call(value)
	option_changed.emit(key, option.read.call())


## Puts each of [param keys] back to its default. Keys that aren't offered
## here are skipped.
func reset_options(keys: Array[StringName]) -> void:
	for key: StringName in keys:
		if has_option(key):
			set_option(key, get_default(key))


## --- The options ---

## Tab by tab, in the menu's order. Load order matters in two places, both
## kept within a tab: the monitor before fullscreen, and the old screenshake
## checkbox after the slider.
func _register_options() -> void:
	_register_game_options()
	_register_graphics_options()
	_register_audio_options()
	_register_controls_options()
	_register_accessibility_options()


func _register_game_options() -> void:
	register(ANIMATION_SPEED, 1.0,
		func() -> float: return Globals.animation_speed,
		func(value: Variant) -> void: Globals.animation_speed = _read_number(value))
	# Empty means nothing chosen yet: Localization picks from the OS language.
	register(LANGUAGE, "",
		Localization.get_locale,
		func(value: Variant) -> void: Localization.set_locale(str(value)))
	register(REGION_ALERTS, true,
		func() -> bool: return Globals.show_region_alerts,
		func(value: Variant) -> void: Globals.show_region_alerts = bool(value))
	register(PAUSE_IN_BACKGROUND, false,
		func() -> bool: return background_focus.pause_in_background,
		func(value: Variant) -> void: background_focus.pause_in_background = bool(value))
	# The live value is a static on the class that reads it, so it's set
	# before any player exists.
	register(CONFIRM_END_TURN, true,
		func() -> bool: return EndTurnConfirm.enabled,
		func(value: Variant) -> void: EndTurnConfirm.enabled = bool(value))


func _register_graphics_options() -> void:
	if controls_window():
		register(MONITOR, DisplayServer.get_primary_screen(),
			DisplayServer.window_get_current_screen,
			_move_to_monitor)
		register(VSYNC, true,
			func() -> bool: return DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED,
			func(value: Variant) -> void:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED))
		register(PIXEL_PERFECT, true,
			pixel_perfect_scaler.is_wanted,
			func(value: Variant) -> void: pixel_perfect_scaler.set_wanted(bool(value)))
		register(WINDOW_SCALE, largest_window_scale(), current_window_scale, _set_window_scale, false)
	# After the monitor, so it goes fullscreen on the right one. Works in a
	# browser too (the checkbox is a click, which browsers allow), but can't
	# be restored at boot there.
	register(FULLSCREEN, false, is_fullscreen, _set_fullscreen, controls_window())
	register(MAX_FPS, 60,
		func() -> int: return Engine.max_fps,
		func(value: Variant) -> void: Engine.max_fps = int(_read_number(value)))


func _register_audio_options() -> void:
	_ensure_bus_layout()
	_register_bus_volume(MASTER_VOLUME, "Master")
	_register_bus_volume(MUSIC_VOLUME, "Music")
	_register_bus_volume(SFX_VOLUME, "SFX")
	register(MUTE_ALL, false,
		func() -> bool: return AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		func(value: Variant) -> void: AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), bool(value)))
	register(MUTE_IN_BACKGROUND, true,
		func() -> bool: return background_focus.mute_in_background,
		func(value: Variant) -> void: background_focus.mute_in_background = bool(value))


## Loads the project's bus layout by path if the engine started without it.
func _ensure_bus_layout() -> void:
	if AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("SFX") != -1:
		return
	push_warning("Audio buses missing at boot (bus layout uid unresolved); loading %s" % _BUS_LAYOUT_PATH)
	AudioServer.set_bus_layout(load(_BUS_LAYOUT_PATH) as AudioBusLayout)


func _register_bus_volume(key: StringName, bus: StringName) -> void:
	register(key, 0.5,
		func() -> float: return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)),
		func(value: Variant) -> void: AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), float(value)))


## Key and controller bindings, one option per action (InputBindings), the
## controller pointer's speed, and how dice are picked up and put down.
func _register_controls_options() -> void:
	for action: StringName in InputBindings.ACTIONS:
		register(InputBindings.option_key(action), InputBindings.default_value(action),
			func() -> Array: return InputBindings.read(action),
			func(value: Variant) -> void: InputBindings.write(action, value))
	register(CURSOR_SPEED, 1.0,
		func() -> float: return InputManager.cursor.speed_scale,
		func(value: Variant) -> void:
			InputManager.cursor.speed_scale = clampf(float(value), CURSOR_SPEEDS.x, CURSOR_SPEEDS.y))
	# A static on Draggable, so it's set before any die exists.
	register(DICE_PLACEMENT, Draggable.PlacementMode.DRAG,
		func() -> int: return Draggable.placement_mode,
		func(value: Variant) -> void:
			var mode: int = int(value)
			Draggable.placement_mode = mode as Draggable.PlacementMode \
				if Draggable.PlacementMode.values().has(mode) else Draggable.PlacementMode.DRAG)


## Comfort (screenshake, flashing, hit pause), colour symbols for players who
## can't rely on colour alone, and the readable font.
func _register_accessibility_options() -> void:
	register(SCREENSHAKE_INTENSITY, 1.0,
		func() -> float: return Globals.screenshake_intensity,
		func(value: Variant) -> void: Globals.screenshake_intensity = clampf(float(value), 0.0, 1.0))
	# The old checkbox, loaded after the slider: a file from before the slider
	# has no intensity, so it comes in at full, and the old "off" then takes
	# it to zero. Saved as "intensity above zero", so in a newer file it always
	# agrees with the slider and loading it changes nothing.
	register(SCREENSHAKE, true,
		func() -> bool: return Globals.screenshake_enabled,
		func(value: Variant) -> void:
			if not bool(value):
				Globals.screenshake_intensity = 0.0)
	register(REDUCE_FLASHING, false,
		func() -> bool: return Globals.reduce_flashing,
		func(value: Variant) -> void: Globals.reduce_flashing = bool(value))
	register(HIT_PAUSE, true,
		func() -> bool: return TimeDirector.hitstop_enabled,
		func(value: Variant) -> void: TimeDirector.hitstop_enabled = bool(value))
	register(COLOR_SYMBOLS, false,
		func() -> bool: return ColorSymbolBadge.symbols_enabled,
		func(value: Variant) -> void: ColorSymbolBadge.symbols_enabled = bool(value))
	register(READABLE_FONT, false, FontSwap.is_readable,
		func(value: Variant) -> void: FontSwap.set_readable(bool(value)))


## --- Window ---

## Whether the game owns its window. In a browser the page does: size,
## position and vsync can't be set, and fullscreen is only granted in direct
## response to a click, never at boot.
func controls_window() -> bool:
	return not OS.has_feature("web")


func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## The largest window scale that still fits on the current display.
func largest_window_scale() -> int:
	return maxi(_largest_scale_within(DisplayServer.screen_get_size()), WINDOW_SCALES[0])


## The largest offered scale whose window fits in [param area], or
## _FALLBACK_WINDOW_SCALE when the area is unknown (zero). The smallest scale
## if none fits.
static func scale_to_fit(area: Vector2i) -> int:
	if area.x <= 0 or area.y <= 0:
		return _FALLBACK_WINDOW_SCALE
	return maxi(_largest_scale_within(area), WINDOW_SCALES[0])


## 0 if not even the smallest scale fits.
static func _largest_scale_within(area: Vector2i) -> int:
	var best: int = 0
	for scale: int in WINDOW_SCALES:
		var size: Vector2 = Globals.SCREEN_SIZE * scale
		if size.x > area.x or size.y > area.y:
			break
		best = scale
	return best


## Whether enough of [param window] lies on [param screens] to call it on
## screen (see _MIN_ON_SCREEN_SHARE). Screens never overlap, so a window
## straddling two counts what's on each.
static func is_on_screens(window: Rect2i, screens: Array[Rect2i]) -> bool:
	var area: int = window.get_area()
	if area <= 0:
		return false
	var on_screen: int = 0
	for screen: Rect2i in screens:
		on_screen += window.intersection(screen).get_area()
	return on_screen >= area * _MIN_ON_SCREEN_SHARE


## The window's scale when it's exactly one of the offered sizes, else 0 (a
## size dragged out by hand, or fullscreen).
func current_window_scale() -> int:
	if is_fullscreen():
		return 0
	var size: Vector2i = DisplayServer.window_get_size()
	var scale: int = size.x / int(Globals.SCREEN_SIZE.x)
	if Vector2i(Globals.SCREEN_SIZE * scale) != size or not WINDOW_SCALES.has(scale):
		return 0
	return scale


func _set_fullscreen(value: Variant) -> void:
	if bool(value) == is_fullscreen():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)


## Leaves fullscreen if need be, and centres the resized window on its screen.
func _set_window_scale(value: Variant) -> void:
	var scale: int = int(value)
	if not WINDOW_SCALES.has(scale):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var window_size: Vector2i = Vector2i(Globals.SCREEN_SIZE * scale)
	DisplayServer.window_set_size(window_size)
	_centre_window(window_size)


## Centres the window in the part of its screen the menu bar, dock or
## taskbar leave free.
func _centre_window(window_size: Vector2i) -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(_window_screen())
	DisplayServer.window_set_position(usable.position + (usable.size - window_size) / 2)


## The screen the window is on, or the primary one if that can't be told.
func _window_screen() -> int:
	var screen: int = DisplayServer.window_get_current_screen()
	if screen < 0 or screen >= DisplayServer.get_screen_count():
		return DisplayServer.get_primary_screen()
	return screen


## Moves the window to another monitor, staying fullscreen if it was. A saved
## monitor that's since been unplugged falls back to the primary one.
func _move_to_monitor(value: Variant) -> void:
	var screen: int = int(value)
	if screen < 0 or screen >= DisplayServer.get_screen_count():
		screen = DisplayServer.get_primary_screen()
	if screen == DisplayServer.window_get_current_screen():
		return
	var was_fullscreen: bool = is_fullscreen()
	if was_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(screen)
	if was_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		_centre_window(DisplayServer.window_get_size())


## Puts a windowed game back where it was and at the size it was. A saved
## spot that's no longer on any screen (its monitor unplugged, or the display
## shrunk) brings it back instead: centred on the screen it's on now, at the
## largest offered scale that fits there.
func _restore_window(config: ConfigFile) -> void:
	var default_size: Vector2i = Vector2i(Globals.SCREEN_SIZE * largest_window_scale())
	var window_size: Vector2i = config.get_value("Graphics", "window_size", default_size)
	if config.has_section_key("Graphics", "window_pos"):
		var window_pos: Vector2i = config.get_value("Graphics", "window_pos")
		if is_on_screens(Rect2i(window_pos, window_size), _usable_screen_rects()):
			DisplayServer.window_set_size(window_size)
			DisplayServer.window_set_position(window_pos)
			return
		var usable: Vector2i = DisplayServer.screen_get_usable_rect(_window_screen()).size
		window_size = Vector2i(Globals.SCREEN_SIZE * scale_to_fit(usable))
	DisplayServer.window_set_size(window_size)
	_centre_window(window_size)


## Every screen's area free of menu bars, docks and taskbars, in the same
## desktop coordinates as the window's position.
func _usable_screen_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for screen: int in DisplayServer.get_screen_count():
		rects.append(DisplayServer.screen_get_usable_rect(screen))
	return rects


## --- Saving and loading ---

func save_options_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in _options:
		if _options[key].persist:
			config.set_value(_section(key), _name(key), get_option(key))

	# Where and how big the window was, so a hand-dragged size comes back too.
	if controls_window():
		config.set_value("Graphics", "window_size", DisplayServer.window_get_size())
		config.set_value("Graphics", "window_pos", DisplayServer.window_get_position())

	config.set_value("Misc", "times_run", Globals.times_run)
	config.set_value(_PROGRESS_SECTION, _TUTORIAL_COMPLETED, Globals.tutorial_completed)

	config.save(_SETTINGS_PATH)


func load_options_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(_SETTINGS_PATH)

	# A missing file is a first launch: every option falls back to its default.
	if err != OK and err != ERR_FILE_NOT_FOUND:
		printerr("Error loading settings file: ", _SETTINGS_PATH, " (", error_string(err), ")")

	for key: StringName in _options:
		if _options[key].persist:
			_options[key].write.call(config.get_value(_section(key), _name(key), get_default(key)))

	if controls_window() and not is_fullscreen():
		_restore_window(config)

	Globals.times_run = config.get_value("Misc", "times_run", 0)
	Globals.tutorial_completed = read_tutorial_completed(config)


## Whether [param config] says the tutorial has been played. Files from before
## it was progress had a Show Tutorial option instead, switched off when the
## tutorial finished (or by hand): either way that player shouldn't be put
## back through it.
static func read_tutorial_completed(config: ConfigFile) -> bool:
	if config.has_section_key(_PROGRESS_SECTION, _TUTORIAL_COMPLETED):
		return bool(config.get_value(_PROGRESS_SECTION, _TUTORIAL_COMPLETED))
	return not bool(config.get_value("Game", _LEGACY_SHOW_TUTORIAL, true))


static func _section(key: StringName) -> String:
	return key.get_slice("/", 0)


static func _name(key: StringName) -> String:
	return key.get_slice("/", 1)


## Settings files written before October 2026 stored these as the menu's
## labels ("2x", "Unlimited") rather than as numbers.
static func _read_number(value: Variant) -> float:
	if value is String:
		return 0.0 if value == "Unlimited" else float(value.trim_suffix("x"))
	return float(value)
