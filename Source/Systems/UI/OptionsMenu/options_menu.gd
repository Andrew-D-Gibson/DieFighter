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
	_setup_game_options_UI()
	_setup_graphics_options_UI()
	_setup_audio_sliders()
	
	# Start the options menu on the Game tab
	_on_audio_button_pressed()
		
	
func _on_close_button_pressed() -> void:
	%OptionsSavingManager.save_options_settings()
	hide()


func _on_item_hover() -> void:
	Events.play_sound.emit('hover_thump')


func _setup_game_options_UI() -> void:
	match Globals.animation_speed:
		0.5:
			%AnimationSpeedOptionButton.select(0)
		1.0:
			%AnimationSpeedOptionButton.select(1)
		2.0:
			%AnimationSpeedOptionButton.select(2)
		4.0:
			%AnimationSpeedOptionButton.select(3)
			
	match Engine.max_fps:
		30:
			%FPSLimitOptions.select(0)
		60:
			%FPSLimitOptions.select(1)
		120:
			%FPSLimitOptions.select(2)
		0:
			%FPSLimitOptions.select(3)
		_:
			%FPSLimitOptions.select(1)
			
	var bus_idx: int = AudioServer.get_bus_index("Master")
	%MuteAllSoundsCheckBox.button_pressed = AudioServer.is_bus_mute(bus_idx)


func _setup_graphics_options_UI() -> void:
	%ScreenshakeCheckBox.button_pressed = Globals.screenshake_enabled

	%VSyncCheckBox.button_pressed = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSyncMode.VSYNC_ENABLED)
	
	%FullscreenCheckBox.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	_reduce_scale_options()
	_set_scale_choice_label()
	
	
func _reduce_scale_options() -> void:
	var base_resolution: Vector2 = Vector2(320, 180)
	var display_size: Vector2 = DisplayServer.screen_get_size()
	var max_scale: int = 2

	for scale in [4, 6, 8, 9, 10, 12]:
		if (base_resolution * scale).x <= display_size.x and (base_resolution * scale).y <= display_size.y:
			max_scale = scale
		else:
			break
	
	var max_scale_index: int = Array([2, 4, 6, 8, 9, 10, 12]).find(max_scale)

	for idx: int in range(6, max_scale_index, -1):
		%ScaleOptionButton.remove_item(idx)
	
	
func _set_scale_choice_label() -> void:
	var screen_scale: int = 1
	var current_window_size: Vector2 = DisplayServer.window_get_size() 
	var base_resolution: Vector2 = Vector2(320, 180)
	if current_window_size.x / base_resolution.x == current_window_size.y / base_resolution.y:
		screen_scale = floor(current_window_size.x / base_resolution.x)
		
	var scale_index: int = Array([2, 4, 6, 8, 9, 10, 12]).find(screen_scale)
	%ScaleOptionButton.select(scale_index)
	

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
		%ScaleLabel.add_theme_color_override("default_color", Globals.dark_gray)
		%ScaleOptionButton.select(-1)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		%ScaleLabel.add_theme_color_override("default_color", Globals.red)
		_set_scale_choice_label()
	

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


func _on_animation_speed_option_button_item_selected(index: int) -> void:
	var option_selected: String = %AnimationSpeedOptionButton.get_item_text(index)
	match option_selected:
		"0.5x":
			Globals.animation_speed = 0.5
		"1x":
			Globals.animation_speed = 1
		"2x":
			Globals.animation_speed = 2
		"4x":
			Globals.animation_speed = 4


func _on_fps_limit_options_item_selected(index: int) -> void:
	var option_selected: String = %FPSLimitOptions.get_item_text(index)
	match option_selected:
		"30":
			Engine.max_fps = 30
		"60":
			Engine.max_fps = 60
		"120":
			Engine.max_fps = 120
		"Unlimited":
			Engine.max_fps = 0 # 0 means unlimited


func _on_mute_all_sounds_check_box_toggled(toggled_on: bool) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, toggled_on)


func _on_scale_option_button_item_selected(index: int) -> void:
	var base_resolution: Vector2 = Vector2(320, 180)
	var scale: int = 2
	
	var option_selected: String = %ScaleOptionButton.get_item_text(index)
	match option_selected:
		"2x":
			scale = 2
		"4x":
			scale = 4
		"6x":
			scale = 6
		"8x":
			scale = 8
		"9x":
			scale = 9
		"10x":
			scale = 10
		"12x":
			scale = 12
		
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	var window_size: Vector2 = base_resolution * scale
	DisplayServer.window_set_size(window_size)	
	
	var display_size: Vector2 = DisplayServer.screen_get_size()
	DisplayServer.window_set_position((display_size - window_size) / 2)
	
	%ScaleLabel.add_theme_color_override("default_color", Globals.red)
	%FullscreenCheckBox.button_pressed = false
