extends Node
## Game-wide input: the global actions (screenshot, pause, end turn), the
## controller's virtual cursor, and listening for a new key binding.

## A rebinding slot got its press (see listen_for_binding()).
signal binding_captured(action: StringName, kind: InputBindings.Kind, event: InputEvent)
## Listening ended without a binding: Escape, a click, or another device.
signal binding_cancelled(action: StringName, kind: InputBindings.Kind)

## The displayed controls changed: device, controller family, or bindings.
signal prompts_changed()

var controller_active: bool = false
var controller_family: StringName = &"xbox"
var active_joypad: int = -1

const _NOT_LISTENING: int = -1

var cursor: VirtualCursor = VirtualCursor.new()

## The selection-icon scheme, paired with the stick-steered pointer the default
## (CURSOR) runs. Both drive the same cursor; control_scheme picks which one
## moves it (see _input). Set by OptionsSettings.CONTROLLER_SCHEME.
var focus_selection: FocusSelection = FocusSelection.new()

## Which way the controller drives the game. CURSOR runs the stick-steered
## pointer; FOCUS swaps it for a selection icon that snaps between the on-
## screen objects of interest. Set by the Controller Mode option (see
## OptionsSettings.CONTROLLER_SCHEME); defaults so the behaviour is exactly
## today's until FocusSelection is wired in (see _process, below).
var control_scheme: InputBindings.ControlScheme = InputBindings.ControlScheme.CURSOR

## Where the last mouse event put the pointer, in the root viewport's
## coordinates. Read instead of Viewport.get_mouse_position(), which in a real
## window asks the OS and so never sees injected events (tests, the MCP
## bridge). For a player they're the same: every OS move arrives as an event.
var _mouse_position: Vector2 = Vector2.ZERO
var _has_mouse_position: bool = false

var _listen_action: StringName = &""
var _listen_kind: int = _NOT_LISTENING
## Real time, not the game's: hitstop sets Engine.time_scale to 0 and the
## pointer mustn't freeze with it.
var _last_tick_usec: int = 0


func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS
	cursor.attach(get_viewport())
	# The selection icon reuses the same cursor, so the click and warp machinery
	# is shared; it's inactive until a scheme turns it on.
	add_child(focus_selection)
	focus_selection.attach(cursor, get_viewport())
	# window_input comes before any node's _input, so even nodes that hear an
	# event ahead of this autoload read the pointer it carries.
	get_window().window_input.connect(_track_mouse)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	OptionsSettings.option_changed.connect(_on_prompt_option_changed)
	_last_tick_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real_delta: float = minf((now - _last_tick_usec) / 1_000_000.0, 0.1)
	_last_tick_usec = now
	# A controller still sends input to a window in the background; it mustn't
	# drag the desktop's pointer around.
	if not get_window().has_focus():
		cursor.release_all()
		return
	if control_scheme == InputBindings.ControlScheme.CURSOR:
		cursor.update(real_delta)


