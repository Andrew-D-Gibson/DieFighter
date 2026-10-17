class_name OptionsMenu
extends Node2D

const _HOVER_THUMP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")

@export var _game_options: Control
@export var _graphics_options: Control
@export var _audio_options: Control

enum ScreenShowing {GAME, GRAPHICS, AUDIO}
var screen_showing: ScreenShowing

# What each dropdown row means, by index. Rows are matched by position, not by
# their text, so the text can be translated.
const _ANIMATION_SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]
const _FPS_LIMITS: Array[int] = [30, 60, 120, 0] # 0 means unlimited
const _WINDOW_SCALES: Array[int] = [2, 4, 6, 8, 9, 10, 12]

## Locale codes in the language dropdown's row order.
var _language_locales: Array[String] = []


func _ready() -> void:
	# Settings were loaded and applied at startup by the OptionsSettings
	# autoload; the UI just reflects them.
	_setup_game_options_UI()
	_setup_graphics_options_UI()
	_setup_audio_sliders()
	
	# Start the options menu on the Game tab
	_on_audio_button_pressed()
		
	
func _on_close_button_pressed() -> void:
	OptionsSettings.save_options_settings()
	hide()


func _on_item_hover() -> void:
	Events.play_sound.emit(_HOVER_THUMP_SFX)


func _setup_game_options_UI() -> void:
	%AnimationSpeedOptionButton.select(_ANIMATION_SPEEDS.find(Globals.animation_speed))

	var fps_index: int = _FPS_LIMITS.find(Engine.max_fps)
	%FPSLimitOptions.select(fps_index if fps_index >= 0 else _FPS_LIMITS.find(60))

	_setup_language_options()
			
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
	
	var max_scale_index: int = _WINDOW_SCALES.find(max_scale)

	for idx: int in range(6, max_scale_index, -1):
		%ScaleOptionButton.remove_item(idx)
	
	
func _set_scale_choice_label() -> void:
	var screen_scale: int = 1
	var current_window_size: Vector2 = DisplayServer.window_get_size() 
	var base_resolution: Vector2 = Vector2(320, 180)
	if current_window_size.x / base_resolution.x == current_window_size.y / base_resolution.y:
		screen_scale = floor(current_window_size.x / base_resolution.x)
		
	var scale_index: int = _WINDOW_SCALES.find(screen_scale)
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
	Globals.animation_speed = _ANIMATION_SPEEDS[index]


func _on_fps_limit_options_item_selected(index: int) -> void:
	Engine.max_fps = _FPS_LIMITS[index]


func _setup_language_options() -> void:
	_language_locales = Localization.get_available_locales()
	%LanguageOptionButton.clear()
	for locale: String in _language_locales:
		%LanguageOptionButton.add_item(Localization.get_locale_name(locale))
	%LanguageOptionButton.select(_language_locales.find(Localization.get_locale()))


func _on_language_option_button_item_selected(index: int) -> void:
	Localization.set_locale(_language_locales[index])


func _on_mute_all_sounds_check_box_toggled(toggled_on: bool) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, toggled_on)


func _on_scale_option_button_item_selected(index: int) -> void:
	var base_resolution: Vector2 = Vector2(320, 180)
	var scale: int = _WINDOW_SCALES[index]

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	var window_size: Vector2 = base_resolution * scale
	DisplayServer.window_set_size(window_size)	
	
	var display_size: Vector2 = DisplayServer.screen_get_size()
	DisplayServer.window_set_position((display_size - window_size) / 2)
	
	%ScaleLabel.add_theme_color_override("default_color", Globals.red)
	%FullscreenCheckBox.button_pressed = false


func _on_text_speed_option_button_item_selected(index: int) -> void:
	pass # Replace with function body.
