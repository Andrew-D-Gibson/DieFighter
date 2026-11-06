class_name CutsceneSkipPrompt
extends CanvasLayer
## How a cutscene is skipped: the first press of anything shows a caption at
## the bottom of the screen, and a second press while it's up skips. The
## caption fades away on its own if the player doesn't confirm, so one stray
## press never ends a cutscene. Every press is consumed, so nothing reaches
## the game behind.

## The player pressed again while the caption was up.
signal confirmed

const _FADE_IN: float = 0.15
const _HOLD: float = 2.0
const _FADE_OUT: float = 2.0
const _AXIS_THRESHOLD: float = 0.6
## Screen pixels per art pixel on the 1080p layer the caption draws in.
const _ART_SCALE: float = 6.0
## Gap under the caption, in art pixels.
const _MARGIN_ART_PX: float = 6.0

var _prompt: Label
## Negative while hidden; confirmation expires only when the fade is complete.
var _elapsed: float = -1.0
var _axes_held: Dictionary[Vector2i, bool] = {}


func _init(draw_layer: int = 10) -> void:
	name = "SkipOverlay"
	layer = draw_layer


func _ready() -> void:
	_prompt = Label.new()
	_prompt.name = "SkipPrompt"
	_prompt.text = tr("CUTSCENE_SKIP_PROMPT")
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The default (small) font at one font pixel per art pixel, so the caption
	# sits on the same 320x180 grid as the art it's laid over.
	_prompt.theme_type_variation = FontRoles.slot(FontRoles.SMALL, _ART_SCALE)
	_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prompt.add_theme_constant_override("shadow_offset_x", int(_ART_SCALE))
	_prompt.add_theme_constant_override("shadow_offset_y", int(_ART_SCALE))
	add_child(_prompt)
	# Placed by hand rather than centred by the Label: centring an odd number
	# of art pixels in an even width would land the text half a pixel off.
	var text_size: Vector2 = _prompt.get_combined_minimum_size()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_prompt.size = text_size
	_prompt.position = Vector2(
		snappedf((screen.x - text_size.x) / 2.0, _ART_SCALE),
		screen.y - text_size.y - _MARGIN_ART_PX * _ART_SCALE)
	_prompt.modulate.a = 0.0
	_prompt.hide()


func _input(event: InputEvent) -> void:
	if not _is_press(event):
		return
	# Consume the original press before InputManager can turn controller A
	# into a second, synthetic mouse press or move the desktop pointer.
	get_viewport().set_input_as_handled()
	if _elapsed >= 0.0:
		confirmed.emit()
	else:
		_elapsed = 0.0
		_prompt.show()


func _process(delta: float) -> void:
	if _elapsed < 0.0:
		return
	_elapsed += delta
	if _elapsed < _FADE_IN:
		_prompt.modulate.a = _elapsed / _FADE_IN
	elif _elapsed < _FADE_IN + _HOLD:
		_prompt.modulate.a = 1.0
	else:
		var fading: float = _elapsed - _FADE_IN - _HOLD
		_prompt.modulate.a = maxf(1.0 - fading / _FADE_OUT, 0.0)
		if fading >= _FADE_OUT:
			_elapsed = -1.0
			_prompt.hide()


func _is_press(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var axis_key: Vector2i = Vector2i(event.device, event.axis)
		var was_held: bool = _axes_held.get(axis_key, false)
		var amount: float = absf(event.axis_value)
		# Hysteresis requires a return to neutral, so a held stick/trigger
		# cannot both reveal the prompt and confirm it as values fluctuate.
		if amount < 0.2:
			_axes_held.erase(axis_key)
		elif amount >= _AXIS_THRESHOLD and not was_held:
			_axes_held[axis_key] = true
			return true
		return false
	if event is InputEventMouseButton and _is_wheel(event.button_index):
		# One flick of a wheel or trackpad is a burst of presses, which would
		# raise the prompt and confirm it before the player meant either.
		return false
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed() and not event.is_echo()
	return false


static func _is_wheel(button: MouseButton) -> bool:
	return button in [
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
	]
