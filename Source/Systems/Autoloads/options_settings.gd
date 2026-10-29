extends Node
## Persists the player's options (plus the launch counter) to a ConfigFile and
## applies them at startup.
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
## So code that changes one directly (the tutorial turning itself off) is
## still saved correctly.

## Emitted after an option is set through set_option() or reset_options().
signal option_changed(key: StringName, value: Variant)

const _SETTINGS_PATH: String = "user://options_settings.cfg"

## Window scales offered, in screen multiples of Globals.SCREEN_SIZE.
const WINDOW_SCALES: Array[int] = [2, 4, 6, 8, 9, 10, 12]

## Option keys are "Section/name", the section and key they're saved under.
const ANIMATION_SPEED: StringName = &"Game/animation_speed"
const LANGUAGE: StringName = &"Game/language"
const SHOW_TUTORIAL: StringName = &"Game/show_tutorial"
const REGION_ALERTS: StringName = &"Game/region_alerts"
const FULLSCREEN: StringName = &"Graphics/fullscreen"
const PIXEL_PERFECT: StringName = &"Graphics/pixel_perfect"
const WINDOW_SCALE: StringName = &"Graphics/window_scale"
const MONITOR: StringName = &"Graphics/monitor"
const VSYNC: StringName = &"Graphics/vsync"
const MAX_FPS: StringName = &"Graphics/max_fps"
## The old on/off screenshake. Still saved, derived from the intensity, so
## older settings files migrate (see _register_comfort_options()).
const SCREENSHAKE: StringName = &"Graphics/screenshake"
const MASTER_VOLUME: StringName = &"Audio/master_volume"
const MUSIC_VOLUME: StringName = &"Audio/music_volume"
const SFX_VOLUME: StringName = &"Audio/sfx_volume"
const MUTE_ALL: StringName = &"Audio/mute_all"
# Colorblind support
const COLOR_SYMBOLS: StringName = &"Accessibility/color_symbols"
const SCREENSHAKE_INTENSITY: StringName = &"Accessibility/screenshake"
const REDUCE_FLASHING: StringName = &"Accessibility/reduce_flashing"
const HIT_PAUSE: StringName = &"Accessibility/hit_pause"
const MUTE_IN_BACKGROUND: StringName = &"Audio/mute_in_background"
const PAUSE_IN_BACKGROUND: StringName = &"Game/pause_in_background"
const DICE_PLACEMENT: StringName = &"Controls/dice_placement"
const CONFIRM_END_TURN: StringName = &"Game/confirm_end_turn"
const CURSOR_SPEED: StringName = &"Controls/cursor_speed"
## The Cursor Speed slider's range, as a multiplier on the controller
## pointer's speed.
const CURSOR_SPEEDS: Vector2 = Vector2(0.5, 2.0)


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

func _register_options() -> void:
	register(ANIMATION_SPEED, 1.0,
		func() -> float: return Globals.animation_speed,
		func(value: Variant) -> void: Globals.animation_speed = _read_number(value))
	# Empty means nothing chosen yet: Localization picks from the OS language.
	register(LANGUAGE, "",
		Localization.get_locale,
		func(value: Variant) -> void: Localization.set_locale(str(value)))
	register(SHOW_TUTORIAL, true,
		func() -> bool: return Globals.show_tutorial,
		func(value: Variant) -> void: Globals.show_tutorial = bool(value))
	register(REGION_ALERTS, true,
		func() -> bool: return Globals.show_region_alerts,
		func(value: Variant) -> void: Globals.show_region_alerts = bool(value))

	if controls_window():
		_register_window_options()
	# After the monitor, so it goes fullscreen on the right one. Works in a
	# browser too (the checkbox is a click, which browsers allow), but can't
	# be restored at boot there.
	register(FULLSCREEN, false, is_fullscreen, _set_fullscreen, controls_window())
	register(MAX_FPS, 60,
		func() -> int: return Engine.max_fps,
		func(value: Variant) -> void: Engine.max_fps = int(_read_number(value)))

	_register_bus_volume(MASTER_VOLUME, "Master")
	_register_bus_volume(MUSIC_VOLUME, "Music")
	_register_bus_volume(SFX_VOLUME, "SFX")
	register(MUTE_ALL, false,
		func() -> bool: return AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		func(value: Variant) -> void: AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), bool(value)))
	_register_colorblind_options()

	_register_comfort_options()
	_register_controls_options()
	_register_dice_input_options()


