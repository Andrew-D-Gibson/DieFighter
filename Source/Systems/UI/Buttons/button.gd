## Needs a RichTextLabel and an AnimatedSprite2D as children
## The AnimatedSprite2D must include animations:
## "default", "pushed", and "disabled"

extends Button

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

@onready var _text_on_ready: String = $RichTextLabel.text
var _button_down_time: int

## Connect to this signal to execute the button's function
signal pressed_within_window()


func update_ui() -> void:
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
		
	Events.play_sound.emit('hover_thump')
	
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
		+ _text_on_ready \
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
		Events.play_sound.emit('tile_dropped')
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
		+ _text_on_ready \
		+ '[/wave]'
	$RichTextLabel.add_theme_color_override('default_color', soft_highlight_color)
