class_name OptionsSavingManager
extends Node

var _settings_path: String = "user://options_settings.cfg"


func save_options_settings() -> void:	
	var config = ConfigFile.new()
	
	# Game settings
	
	# Graphics settings
	var graphics_settings: Dictionary[String, bool] = _get_current_graphics_settings()
	config.set_value("Graphics", "screenshake", graphics_settings["screenshake"])
	config.set_value("Graphics", "vsync", graphics_settings["vsync"])
	config.set_value("Graphics", "fullscreen", graphics_settings["fullscreen"])
	
	# Audio settings
	var audio_settings: Dictionary[String, float] = _get_current_audio_settings()
	config.set_value("Audio", "master_volume", audio_settings["master_volume"])
	config.set_value("Audio", "music_volume", audio_settings["music_volume"])
	config.set_value("Audio", "sfx_volume", audio_settings["sfx_volume"])

	config.save(_settings_path)
	
	
func load_options_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(_settings_path)

	# If the file didn't load, ignore it
	if err != OK:
		printerr("Error loading settings file: ", _settings_path)
		return

	# Graphics
	var graphics_settings: Dictionary[String, bool] = {}
	graphics_settings["screenshake"] = config.get_value("Graphics", "screenshake", true)
	graphics_settings["vsync"] = config.get_value("Graphics", "vsync", true)
	graphics_settings["fullscreen"] = config.get_value("Graphics", "fullscreen", false)
	_set_graphics_settings(graphics_settings)

	# Audio
	var audio_settings: Dictionary[String, float] = {}
	audio_settings["master_volume"] = config.get_value("Audio", "master_volume", 0.5)
	audio_settings["music_volume"] = config.get_value("Audio", "music_volume", 0.5)
	audio_settings["sfx_volume"] = config.get_value("Audio", "sfx_volume", 0.5)
	_set_audio_settings(audio_settings)


func _get_current_graphics_settings() -> Dictionary[String, bool]:
	var graphics_settings: Dictionary[String, bool] = {}
	
	graphics_settings["screenshake"] = Globals.screenshake_enabled
	graphics_settings["vsync"] = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSyncMode.VSYNC_ENABLED)
	graphics_settings["fullscreen"] = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	return graphics_settings
	
	
func _set_graphics_settings(graphics_settings: Dictionary[String, bool]) -> void:
	Globals.screenshake_enabled = graphics_settings["screenshake"]
	
	if graphics_settings["vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
	if graphics_settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	
func _get_current_audio_settings() -> Dictionary[String, float]:
	var audio_settings: Dictionary[String, float] = {}
	
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	var music_bus_index: int = AudioServer.get_bus_index("Music")
	var sfx_bus_index: int = AudioServer.get_bus_index("SFX")
	
	audio_settings["master_volume"] = 	AudioServer.get_bus_volume_linear(master_bus_index)
	audio_settings["music_volume"] = 	AudioServer.get_bus_volume_linear(music_bus_index)
	audio_settings["sfx_volume"] = 	AudioServer.get_bus_volume_linear(sfx_bus_index)

	return audio_settings
	

func _set_audio_settings(audio_settings: Dictionary[String, float]) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	var music_bus_index: int = AudioServer.get_bus_index("Music")
	var sfx_bus_index: int = AudioServer.get_bus_index("SFX")
	
	AudioServer.set_bus_volume_linear(master_bus_index, audio_settings["master_volume"])
	AudioServer.set_bus_volume_linear(music_bus_index, audio_settings["music_volume"])
	AudioServer.set_bus_volume_linear(sfx_bus_index, audio_settings["sfx_volume"])
