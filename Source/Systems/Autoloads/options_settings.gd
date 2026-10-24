extends Node
## Persists the player's options (plus the launch counter) to a ConfigFile and
## applies them at startup.
##
## An autoload so settings take effect when the game boots. It used to live
## inside the OptionsMenu scene, so nothing was applied — window size, volume,
## animation speed — until a menu containing it happened to be instanced.

const _SETTINGS_PATH: String = "user://options_settings.cfg"

## Window scales offered, in screen multiples of Globals.SCREEN_SIZE.
const WINDOW_SCALES: Array[int] = [2, 4, 6, 8, 9, 10, 12]


func _ready() -> void:
	Events.save_options_config.connect(save_options_settings)
	load_options_settings()


## Whether the game owns its window. In a browser the page does: size,
## position and vsync can't be set, and fullscreen is only granted in direct
## response to a click, never at boot.
func controls_window() -> bool:
	return not OS.has_feature("web")


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


func save_options_settings() -> void:
	var config: ConfigFile = ConfigFile.new()

	config.set_value("Game", "animation_speed", Globals.animation_speed)
	config.set_value("Game", "language", Localization.get_locale())
	config.set_value("Game", "show_tutorial", Globals.show_tutorial)
	config.set_value("Game", "region_alerts", Globals.show_region_alerts)

	config.set_value("Graphics", "screenshake", Globals.screenshake_enabled)
	config.set_value("Graphics", "max_fps", Engine.max_fps)
	if controls_window():
		config.set_value("Graphics", "vsync", DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED)
		config.set_value("Graphics", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		config.set_value("Graphics", "window_size", DisplayServer.window_get_size())
		config.set_value("Graphics", "window_pos", DisplayServer.window_get_position())

	var master_bus: int = AudioServer.get_bus_index("Master")
	config.set_value("Audio", "master_volume", AudioServer.get_bus_volume_linear(master_bus))
	config.set_value("Audio", "music_volume", AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")))
	config.set_value("Audio", "sfx_volume", AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")))
	config.set_value("Audio", "mute_all", AudioServer.is_bus_mute(master_bus))

	config.set_value("Misc", "times_run", Globals.times_run)

	config.save(_SETTINGS_PATH)


func load_options_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(_SETTINGS_PATH)

	# A missing file is a first launch: every get_value() below falls back to
	# its default.
	if err != OK and err != ERR_FILE_NOT_FOUND:
		printerr("Error loading settings file: ", _SETTINGS_PATH, " (", error_string(err), ")")

	# Empty means nothing chosen yet: Localization picks from the OS language.
	Localization.set_locale(config.get_value("Game", "language", ""))
	Globals.animation_speed = _read_number(config.get_value("Game", "animation_speed", 1.0))
	Globals.show_tutorial = config.get_value("Game", "show_tutorial", true)
	Globals.show_region_alerts = config.get_value("Game", "region_alerts", true)

	Globals.screenshake_enabled = config.get_value("Graphics", "screenshake", true)
	Engine.max_fps = int(_read_number(config.get_value("Graphics", "max_fps", 60)))
	if controls_window():
		_apply_window_settings(config)

	var master_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(master_bus, config.get_value("Audio", "master_volume", 0.5))
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), config.get_value("Audio", "music_volume", 0.5))
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), config.get_value("Audio", "sfx_volume", 0.5))
	AudioServer.set_bus_mute(master_bus, config.get_value("Audio", "mute_all", false))

	Globals.times_run = config.get_value("Misc", "times_run", 0)


func _apply_window_settings(config: ConfigFile) -> void:
	var vsync: bool = config.get_value("Graphics", "vsync", true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	if config.get_value("Graphics", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	var default_size: Vector2 = Globals.SCREEN_SIZE * largest_window_scale()
	var display_size: Vector2 = DisplayServer.screen_get_size()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(config.get_value("Graphics", "window_size", default_size))
	DisplayServer.window_set_position(config.get_value("Graphics", "window_pos", (display_size - default_size) / 2))


## Settings files written before October 2026 stored these as the menu's
## labels ("2x", "Unlimited") rather than as numbers.
static func _read_number(value: Variant) -> float:
	if value is String:
		return 0.0 if value == "Unlimited" else float(value.trim_suffix("x"))
	return float(value)
