extends "res://test/helpers/die_fighter_test.gd"

const POPUP: PackedScene = preload("res://Source/Systems/TutorialManager/TutorialTextPopup/tutorial_text_popup.tscn")
var _old_active: bool
var _old_family: StringName
var _old_device: int
var _bindings: Dictionary[StringName, Array] = {}


func before_each() -> void:
	super()
	_old_active = InputManager.controller_active
	_old_family = InputManager.controller_family
	_old_device = InputManager.active_joypad
	for action: StringName in [&"cursor_click", &"target_left", &"target_right"]:
		_bindings[action] = InputBindings.read(action)
		InputBindings.write(action, InputBindings.default_value(action))
	InputManager.set_prompt_device(false)


func after_each() -> void:
	for action: StringName in _bindings:
		InputBindings.write(action, _bindings[action])
	InputManager.controller_active = _old_active
	InputManager.controller_family = _old_family
	InputManager.active_joypad = _old_device
	InputManager.prompts_changed.emit()
	super()


func test_families_detect_explicit_names_before_generic_wireless() -> void:
	assert_eq(InputManager.family_for_name("Xbox Wireless Controller"), &"xbox")
	assert_eq(InputManager.family_for_name("Sony DualSense Wireless Controller"), &"ps")
	assert_eq(InputManager.family_for_name("PS4 Controller"), &"ps")
	assert_eq(InputManager.family_for_name("Steam Virtual Gamepad"), &"steam")
	assert_eq(InputManager.family_for_name("Steam Deck"), &"steam")
	assert_eq(InputManager.family_for_name("Unknown Gamepad"), &"xbox")


func test_drift_does_not_switch_but_deliberate_pad_and_keyboard_input_do() -> void:
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.1
	InputManager.track_prompt_input(motion)
	assert_false(InputManager.controller_active)
	motion.axis_value = 0.8
	InputManager.track_prompt_input(motion)
	assert_true(InputManager.controller_active)
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_SPACE
	InputManager.track_prompt_input(key)
	assert_false(InputManager.controller_active)


func test_virtual_mouse_does_not_switch_controller_prompts_back() -> void:
	InputManager.set_prompt_device(true, 0, "DualSense")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.device = VirtualCursor.DEVICE_ID
	click.pressed = true
	InputManager.track_prompt_input(click)
	assert_true(InputManager.controller_active)
	assert_eq(InputManager.controller_family, &"ps")
	click.device = 0
	InputManager.track_prompt_input(click)
	assert_false(InputManager.controller_active)


func test_disconnect_returns_to_mouse_prompts() -> void:
	InputManager.set_prompt_device(true, 3, "Steam Deck")
	InputManager._on_joy_connection_changed(2, false)
	assert_true(InputManager.controller_active)
	InputManager._on_joy_connection_changed(3, false)
	assert_false(InputManager.controller_active)


func test_each_family_has_icons_for_common_buttons() -> void:
	for family: StringName in [&"xbox", &"ps", &"steam"]:
		for code: int in InputPrompts._BUTTON_NAMES:
			var event: InputEventJoypadButton = InputEventJoypadButton.new()
			event.button_index = code as JoyButton
			assert_false(InputPrompts.event_icon_path(event, family).is_empty(), "%s button %s" % [family, code])


func test_prompt_follows_remapped_binding_and_unknown_button_uses_its_name() -> void:
	InputManager.set_prompt_device(true, 0, "DualSense")
	assert_string_contains(Utils.format_text("Click (left_mouse)"), "ps_cross.png")
	InputBindings.write(&"cursor_click", ["pad:%d" % JOY_BUTTON_X])
	assert_string_contains(Utils.format_text("Click (left_mouse)"), "ps_square.png")
	InputBindings.write(&"cursor_click", ["pad:%d" % JOY_BUTTON_PADDLE1])
	assert_string_contains(Utils.format_text("Click (left_mouse)"), "P1")
	assert_false(Utils.format_text("Click (left_mouse)").contains("mouse_indicator"))


func test_existing_tutorial_and_world_prompt_refresh_without_restarting_reveal() -> void:
	var popup: TutorialTextPopup = add_child_autofree(POPUP.instantiate())
	var ghost: GhostCursor = add_child_autofree(GhostCursor.new())
	popup.setup("Click (left_mouse) to move; change target (targeting_arrows).", Vector2.ZERO)
	popup.current_character = 3
	InputManager.set_prompt_device(true, 0, "DualSense")
	assert_string_contains(popup.get_node("%RichTextLabel").text, "ps_cross.png")
	assert_eq(popup.current_character, 3)
	assert_true(ghost._input_prompt.visible)
	assert_string_contains(ghost._input_prompt.texture.resource_path, "ps_cross.png")
	popup._finish_showing_text()
	InputManager.set_prompt_device(true, 1, "Steam Deck")
	assert_eq(popup.get_node("%RichTextLabel").visible_characters, -1)
	assert_string_contains(popup.get_node("%RichTextLabel").text, "steam_a.png")
	InputManager.set_prompt_device(false)
	assert_string_contains(popup.get_node("%RichTextLabel").text, "mouse_indicator.png")
	assert_false(ghost._input_prompt.visible)
