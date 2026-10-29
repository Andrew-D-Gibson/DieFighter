class_name VirtualCursor
extends RefCounted
## Plays the mouse from a controller: the left stick and d-pad move the
## pointer, cursor_click is the left button and cursor_back the right one (and
## ui_cancel).
##
## The game is all pointing, clicking and dragging dice, so rather than teach
## every screen about controllers this makes real mouse input: the OS pointer
## is warped along and InputEventMouseMotion / InputEventMouseButton are fed
## to Input, so hover, clicks, drags (Input.is_mouse_button_pressed) and
## get_global_mouse_position() all work unchanged.
##
## Positions are in the root viewport's own coordinates, where the game's
## frame (ScreenFrame) is always 1920x1080 whatever the window or fullscreen
## scale, so the pointer crosses the screen in the same time on any display
## and is kept inside the frame (not the black bars of pixel-perfect mode).
##
## InputManager owns one and feeds it events and frame times. The hooks
## (send_event, warp, read_mouse, frame_rect, to_window) are what touch the
## engine, so tests can swap them for fakes.

## The device id on events this makes, so they can be told from a real mouse.
const DEVICE_ID: int = -3

## Stick deflection below this is drift, not intent.
const DEADZONE: float = 0.2
## Full tilt, in frame units (1920 to the frame's width) per second: about
## 1.3 s to cross the screen before acceleration.
const BASE_SPEED: float = 1500.0
## The d-pad nudges, for lining up on small things.
const DPAD_SPEED_SCALE: float = 0.3
## Holding a direction speeds the pointer up by this much...
const MAX_BOOST: float = 2.0
## ...over this many seconds.
const BOOST_TIME: float = 0.6

## The player's Cursor Speed option, a multiplier on BASE_SPEED.
var speed_scale: float = 1.0
## Where the pointer is, in viewport coordinates.
var position: Vector2 = Vector2.ZERO
## Whether the controller moved the pointer last. A real mouse moving takes
## over again, and the next stick push starts from wherever it left off.
var active: bool = false

## Hands an event to the engine (Input.parse_input_event).
var send_event: Callable
## Moves the OS pointer to a viewport position.
var warp: Callable
## Where the real pointer is, in viewport coordinates.
var read_mouse: Callable
## The game's frame in viewport coordinates: the pointer stays inside it.
var frame_rect: Callable
## Viewport coordinates to window pixels, which mouse events are given in.
var to_window: Callable

var _stick: Vector2 = Vector2.ZERO
var _dpad: Dictionary[JoyButton, bool] = {}
var _held_time: float = 0.0
var _button_mask: int = 0


## Points the hooks at [param viewport]: the root one in the game.
func attach(viewport: Viewport) -> void:
	send_event = Input.parse_input_event
	warp = viewport.warp_mouse
	read_mouse = viewport.get_mouse_position
	frame_rect = func() -> Rect2: return ScreenFrame.rect_in_viewport(viewport)
	to_window = viewport.get_screen_transform


## Takes the controller events that drive the pointer. Returns true for ones
## it used up, which nothing else should then see: the stick and d-pad would
## otherwise also turn the codex's pages (ui_left / ui_right).
func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if event.device != DEVICE_ID and not _is_warp_echo(event):
			active = false
		return false
	if event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_LEFT_X:
				_stick.x = event.axis_value
				return true
			JOY_AXIS_LEFT_Y:
				_stick.y = event.axis_value
				return true
		return _press_buttons(event)
	if event is InputEventJoypadButton:
		if event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			_dpad[event.button_index] = event.pressed
			return true
		return _press_buttons(event)
	return false


## Moves the pointer for [param delta] seconds of whatever the stick and
## d-pad are holding.
func update(delta: float) -> void:
	var direction: Vector2 = _direction()
	if direction == Vector2.ZERO:
		_held_time = 0.0
		return
	if not active:
		position = read_mouse.call()
		active = true
	_held_time += delta
	var boost: float = lerpf(1.0, MAX_BOOST, clampf(_held_time / BOOST_TIME, 0.0, 1.0))
	_move_to(position + direction * BASE_SPEED * speed_scale * boost * delta, delta)