## Screenshake, flashing, hit pause, and what happens in the background.
func _register_comfort_options() -> void:
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

	background_focus = BackgroundFocus.new()
	add_child(background_focus)
	register(MUTE_IN_BACKGROUND, true,
		func() -> bool: return background_focus.mute_in_background,
		func(value: Variant) -> void: background_focus.mute_in_background = bool(value))
	register(PAUSE_IN_BACKGROUND, false,
		func() -> bool: return background_focus.pause_in_background,
		func(value: Variant) -> void: background_focus.pause_in_background = bool(value))


## Key and controller bindings, one option per action (InputBindings), and the
## controller pointer's speed.
func _register_controls_options() -> void:
	for action: StringName in InputBindings.ACTIONS:
		register(InputBindings.option_key(action), InputBindings.default_value(action),
			func() -> Array: return InputBindings.read(action),
			func(value: Variant) -> void: InputBindings.write(action, value))
	register(CURSOR_SPEED, 1.0,
		func() -> float: return InputManager.cursor.speed_scale,
		func(value: Variant) -> void:
			InputManager.cursor.speed_scale = clampf(float(value), CURSOR_SPEEDS.x, CURSOR_SPEEDS.y))


## Dice placement and the End Turn check. Both live values are statics on
## the classes that read them, so they're set before any die or player exists.
func _register_dice_input_options() -> void:
	register(DICE_PLACEMENT, Draggable.PlacementMode.DRAG,
		func() -> int: return Draggable.placement_mode,
		func(value: Variant) -> void:
			var mode: int = int(value)
			Draggable.placement_mode = mode as Draggable.PlacementMode \
				if Draggable.PlacementMode.values().has(mode) else Draggable.PlacementMode.DRAG)
	register(CONFIRM_END_TURN, true,
		func() -> bool: return EndTurnConfirm.enabled,
		func(value: Variant) -> void: EndTurnConfirm.enabled = bool(value))


func _register_window_options() -> void:
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


## Shapes beside colours for players who can't rely on colour alone.
func _register_colorblind_options() -> void:
	register(COLOR_SYMBOLS, false,
		func() -> bool: return ColorSymbolBadge.symbols_enabled,
		func(value: Variant) -> void: ColorSymbolBadge.symbols_enabled = bool(value))


func _register_bus_volume(key: StringName, bus: StringName) -> void:
	register(key, 0.5,
		func() -> float: return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)),
		func(value: Variant) -> void: AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), float(value)))


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
	var display_size: Vector2 = DisplayServer.screen_get_size()
	var best: int = WINDOW_SCALES[0]
	for scale: int in WINDOW_SCALES:
		var size: Vector2 = Globals.SCREEN_SIZE * scale
		if size.x > display_size.x or size.y > display_size.y:
			break
		best = scale
	return best


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


func _centre_window(window_size: Vector2i) -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var screen_rect: Rect2i = Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - window_size) / 2)


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


func _restore_window(config: ConfigFile) -> void:
	var default_size: Vector2i = Vector2i(Globals.SCREEN_SIZE * largest_window_scale())
	var window_size: Vector2i = config.get_value("Graphics", "window_size", default_size)
	DisplayServer.window_set_size(window_size)
	if config.has_section_key("Graphics", "window_pos"):
		DisplayServer.window_set_position(config.get_value("Graphics", "window_pos"))
	else:
		_centre_window(window_size)


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