## Comes before the GUI and unhandled input, so a binding being listened for,
## or the stick steering the pointer, isn't also read as a game action.
func _input(event: InputEvent) -> void:
	track_prompt_input(event)
	if is_listening():
		if _listen_to(event):
			get_viewport().set_input_as_handled()
		return
	if control_scheme == InputBindings.ControlScheme.FOCUS:
		# The selection icon takes the controller: the d-pad steps it, A and B
		# act. A real mouse still moves the pointer underneath, so a mouse user
		# isn't frozen; the stick is inert here (it's the CURSOR scheme's job).
		if focus_selection.handle_event(event):
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			cursor.handle_event(event)
		return
	# CURSOR scheme: the stick and d-pad steer the pointer as before.
	if cursor.handle_event(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Global actions
	if event.is_action_pressed("screenshot"):
		Events.take_screenshot.emit()

	# Game only actions
	if not Globals.state_manager or \
	Globals.state_manager.state == GameStateManager.GameState.GAME_OVER:
		return

	if event.is_action_pressed('PauseMenu'):
		Events.toggle_pause_menu.emit()
	elif event.is_action_pressed('EndTurn'):
		# Exactly as the button: only when it would take a click (not mid-jump,
		# not while dropped dice are still to fire), and asking first when
		# playable dice would go unused.
		Globals.player.request_end_turn()


## Where the pointer is in [param viewport]'s coordinates: the controller's
## while it's steering, else the mouse's. The same thing once the OS pointer
## has been warped there; the drawn cursor asks this so it keeps up even
## where a platform won't warp.
func pointer_position(viewport: Viewport) -> Vector2:
	if viewport == get_viewport():
		if cursor.active:
			return cursor.position
		if _has_mouse_position:
			return _mouse_position
	return viewport.get_mouse_position()


## [method pointer_position] in [param item]'s canvas: what
## get_global_mouse_position() would give, but for the same pointer.
func pointer_global_position(item: CanvasItem) -> Vector2:
	return item.get_canvas_transform().affine_inverse() * pointer_position(item.get_viewport())


## window_input carries window pixels; nodes get them after the stretch.
func _track_mouse(event: InputEvent) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse:
		_mouse_position = get_window().get_final_transform().affine_inverse() * mouse.position
		_has_mouse_position = true


## --- Rebinding ---

## Waits for the next key ([param kind] KEY) or controller button (PAD) and
## announces it with binding_captured, without acting on it. Escape, a mouse
## click or the other device's input cancels instead. Escape binds rather
## than cancels for an action it's bound to by default (the pause menu), or
## nothing could ever be put back on it.
func listen_for_binding(action: StringName, kind: InputBindings.Kind) -> void:
	if is_listening():
		cancel_listening()
	_listen_action = action
	_listen_kind = kind
	cursor.release_all()


func cancel_listening() -> void:
	if not is_listening():
		return
	var action: StringName = _listen_action
	var kind: InputBindings.Kind = _listen_kind as InputBindings.Kind
	_stop_listening()
	binding_cancelled.emit(action, kind)


func is_listening() -> bool:
	return _listen_kind != _NOT_LISTENING


func listening_for() -> Array:
	return [_listen_action, _listen_kind]


## Returns whether [param event] was taken (so nothing else acts on it).
func _listen_to(event: InputEvent) -> bool:
	var kind: InputBindings.Kind = _listen_kind as InputBindings.Kind
	var action: StringName = _listen_action
	if event is InputEventMouseMotion:
		return false
	if event is InputEventJoypadMotion and not InputBindings.accepts(kind, event):
		# The stick keeps steering the pointer, to click away and cancel.
		return cursor.handle_event(event)
	if not event.is_pressed() or event.is_echo():
		# Releases are swallowed too: the key that cancelled mustn't then
		# reach the game on its way up.
		return true
	if _cancels(event, kind, action):
		cancel_listening()
		return true
	if InputBindings.accepts(kind, event):
		_stop_listening()
		binding_captured.emit(action, kind, event)
	return true


func _cancels(event: InputEvent, kind: InputBindings.Kind, action: StringName) -> bool:
	if event is InputEventMouseButton:
		return true
	if event is InputEventKey:
		if kind == InputBindings.Kind.PAD:
			return true
		return event.physical_keycode == KEY_ESCAPE and not "key:%d" % KEY_ESCAPE in InputBindings.default_value(action)
	# A controller button while listening for a key: the pad's back button
	# (or any) gives up, as Escape does on the keyboard.
	return kind == InputBindings.Kind.KEY and event is InputEventJoypadButton


func _stop_listening() -> void:
	_listen_action = &""
	_listen_kind = _NOT_LISTENING


## A virtual mouse event and an OS warp echo still belong to the controller.
## Stick drift and button releases do not switch the displayed controls.
func track_prompt_input(event: InputEvent) -> void:
	if event.device == VirtualCursor.DEVICE_ID:
		return
	if event is InputEventJoypadButton and event.pressed:
		set_prompt_device(true, event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > VirtualCursor.DEADZONE:
		set_prompt_device(true, event.device)
	elif event is InputEventKey and event.pressed:
		set_prompt_device(false)
	elif event is InputEventMouseButton and event.pressed:
		set_prompt_device(false)
	elif event is InputEventMouseMotion and not event.relative.is_zero_approx() \
		and not cursor._is_warp_echo(event):
		set_prompt_device(false)


func set_prompt_device(controller: bool, device: int = -1, device_name: String = "") -> void:
	var family: StringName = controller_family
	if controller:
		if device_name.is_empty() and device in Input.get_connected_joypads():
			device_name = Input.get_joy_name(device)
		family = family_for_name(device_name)
	else:
		device = -1
	if controller == controller_active and family == controller_family and device == active_joypad:
		return
	controller_active = controller
	controller_family = family
	active_joypad = device
	prompts_changed.emit()


func family_for_name(device_name: String) -> StringName:
	var lower: String = device_name.to_lower()
	if "steam" in lower or "deck" in lower:
		return &"steam"
	if "xbox" in lower or "xinput" in lower or "microsoft" in lower:
		return &"xbox"
	for marker: String in ["dualsense", "dualshock", "playstation", "sony", "ps3", "ps4", "ps5", "wireless controller"]:
		if marker in lower:
			return &"ps"
	return &"xbox"


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and controller_active and device == active_joypad:
		cursor.release_all()
		set_prompt_device(false)


func _on_prompt_option_changed(key: StringName, _value: Variant) -> void:
	if String(key).begins_with("Controls/"):
		prompts_changed.emit()
