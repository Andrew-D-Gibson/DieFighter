class_name OptionsSavingManager
extends Node

var _settings_path: String = "user://options_settings.cfg"


func save_options_settings() -> void:	
	var config = ConfigFile.new()
	
	# Game settings
	var game_settings: Dictionary = _get_current_game_settings()
	print(game_settings)
	config.set_value("Game", "animation_speed", game_settings["animation_speed"])
	
	# Graphics settings
	var graphics_settings: Dictionary = _get_current_graphics_settings()
	config.set_value("Graphics", "screenshake", graphics_settings["screenshake"])
	config.set_value("Graphics", "vsync", graphics_settings["vsync"])
	config.set_value("Graphics", "fullscreen", graphics_settings["fullscreen"])
	config.set_value("Graphics", "max_fps", graphics_settings["max_fps"])
	
	# Audio settings
	var audio_settings: Dictionary = _get_current_audio_settings()
	config.set_value("Audio", "master_volume", audio_settings["master_volume"])
	config.set_value("Audio", "music_volume", audio_settings["music_volume"])
	config.set_value("Audio", "sfx_volume", audio_settings["sfx_volume"])
	config.set_value("Audio", "mute_all", audio_settings["mute_all"])

	# Misc. settings
	config.set_value("Misc", "times_run", Globals.times_run)

	config.save(_settings_path)
	
	
func load_options_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(_settings_path)

	# If the file didn't load, ignore it
	if err != OK:
		printerr("Error loading settings file: ", _settings_path)
		return
		
	# Game
	var game_settings: Dictionary = {}
	game_settings["language"] = config.get_value("Game", "language", "eng")
	game_settings["animation_speed"] = config.get_value("Game", "animation_speed", "1x")
	_set_game_settings(game_settings)

	# Graphics
	var graphics_settings: Dictionary = {}
	graphics_settings["screenshake"] = config.get_value("Graphics", "screenshake", true)
	graphics_settings["vsync"] = config.get_value("Graphics", "vsync", true)
	graphics_settings["fullscreen"] = config.get_value("Graphics", "fullscreen", false)
	graphics_settings["max_fps"] = config.get_value("Graphics", "max_fps", "60")
	_set_graphics_settings(graphics_settings)

	# Audio
	var audio_settings: Dictionary = {}
	audio_settings["master_volume"] = config.get_value("Audio", "master_volume", 0.5)
	audio_settings["music_volume"] = config.get_value("Audio", "music_volume", 0.5)
	audio_settings["sfx_volume"] = config.get_value("Audio", "sfx_volume", 0.5)
	audio_settings["mute_all"] = config.get_value("Audio", "mute_all", false)
	_set_audio_settings(audio_settings)
	
	# Misc.
	var times_run: int = config.get_value("Misc", "times_run", 0)
	Globals.times_run = times_run


func _get_current_game_settings() -> Dictionary:
	var game_settings: Dictionary = {}
	
	match Globals.animation_speed:
		0.5:
			game_settings["animation_speed"] = "0.5x"
		1.0:
			game_settings["animation_speed"] = "1x"
		2.0:
			game_settings["animation_speed"] = "2x"
		4.0:
			game_settings["animation_speed"] = "4x"
		_:
			game_settings["animation_speed"] = "1x"
			
	return game_settings
	
	
func _set_game_settings(game_settings: Dictionary) -> void:
	# TODO: Set Language with game_settings["language"]
	match game_settings["animation_speed"]:
		"0.5x":
			Globals.animation_speed = 0.5
		"1x": 
			Globals.animation_speed = 1
		"2x":
			Globals.animation_speed = 2
		"4x":
			Globals.animation_speed = 4
	

func _get_current_graphics_settings() -> Dictionary:
	var graphics_settings: Dictionary = {}
	
	graphics_settings["screenshake"] = Globals.screenshake_enabled
	graphics_settings["vsync"] = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSyncMode.VSYNC_ENABLED)
	graphics_settings["fullscreen"] = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	match Engine.max_fps:
		30:
			graphics_settings["max_fps"] = "30"
		60:
			graphics_settings["max_fps"] = "60"
		120:
			graphics_settings["max_fps"] = "120"
		0:
			graphics_settings["max_fps"] = "Unlimited"
		_:
			graphics_settings["max_fps"] = "60"
	
	return graphics_settings
	
	
func _set_graphics_settings(graphics_settings: Dictionary) -> void:
	# Screenshake
	Globals.screenshake_enabled = graphics_settings["screenshake"]
	
	# V-Sync
	if graphics_settings["vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
	# Fullscreen
	if graphics_settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# FPS Limit
	match graphics_settings["max_fps"]:
		"30":
			Engine.max_fps = 30
		"60":
			Engine.max_fps = 60
		"120":
			Engine.max_fps = 120
		"Unlimited":
			Engine.max_fps = 0 # 0 means unlimited
		_:
			Engine.max_fps = 60
	
	
func _get_current_audio_settings() -> Dictionary:
	var audio_settings: Dictionary = {}
	
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	var music_bus_index: int = AudioServer.get_bus_index("Music")
	var sfx_bus_index: int = AudioServer.get_bus_index("SFX")
	
	audio_settings["master_volume"] = 	AudioServer.get_bus_volume_linear(master_bus_index)
	audio_settings["music_volume"] = 	AudioServer.get_bus_volume_linear(music_bus_index)
	audio_settings["sfx_volume"] = 	AudioServer.get_bus_volume_linear(sfx_bus_index)
	audio_settings["mute_all"] = AudioServer.is_bus_mute(master_bus_index)

	return audio_settings
	

func _set_audio_settings(audio_settings: Dictionary) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	var music_bus_index: int = AudioServer.get_bus_index("Music")
	var sfx_bus_index: int = AudioServer.get_bus_index("SFX")
	
	AudioServer.set_bus_volume_linear(master_bus_index, audio_settings["master_volume"])
	AudioServer.set_bus_volume_linear(music_bus_index, audio_settings["music_volume"])
	AudioServer.set_bus_volume_linear(sfx_bus_index, audio_settings["sfx_volume"])

	AudioServer.set_bus_mute(master_bus_index, audio_settings["mute_all"])
