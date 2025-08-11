class_name OptionsMenu
extends Node2D

@export var _game_options: Control
@export var _graphics_options: Control
@export var _audio_options: Control

enum ScreenShowing {GAME, GRAPHICS, AUDIO}
var screen_showing: ScreenShowing


func _ready() -> void:
	%OptionsSavingManager.load_options_settings()
	
	# Set up the UI elements to reflect the loaded settings
	_setup_graphics_options_UI()
	_setup_audio_sliders()
	
	# Start the options menu on the Game tab
	_on_audio_button_pressed()
	
	
func _on_close_button_pressed() -> void:
	%OptionsSavingManager.save_options_settings()
	hide()


func _on_item_hover() -> void:
	Events.play_sound.emit('tile_dropped')


func _setup_graphics_options_UI() -> void:
	%ScreenshakeCheckBox.button_pressed = Globals.screenshake_enabled

	%VSyncCheckBox.button_pressed = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSyncMode.VSYNC_ENABLED)
	
	%FullscreenCheckBox.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_screenshake_check_box_toggled(toggled_on: bool) -> void:
	Globals.screenshake_enabled = toggled_on
	
	
func _on_v_sync_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSyncMode.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSyncMode.VSYNC_DISABLED)
	
	
func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	

func _setup_audio_sliders() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	var music_bus_index: int = AudioServer.get_bus_index("Music")
	var sfx_bus_index: int = AudioServer.get_bus_index("SFX")
	
	%GameVolumeSlider.value = AudioServer.get_bus_volume_linear(master_bus_index)
	%MusicVolumeSlider.value = AudioServer.get_bus_volume_linear(music_bus_index)
	%SFXVolumeSlider.value = AudioServer.get_bus_volume_linear(sfx_bus_index)
	
	
func _on_game_volume_slider_value_changed(value: float) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(master_bus_index, %GameVolumeSlider.value)
	
	%GameVolumeKnobLabel.text = str(int(%GameVolumeSlider.value * 100)) + '%'
	%GameVolumeKnobLabel.global_position.x = \
		%GameVolumeSlider.global_position.x + \
		(%GameVolumeSlider.value / %GameVolumeSlider.max_value) * \
		(%GameVolumeSlider.size.x - 24)
		

func _on_music_volume_slider_value_changed(value: float) -> void:
	var music_bus_index: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_linear(music_bus_index, %MusicVolumeSlider.value)
	
	%MusicVolumeKnobLabel.text = str(int(%MusicVolumeSlider.value * 100)) + '%'
	%MusicVolumeKnobLabel.global_position.x = \
		%MusicVolumeSlider.global_position.x + \
		(%MusicVolumeSlider.value / %MusicVolumeSlider.max_value) * \
		(%MusicVolumeSlider.size.x - 24)


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	var sfx_bus_index: int = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_linear(sfx_bus_index, %SFXVolumeSlider.value)
	
	%SFXVolumeKnobLabel.text = str(int(%SFXVolumeSlider.value * 100)) + '%'
	%SFXVolumeKnobLabel.global_position.x = \
		%SFXVolumeSlider.global_position.x + \
		(%SFXVolumeSlider.value / %SFXVolumeSlider.max_value) * \
		(%SFXVolumeSlider.size.x - 24)		


func _on_game_button_pressed() -> void:
	_game_options.show()
	_graphics_options.hide()
	_audio_options.hide()
	
	%Background.frame = 0
	screen_showing = ScreenShowing.GAME


func _on_graphics_button_pressed() -> void:
	_game_options.hide()
	_graphics_options.show()
	_audio_options.hide()
	
	%Background.frame = 1
	screen_showing = ScreenShowing.GRAPHICS
	

func _on_audio_button_pressed() -> void:
	_game_options.hide()
	_graphics_options.hide()
	_audio_options.show()
	
	%Background.frame = 2
	screen_showing = ScreenShowing.AUDIO