## Lets go of everything, as if the controller were put down: for when the
## window loses focus mid-drag.
func release_all() -> void:
	_stick = Vector2.ZERO
	_dpad.clear()
	_held_time = 0.0
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if _button_mask & mouse_button_to_mask(button):
			_send_button(button, false)


static func mouse_button_to_mask(button: MouseButton) -> int:
	return 1 << (button - 1)


## --- Internals ---

## Where the stick and d-pad point, as a speed fraction: a gentle tilt goes
## slowly (squared, for fine control), full tilt at 1.
func _direction() -> Vector2:
	var result: Vector2 = Vector2.ZERO
	var tilt: float = _stick.length()
	if tilt > DEADZONE:
		var amount: float = clampf((tilt - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		result = _stick / tilt * amount * amount
	var dpad: Vector2 = Vector2(
		float(_dpad.get(JOY_BUTTON_DPAD_RIGHT, false)) - float(_dpad.get(JOY_BUTTON_DPAD_LEFT, false)),
		float(_dpad.get(JOY_BUTTON_DPAD_DOWN, false)) - float(_dpad.get(JOY_BUTTON_DPAD_UP, false)))
	if dpad != Vector2.ZERO:
		result += dpad.normalized() * DPAD_SPEED_SCALE
	return result.limit_length(1.0)


func _press_buttons(event: InputEvent) -> bool:
	if event.is_action(&"cursor_click", true):
		_sync_from_mouse()
		_send_button(MOUSE_BUTTON_LEFT, event.is_pressed())
		return true
	if event.is_action(&"cursor_back", true):
		_sync_from_mouse()
		_send_button(MOUSE_BUTTON_RIGHT, event.is_pressed())
		var cancel: InputEventAction = InputEventAction.new()
		cancel.action = &"ui_cancel"
		cancel.pressed = event.is_pressed()
		send_event.call(cancel)
		return true
	return false


## Some platforms answer a warp with a real motion event to where the pointer
## was sent. That isn't the player taking the mouse back, and re-reading the
## position from it would round away slow, sub-pixel stick movement.
func _is_warp_echo(motion: InputEventMouseMotion) -> bool:
	if not active:
		return false
	var window_pixel: float = 1.0 / maxf(to_window.call().get_scale().x, 0.001)
	return motion.position.distance_to(position) <= 1.5 * window_pixel


## A click with the stick untouched lands where the real pointer is.
func _sync_from_mouse() -> void:
	if not active:
		position = read_mouse.call()


func _move_to(target: Vector2, delta: float) -> void:
	var frame: Rect2 = frame_rect.call()
	var clamped: Vector2 = target.clamp(frame.position, frame.end - Vector2.ONE)
	var moved: Vector2 = clamped - position
	if moved == Vector2.ZERO:
		return
	position = clamped
	warp.call(position)

	var transform: Transform2D = to_window.call()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.device = DEVICE_ID
	motion.position = transform * position
	motion.global_position = motion.position
	motion.relative = transform.basis_xform(moved)
	motion.screen_relative = motion.relative
	motion.velocity = motion.relative / maxf(delta, 0.001)
	motion.screen_velocity = motion.velocity
	motion.button_mask = _button_mask
	send_event.call(motion)


func _send_button(button: MouseButton, pressed: bool) -> void:
	var bit: int = mouse_button_to_mask(button)
	if pressed == bool(_button_mask & bit):
		return
	_button_mask = (_button_mask | bit) if pressed else (_button_mask & ~bit)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.device = DEVICE_ID
	click.button_index = button
	click.pressed = pressed
	click.position = to_window.call() * position
	click.global_position = click.position
	click.button_mask = _button_mask
	send_event.call(click)
