extends Node
## Game-wide input: the global actions (screenshot, pause, end turn), the
## controller's virtual cursor, and listening for a new key binding.

## A rebinding slot got its press (see listen_for_binding()).
signal binding_captured(action: StringName, kind: InputBindings.Kind, event: InputEvent)
## Listening ended without a binding: Escape, a click, or another device.
signal binding_cancelled(action: StringName, kind: InputBindings.Kind)

const _NOT_LISTENING: int = -1

var cursor: VirtualCursor = VirtualCursor.new()

var _listen_action: StringName = &""
var _listen_kind: int = _NOT_LISTENING
## Real time, not the game's: hitstop sets Engine.time_scale to 0 and the
## pointer mustn't freeze with it.
var _last_tick_usec: int = 0


func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS
	cursor.attach(get_viewport())
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
	cursor.update(real_delta)


## Comes before the GUI and unhandled input, so a binding being listened for,
## or the stick steering the pointer, isn't also read as a game action.
func _input(event: InputEvent) -> void:
	if is_listening():
		if _listen_to(event):
			get_viewport().set_input_as_handled()
		return
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
		# Whenever the button would take a click, and only then: not mid-jump,
		# and not while dice already dropped are still to fire.
		if Globals.player.can_end_turn():
			Globals.player.end_turn()


## Where the pointer is in [param viewport]'s coordinates: the controller's
## while it's steering, else the mouse's. The same thing once the OS pointer
## has been warped there; the drawn cursor asks this so it keeps up even
## where a platform won't warp.
func pointer_position(viewport: Viewport) -> Vector2:
	if cursor.active and viewport == get_viewport():
		return cursor.position
	return viewport.get_mouse_position()


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
