class_name OptionsMenu
extends Node2D

@export var _game_options: Control
@export var _graphics_options: Control
@export var _audio_options: Control

enum ScreenShowing {GAME, GRAPHICS, AUDIO}
var screen_showing: ScreenShowing = ScreenShowing.GAME

func _on_close_button_pressed() -> void:
	queue_free()


func _on_item_hover() -> void:
	Events.play_sound.emit('tile_dropped')


func _on_game_volume_slider_value_changed(value: float) -> void:
	%GameVolumeKnobLabel.text = str(int(%GameVolumeSlider.value)) + '%'
	%GameVolumeKnobLabel.global_position.x = \
		%GameVolumeSlider.global_position.x + \
		(%GameVolumeSlider.value / %GameVolumeSlider.max_value) * \
		(%GameVolumeSlider.size.x - 24)


func _on_music_volume_slider_value_changed(value: float) -> void:
	%MusicVolumeKnobLabel.text = str(int(%MusicVolumeSlider.value)) + '%'
	%MusicVolumeKnobLabel.global_position.x = \
		%MusicVolumeSlider.global_position.x + \
		(%MusicVolumeSlider.value / %MusicVolumeSlider.max_value) * \
		(%MusicVolumeSlider.size.x - 24)


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	%SFXVolumeKnobLabel.text = str(int(%SFXVolumeSlider.value)) + '%'
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
	
	%GameOptionsButton.add_theme_color_override('default_color', Globals.white)
	%GameOptionsButton.text = 'GAME'
	
	
func _on_game_button_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.GAME:
		%GameOptionsButton.add_theme_color_override('default_color', Globals.orange)
		%GameOptionsButton.text = '[wave amp=8.0 freq=5.0 connected=1]GAME[/wave]'

	else:
		%GameOptionsButton.add_theme_color_override('default_color', Globals.white)
		%GameOptionsButton.text = 'GAME'


func _on_graphics_button_pressed() -> void:
	_game_options.hide()
	_graphics_options.show()
	_audio_options.hide()
	
	%Background.frame = 1
	screen_showing = ScreenShowing.GRAPHICS
	
	%GraphicsOptionsButton.add_theme_color_override('default_color', Globals.white)
	%GraphicsOptionsButton.text = 'GRAPHICS'


func _on_graphics_button_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.GRAPHICS:
		%GraphicsOptionsButton.add_theme_color_override('default_color', Globals.green)
		%GraphicsOptionsButton.text = '[wave amp=8.0 freq=5.0 connected=1]GRAPHICS[/wave]'

	else:
		%GraphicsOptionsButton.add_theme_color_override('default_color', Globals.white)
		%GraphicsOptionsButton.text = 'GRAPHICS'


func _on_audio_button_pressed() -> void:
	_game_options.hide()
	_graphics_options.hide()
	_audio_options.show()
	
	%Background.frame = 2
	screen_showing = ScreenShowing.AUDIO
	
	%AudioOptionsButton.add_theme_color_override('default_color', Globals.white)
	%AudioOptionsButton.text = 'AUDIO'


func _on_audio_button_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.AUDIO:
		%AudioOptionsButton.add_theme_color_override('default_color', Globals.purple)
		%AudioOptionsButton.text = '[wave amp=8.0 freq=5.0 connected=1]AUDIO[/wave]'

	else:
		%AudioOptionsButton.add_theme_color_override('default_color', Globals.white)
		%AudioOptionsButton.text = 'AUDIO'
