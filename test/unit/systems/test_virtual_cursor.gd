extends "res://test/helpers/die_fighter_test.gd"
## The controller's virtual cursor: stick and d-pad events move it in frame
## units whatever the window's scale, it stays in the frame, and the click and
## back buttons become real mouse events. No device is needed: joypad events
## are fed in by hand and the mouse events it would hand the engine are caught.

const FRAME: Rect2 = Rect2(0, 0, 1920, 1080)
const START: Vector2 = Vector2(960, 540)

var cursor: VirtualCursor
var sent: Array[InputEvent] = []
var warps: Array[Vector2] = []
var real_mouse: Vector2 = START
var frame: Rect2 = FRAME
## Viewport to window pixels: a 2x window shows the 1920-wide frame in 640.
var window_transform: Transform2D = Transform2D.IDENTITY


func before_each() -> void:
	super()
	sent.clear()
	warps.clear()
	real_mouse = START
	frame = FRAME
	window_transform = Transform2D.IDENTITY
	cursor = VirtualCursor.new()
	cursor.send_event = func(event: InputEvent) -> void: sent.append(event)
	cursor.warp = func(at: Vector2) -> void: warps.append(at)
	cursor.read_mouse = func() -> Vector2: return real_mouse
	cursor.frame_rect = func() -> Rect2: return frame
	cursor.to_window = func() -> Transform2D: return window_transform


func _stick(x: float, y: float = 0.0) -> void:
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = x if axis == JOY_AXIS_LEFT_X else y
		assert_true(cursor.handle_event(motion), "the stick belongs to the cursor")


func _button(index: JoyButton, pressed: bool) -> bool:
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = index
	button.pressed = pressed
	return cursor.handle_event(button)


func _sent_of(type: Variant) -> Array[InputEvent]:
	return sent.filter(func(event: InputEvent) -> bool: return is_instance_of(event, type))


func test_full_tilt_moves_at_base_speed_and_sends_motion() -> void:
	_stick(1.0)
	cursor.update(0.1)
	var expected: float = START.x + VirtualCursor.BASE_SPEED * 0.1 * _boost(0.1)
	assert_almost_eq(cursor.position.x, expected, 0.01)
	assert_eq(cursor.position.y, START.y)
	assert_eq(warps, [cursor.position] as Array[Vector2])
	var motions: Array[InputEvent] = _sent_of(InputEventMouseMotion)
	assert_eq(motions.size(), 1)
	var motion: InputEventMouseMotion = motions[0]
	assert_eq(motion.device, VirtualCursor.DEVICE_ID)
	assert_eq(motion.position, cursor.position)
	assert_almost_eq(motion.relative.x, expected - START.x, 0.01)


func test_speed_is_the_same_in_frame_units_at_any_window_scale() -> void:
	_stick(1.0)
	window_transform = Transform2D(0.0, Vector2(1.0 / 3.0, 1.0 / 3.0), 0.0, Vector2.ZERO)
	cursor.update(0.1)
	var small_window_step: float = cursor.position.x - START.x
	var small_window_event: InputEventMouseMotion = _sent_of(InputEventMouseMotion)[0]

	before_each()
	_stick(1.0)
	# Pixel-perfect 4K fullscreen: 2 screen pixels per unit, frame inset.
	window_transform = Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(40, 20))
	cursor.update(0.1)
	assert_almost_eq(cursor.position.x - START.x, small_window_step, 0.001)
	var big_window_event: InputEventMouseMotion = _sent_of(InputEventMouseMotion)[0]
	# The events themselves are in window pixels.
	assert_almost_eq(big_window_event.relative.x, small_window_event.relative.x * 6.0, 0.01)
	assert_almost_eq(big_window_event.position, window_transform * cursor.position, Vector2(0.01, 0.01))


func test_drift_inside_the_deadzone_does_nothing() -> void:
	_stick(VirtualCursor.DEADZONE * 0.9)
	cursor.update(0.1)
	assert_eq(sent.size(), 0)
	assert_eq(warps.size(), 0)


func test_a_gentle_tilt_is_slower_than_full() -> void:
	_stick(0.5)
	cursor.update(0.1)
	var gentle: float = cursor.position.x - START.x
	assert_gt(gentle, 0.0)
	assert_lt(gentle, VirtualCursor.BASE_SPEED * 0.1 * 0.5)


func test_holding_a_direction_accelerates() -> void:
	frame = Rect2(0, 0, 100000, 1080) # Room to keep going.
	_stick(1.0)
	cursor.update(0.05)
	var first_step: float = cursor.position.x - START.x
	for i: int in range(20):
		cursor.update(0.05)
	var before: float = cursor.position.x
	cursor.update(0.05)
	assert_almost_eq(cursor.position.x - before, first_step / _boost(0.05) * VirtualCursor.MAX_BOOST, 0.01)


func test_cursor_speed_option_scales_movement() -> void:
	cursor.speed_scale = 2.0
	_stick(1.0)
	cursor.update(0.1)
	assert_almost_eq(cursor.position.x - START.x, 2.0 * VirtualCursor.BASE_SPEED * 0.1 * _boost(0.1), 0.01)


func test_stays_inside_an_inset_frame() -> void:
	frame = Rect2(120, 60, 1920, 1080)
	real_mouse = Vector2(200, 100)
	_stick(-1.0, -1.0)
	for i: int in range(30):
		cursor.update(0.1)
	assert_eq(cursor.position, frame.position)
	_stick(1.0, 1.0)
	for i: int in range(60):
		cursor.update(0.1)
	assert_eq(cursor.position, frame.end - Vector2.ONE)


