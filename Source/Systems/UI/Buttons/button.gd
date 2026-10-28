## Needs a RichTextLabel and an AnimatedSprite2D as children
## The AnimatedSprite2D must include animations:
## "default", "pushed", and "disabled"

extends Button

const _HOVER_THUMP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")
const _TILE_DROPPED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")

enum ButtonSize {
	SMALL,
	LARGE,
	MEDIUM,
}
@export var button_size: ButtonSize = ButtonSize.SMALL

@export var hover_text_color: Color = Globals.white
@export var disabled_text_color: Color = Globals.purple
@export var soft_highlight_color: Color = Globals.purple
@onready var text_position: Vector2 = $RichTextLabel.position

## The length of time between the button going down and back up
## that will still emit the 'pressed_within_window' signal.
## This is so that pushing a button can be canceled by holding it
@export var button_click_window_sec: float = 0.5

## A disabled button lets clicks through to whatever is under it. For a button
## that shares its spot with something the player handles until it activates,
## like End Turn over a long hand of dice: a Control eats the click before a
## die's Area2D ever sees it.
@export var pass_mouse_while_disabled: bool = false

## Kept as written, which may be a translation key: the label translates it,
## but the hover wave wraps it in BBCode, which the label can't look up, so
## it has to be translated by hand there.
@onready var _text_on_ready: String = $RichTextLabel.text
var _button_down_time: int

## Connect to this signal to execute the button's function
signal pressed_within_window()


func update_ui() -> void:
	if pass_mouse_while_disabled:
		mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
	if disabled:
		$AnimatedSprite2D.frame = 1
		$RichTextLabel.position = text_position + Vector2(0, 2)
		$RichTextLabel.add_theme_color_override('default_color', disabled_text_color)
	else: 
		$AnimatedSprite2D.frame = 0
		$RichTextLabel.position = text_position
		$RichTextLabel.remove_theme_color_override('default_color')
		

func _on_mouse_entered() -> void:
	if disabled:
		return
		
	Events.play_sound.emit(_HOVER_THUMP_SFX)
	
	var amp: float
	if button_size == ButtonSize.LARGE:
		amp = 12.0
	elif button_size == ButtonSize.MEDIUM:
		amp = 9.0
	elif button_size == ButtonSize.SMALL:
		amp = 6.0
		
	var freq: float = 5.0
	
	$RichTextLabel.text = '[wave '\
		+ 'amp=' + str(amp) \
		+ 'freq=' + str(freq) \
		+ 'connected=1]'\
		+ tr(_text_on_ready) \
		+ '[/wave]'
	$RichTextLabel.add_theme_color_override('default_color', hover_text_color)


func _on_mouse_exited() -> void:
	$RichTextLabel.text = _text_on_ready
	$RichTextLabel.remove_theme_color_override('default_color')
	update_ui()


func _on_button_down() -> void:
	_button_down_time = Time.get_ticks_msec()


func _on_button_up() -> void:
	if Time.get_ticks_msec() < _button_down_time + (button_click_window_sec * 1000):
		Events.play_sound.emit(_TILE_DROPPED_SFX)
		pressed_within_window.emit()
		

func soft_highlight() -> void:
	if disabled:
		return
		
	var amp: float
	if button_size == ButtonSize.LARGE:
		amp = 9.0
	elif button_size == ButtonSize.MEDIUM:
		amp = 6.0
	elif button_size == ButtonSize.SMALL:
		amp = 4.0
		
	var freq: float = 5.0
	
	$RichTextLabel.text = '[wave '\
		+ 'amp=' + str(amp) \
		+ 'freq=' + str(freq) \
		+ 'connected=1]'\
		+ tr(_text_on_ready) \
		+ '[/wave]'
	$RichTextLabel.add_theme_color_override('default_color', soft_highlight_color)


func set_button_text(new_text: String) -> void:
	$RichTextLabel.text = new_text
	_text_on_ready = new_text
