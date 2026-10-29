extends "res://test/helpers/die_fighter_test.gd"
## Key and controller rebinding: bindings round-trip through their options,
## reset to project.godot's, swap when they clash, and the Controls tab's
## slots listen for a press and show the result. Nothing is saved: the
## player's options file is never touched.

var _saved: Dictionary[StringName, Array] = {}


func before_each() -> void:
	super()
	for action: StringName in InputBindings.ACTIONS:
		_saved[action] = InputBindings.read(action)


func after_each() -> void:
	InputManager.cancel_listening()
	for action: StringName in _saved:
		InputBindings.write(action, _saved[action])
	super()


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	return key


func _pad(index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = index
	button.pressed = pressed
	return button


func _bind(action: StringName, kind: InputBindings.Kind, event: InputEvent) -> void:
	var changes: Dictionary[StringName, Array] = InputBindings.plan_bind(action, kind, event)
	for changed: StringName in changes:
		OptionsSettings.set_option(InputBindings.option_key(changed), changes[changed])


## --- Options ---

func test_every_action_is_an_option_defaulting_to_project_godot() -> void:
	for action: StringName in InputBindings.ACTIONS:
		assert_true(InputMap.has_action(action), action)
		assert_true(OptionsSettings.has_option(InputBindings.option_key(action)), action)
	assert_eq(InputBindings.default_value(&"EndTurn"),
		["key:%d" % KEY_SPACE, "key:%d" % KEY_ENTER, "pad:%d" % JOY_BUTTON_Y])
	assert_eq(InputBindings.default_value(&"cursor_click"), ["pad:%d" % JOY_BUTTON_A])


func test_a_binding_round_trips_through_its_option() -> void:
	var key: StringName = InputBindings.option_key(&"EndTurn")
	OptionsSettings.set_option(key, ["key:%d" % KEY_Q, "pad:%d" % JOY_BUTTON_X, "axis:%d:1" % JOY_AXIS_TRIGGER_RIGHT])
	assert_eq(OptionsSettings.get_option(key), ["key:%d" % KEY_Q, "pad:%d" % JOY_BUTTON_X, "axis:%d:1" % JOY_AXIS_TRIGGER_RIGHT])
	var events: Array[InputEvent] = InputMap.action_get_events(&"EndTurn")
	assert_eq(events.size(), 3)
	assert_true(events[0] is InputEventKey and events[0].physical_keycode == KEY_Q)
	assert_true(events[2] is InputEventJoypadMotion and events[2].axis_value > 0.0)

	var pressed_q: InputEventKey = _key(KEY_Q)
	assert_true(pressed_q.is_action_pressed(&"EndTurn"), "the InputMap itself is rebound")


func test_bindings_survive_a_save_and_load() -> void:
	var key: StringName = InputBindings.option_key(&"PauseMenu")
	OptionsSettings.set_option(key, ["key:%d" % KEY_P, "pad:%d" % JOY_BUTTON_START])
	var config: ConfigFile = ConfigFile.new()
	config.set_value("Controls", "bind_PauseMenu", OptionsSettings.get_option(key))
	var reloaded: ConfigFile = ConfigFile.new()
	assert_eq(reloaded.parse(config.encode_to_text()), OK)

	OptionsSettings.reset_options([key])
	OptionsSettings.set_option(key, reloaded.get_value("Controls", "bind_PauseMenu"))
	assert_eq(InputBindings.slot_label(&"PauseMenu", InputBindings.Kind.KEY), "P")


func test_defaults_restore_the_project_bindings() -> void:
	_bind(&"EndTurn", InputBindings.Kind.KEY, _key(KEY_Q))
	_bind(&"target_left", InputBindings.Kind.PAD, _pad(JOY_BUTTON_X))
	var keys: Array[StringName] = []
	for action: StringName in InputBindings.ACTIONS:
		keys.append(InputBindings.option_key(action))
	OptionsSettings.reset_options(keys)
	for action: StringName in InputBindings.ACTIONS:
		assert_eq(InputBindings.read(action), InputBindings.default_value(action), action)


func test_a_damaged_value_falls_back() -> void:
	InputBindings.write(&"EndTurn", "nonsense")
	assert_eq(InputBindings.read(&"EndTurn"), InputBindings.default_value(&"EndTurn"))
	InputBindings.write(&"EndTurn", ["key:abc", "mouse:1", "pad:%d" % JOY_BUTTON_X])
	assert_eq(InputBindings.read(&"EndTurn"), ["pad:%d" % JOY_BUTTON_X])


## --- Rebinding and clashes ---

func test_binding_a_free_key_replaces_only_that_slot() -> void:
	var changes: Dictionary[StringName, Array] = InputBindings.plan_bind(&"EndTurn", InputBindings.Kind.KEY, _key(KEY_Q))
	assert_eq(changes.keys(), [&"EndTurn"])
	assert_eq(changes[&"EndTurn"], ["pad:%d" % JOY_BUTTON_Y, "key:%d" % KEY_Q])


func test_a_clashing_key_swaps() -> void:
	_bind(&"EndTurn", InputBindings.Kind.KEY, _key(KEY_ESCAPE))
	assert_eq(InputBindings.slot_label(&"EndTurn", InputBindings.Kind.KEY), InputBindings.event_label(_key(KEY_ESCAPE)))
	var pause_keys: Array = InputBindings.serialize(InputBindings.events_of_kind(&"PauseMenu", InputBindings.Kind.KEY))
	assert_eq(pause_keys, ["key:%d" % KEY_SPACE, "key:%d" % KEY_ENTER], "the pause menu takes End Turn's old keys")
	assert_eq(InputBindings.slot_label(&"PauseMenu", InputBindings.Kind.PAD),
		InputBindings.event_label(_pad(JOY_BUTTON_START)), "its controller button is untouched")


func test_a_clashing_button_swaps() -> void:
	_bind(&"target_left", InputBindings.Kind.PAD, _pad(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(InputBindings.slot_label(&"target_left", InputBindings.Kind.PAD), "RB")
	assert_eq(InputBindings.slot_label(&"target_right", InputBindings.Kind.PAD), "LB")


func test_taking_the_click_button_hands_click_the_old_one() -> void:
	_bind(&"EndTurn", InputBindings.Kind.PAD, _pad(JOY_BUTTON_A))
	assert_eq(InputBindings.slot_label(&"EndTurn", InputBindings.Kind.PAD), "A")
	assert_eq(InputBindings.slot_label(&"cursor_click", InputBindings.Kind.PAD), "Y")


func test_a_clash_with_an_empty_slot_clears_the_other() -> void:
	InputBindings.write(&"screenshot", ["pad:%d" % JOY_BUTTON_BACK])
	_bind(&"screenshot", InputBindings.Kind.KEY, _key(KEY_ESCAPE))
	assert_eq(InputBindings.slot_label(&"PauseMenu", InputBindings.Kind.KEY), InputBindings.UNBOUND_LABEL)


func test_rebinding_the_same_press_changes_nothing() -> void:
	assert_true(InputBindings.plan_bind(&"target_left", InputBindings.Kind.KEY, _key(KEY_LEFT)).is_empty())


func test_what_a_slot_accepts() -> void:
	var kind_key: InputBindings.Kind = InputBindings.Kind.KEY
	var kind_pad: InputBindings.Kind = InputBindings.Kind.PAD
	assert_true(InputBindings.accepts(kind_key, _key(KEY_Q)))
	assert_false(InputBindings.accepts(kind_key, _key(KEY_Q, false)), "a release")
	assert_false(InputBindings.accepts(kind_key, _pad(JOY_BUTTON_A)))
	assert_false(InputBindings.accepts(kind_key, _key(KEY_QUOTELEFT)), "the dev console's key")
	assert_true(InputBindings.accepts(kind_pad, _pad(JOY_BUTTON_X)))
	assert_false(InputBindings.accepts(kind_pad, _pad(JOY_BUTTON_DPAD_LEFT)), "the d-pad steers the cursor")
	assert_false(InputBindings.accepts(kind_pad, _pad(JOY_BUTTON_GUIDE)))
	var trigger: InputEventJoypadMotion = InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 0.9
	assert_true(InputBindings.accepts(kind_pad, trigger))
	var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	assert_false(InputBindings.accepts(kind_pad, stick), "the stick steers the cursor")


func test_readable_names() -> void:
	assert_eq(InputBindings.event_label(_key(KEY_Q)), "Q")
	assert_eq(InputBindings.event_label(_key(KEY_BACKSLASH)), "\\")
	assert_eq(InputBindings.event_label(_key(KEY_F5)), "F5")
	assert_eq(InputBindings.event_label(_pad(JOY_BUTTON_LEFT_SHOULDER)), "LB")
	var trigger: InputEventJoypadMotion = InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	assert_eq(InputBindings.event_label(trigger), "RT")
	assert_eq(InputBindings.slot_label(&"cursor_click", InputBindings.Kind.KEY), InputBindings.UNBOUND_LABEL)


## --- Listening ---

func test_listening_captures_the_next_key_without_acting_on_it() -> void:
	watch_signals(InputManager)
	InputManager.listen_for_binding(&"EndTurn", InputBindings.Kind.KEY)
	assert_true(InputManager._listen_to(_key(KEY_Q)), "taken, so the game never sees it")
	assert_signal_emitted(InputManager, "binding_captured")
	var params: Array = get_signal_parameters(InputManager, "binding_captured")
	assert_eq(params[0], &"EndTurn")
	assert_eq((params[2] as InputEventKey).physical_keycode, KEY_Q)
	assert_false(InputManager.is_listening())


func test_escape_cancels_except_where_it_belongs() -> void:
	watch_signals(InputManager)
	InputManager.listen_for_binding(&"EndTurn", InputBindings.Kind.KEY)
	InputManager._listen_to(_key(KEY_ESCAPE))
	assert_signal_emitted(InputManager, "binding_cancelled")
	assert_signal_not_emitted(InputManager, "binding_captured")

	InputManager.listen_for_binding(&"PauseMenu", InputBindings.Kind.KEY)
	InputManager._listen_to(_key(KEY_ESCAPE))
	assert_signal_emitted(InputManager, "binding_captured", "Escape can always go back on the pause menu")


func test_listening_for_a_button_ignores_the_stick_and_cancels_on_a_key_or_click() -> void:
	InputManager.listen_for_binding(&"EndTurn", InputBindings.Kind.PAD)
	var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.0
	InputManager._listen_to(stick)
	InputManager._listen_to(_pad(JOY_BUTTON_DPAD_UP))
	assert_true(InputManager.is_listening())
	InputManager._listen_to(_key(KEY_Q))
	assert_false(InputManager.is_listening())

	InputManager.listen_for_binding(&"EndTurn", InputBindings.Kind.PAD)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	InputManager._listen_to(click)
	assert_false(InputManager.is_listening())


func test_a_slot_listens_binds_and_shows_the_swap() -> void:
	var page: OptionsPage = OptionsPage.new()
	add_child_autofree(page)
	var end_turn: BindingSlots = BindingSlots.new(&"EndTurn", page.styled_button)
	page.custom(end_turn, "OPT_ACTION_END_TURN", "", InputBindings.option_key(&"EndTurn"), end_turn.refresh)
	var pause: BindingSlots = BindingSlots.new(&"PauseMenu", page.styled_button)
	page.custom(pause, "OPT_ACTION_PAUSE", "", InputBindings.option_key(&"PauseMenu"), pause.refresh)
	var click: BindingSlots = BindingSlots.new(&"cursor_click", page.styled_button)
	page.custom(click, "OPT_ACTION_CLICK")
	page.refresh()

	assert_true(click.slot(InputBindings.Kind.KEY).disabled, "no keyboard slot for the controller's click")
	end_turn.slot(InputBindings.Kind.PAD).pressed.emit()
	assert_eq(end_turn.slot(InputBindings.Kind.PAD).text, "...")
	InputManager._listen_to(_pad(JOY_BUTTON_START))
	page.refresh()
	assert_eq(end_turn.slot(InputBindings.Kind.PAD).text, InputBindings.event_label(_pad(JOY_BUTTON_START)))
	assert_eq(pause.slot(InputBindings.Kind.PAD).text, "Y")
	assert_has(page.option_keys(), InputBindings.option_key(&"PauseMenu"), "Defaults resets it")


func test_hiding_the_menu_stops_listening() -> void:
	var slots: BindingSlots = BindingSlots.new(&"EndTurn", func(_text: String) -> Button: return Button.new())
	add_child_autofree(slots)
	slots.slot(InputBindings.Kind.KEY).pressed.emit()
	assert_true(InputManager.is_listening())
	slots.hide()
	assert_false(InputManager.is_listening())