func test_dpad_nudges_slower_than_the_stick() -> void:
	assert_true(_button(JOY_BUTTON_DPAD_DOWN, true), "the d-pad belongs to the cursor")
	cursor.update(0.1)
	assert_almost_eq(cursor.position.y - START.y,
		VirtualCursor.BASE_SPEED * VirtualCursor.DPAD_SPEED_SCALE * 0.1 * _boost(0.1), 0.01)
	_button(JOY_BUTTON_DPAD_DOWN, false)
	var stopped: Vector2 = cursor.position
	cursor.update(0.1)
	assert_eq(cursor.position, stopped)


func test_click_button_presses_and_holds_the_left_mouse_button() -> void:
	assert_true(_button(JOY_BUTTON_A, true))
	var press: InputEventMouseButton = _sent_of(InputEventMouseButton)[0]
	assert_eq(press.button_index, MOUSE_BUTTON_LEFT)
	assert_true(press.pressed)
	assert_eq(press.position, START, "a click without moving lands where the real pointer is")
	assert_eq(press.device, VirtualCursor.DEVICE_ID)

	# Dragging: motion while held carries the button in its mask.
	_stick(1.0)
	cursor.update(0.1)
	var drag: InputEventMouseMotion = _sent_of(InputEventMouseMotion)[0]
	assert_eq(drag.button_mask, MOUSE_BUTTON_MASK_LEFT)

	_stick(0.0)
	assert_true(_button(JOY_BUTTON_A, false))
	var release: InputEventMouseButton = _sent_of(InputEventMouseButton)[1]
	assert_false(release.pressed)
	assert_eq(release.position, cursor.position, "dropped where it was dragged to")
	assert_eq(release.button_mask, 0)


func test_back_button_is_right_click_and_ui_cancel() -> void:
	assert_true(_button(JOY_BUTTON_B, true))
	var right: InputEventMouseButton = _sent_of(InputEventMouseButton)[0]
	assert_eq(right.button_index, MOUSE_BUTTON_RIGHT)
	var cancel: InputEventAction = _sent_of(InputEventAction)[0]
	assert_eq(cancel.action, &"ui_cancel")
	assert_true(cancel.pressed)
	_button(JOY_BUTTON_B, false)
	assert_false((_sent_of(InputEventAction)[1] as InputEventAction).pressed)


func test_other_buttons_are_left_for_their_actions() -> void:
	assert_false(_button(JOY_BUTTON_Y, true), "Y is End Turn's")
	assert_false(_button(JOY_BUTTON_START, true), "Start opens the pause menu")
	assert_eq(sent.size(), 0)


func test_rebound_click_follows_the_input_map() -> void:
	var old_events: Array[InputEvent] = InputMap.action_get_events(&"cursor_click")
	InputBindings.write(&"cursor_click", ["pad:%d" % JOY_BUTTON_X])
	assert_false(_button(JOY_BUTTON_A, true))
	assert_true(_button(JOY_BUTTON_X, true))
	InputMap.action_erase_events(&"cursor_click")
	for event: InputEvent in old_events:
		InputMap.action_add_event(&"cursor_click", event)


func test_a_real_mouse_takes_over_and_the_stick_resumes_from_it() -> void:
	_stick(1.0)
	cursor.update(0.1)
	assert_true(cursor.active)
	var mouse: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse.position = Vector2(100, 100)
	assert_false(cursor.handle_event(mouse), "the real mouse's own events pass on")
	assert_false(cursor.active)
	real_mouse = Vector2(100, 100)
	cursor.update(0.1)
	assert_gt(cursor.position.x, 100.0)
	assert_lt(cursor.position.x, START.x)


func test_the_echo_of_a_warp_is_not_the_player() -> void:
	_stick(1.0)
	cursor.update(0.1)
	var echo: InputEventMouseMotion = InputEventMouseMotion.new()
	echo.position = cursor.position.round()
	cursor.handle_event(echo)
	assert_true(cursor.active)


func test_release_all_lets_go_of_a_drag() -> void:
	_button(JOY_BUTTON_A, true)
	cursor.release_all()
	var release: InputEventMouseButton = _sent_of(InputEventMouseButton)[1]
	assert_false(release.pressed)
	cursor.release_all()
	assert_eq(_sent_of(InputEventMouseButton).size(), 2, "nothing more to let go of")


## The real engine path: a click reaches Input, so Draggable's
## Input.is_mouse_button_pressed() sees the button held.
func test_clicks_reach_input() -> void:
	cursor.send_event = Input.parse_input_event
	real_mouse = Vector2(-500, -500) # Off the window: nothing gets clicked.
	_button(JOY_BUTTON_A, true)
	Input.flush_buffered_events()
	assert_true(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	_button(JOY_BUTTON_A, false)
	Input.flush_buffered_events()
	assert_false(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


func _boost(held: float) -> float:
	return lerpf(1.0, VirtualCursor.MAX_BOOST, clampf(held / VirtualCursor.BOOST_TIME, 0.0, 1.0))


## The drawn cursor (MouseCursor) asks InputManager where to be: the
## controller's pointer while it steers, so it keeps up even unwarped.
func test_the_drawn_cursor_follows_the_steering_pointer() -> void:
	var live: VirtualCursor = InputManager.cursor
	var root: Viewport = get_tree().root
	assert_false(live.active, "nobody is holding a controller in the test run")
	assert_eq(InputManager.pointer_position(root), root.get_mouse_position())
	live.active = true
	live.position = Vector2(123, 45)
	assert_eq(InputManager.pointer_position(root), Vector2(123, 45))
	live.active = false
