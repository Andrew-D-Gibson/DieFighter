extends "res://test/helpers/die_fighter_test.gd"
## The comfort options: screenshake intensity (and its migration from the old
## checkbox), Reduce Flashing, Hit Pause, and what the game does in the
## background. Nothing here saves, so the player's options file is never
## touched.

const _CAMERA_SCRIPT: GDScript = preload("res://Source/Systems/UI/Camera/camera.gd")
const _GLITCH_SCRIPT: GDScript = preload("res://Source/Systems/UI/Glitch/glitch_controller.gd")
const _TIME_DIRECTOR_SCRIPT: GDScript = preload("res://Source/Systems/Autoloads/time_director.gd")


## A state manager that skips its _ready(), which wants a whole game scene.
class BareStateManager extends GameStateManager:
	func _ready() -> void:
		pass


var _saved_intensity: float
var _saved_reduce_flashing: bool
var _saved_hitstop: bool
var _saved_master_mute: bool
var _master: int


func before_each() -> void:
	super()
	_saved_intensity = Globals.screenshake_intensity
	_saved_reduce_flashing = Globals.reduce_flashing
	_saved_hitstop = TimeDirector.hitstop_enabled
	_master = AudioServer.get_bus_index(&"Master")
	_saved_master_mute = AudioServer.is_bus_mute(_master)
	Globals.screenshake_intensity = 1.0
	Globals.reduce_flashing = false
	Juice._last_reduced_wash_msec = -100000


func after_each() -> void:
	Globals.screenshake_intensity = _saved_intensity
	Globals.reduce_flashing = _saved_reduce_flashing
	TimeDirector.hitstop_enabled = _saved_hitstop
	AudioServer.set_bus_mute(_master, _saved_master_mute)
	for child: Node in get_tree().root.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 90:
			child.free()
	super()


## Applies [param config] to the screenshake options the way
## load_options_settings() does: each in registration order, its default
## when the file doesn't have it.
func _load_screenshake(config: ConfigFile) -> void:
	for key: StringName in OptionsSettings._options:
		if key != OptionsSettings.SCREENSHAKE and key != OptionsSettings.SCREENSHAKE_INTENSITY:
			continue
		var value: Variant = config.get_value(OptionsSettings._section(key), OptionsSettings._name(key),
			OptionsSettings.get_default(key))
		OptionsSettings._options[key].write.call(value)


# --- Screenshake intensity ---

func test_a_new_player_gets_full_screenshake() -> void:
	Globals.screenshake_intensity = 0.3
	_load_screenshake(ConfigFile.new())
	assert_eq(Globals.screenshake_intensity, 1.0)


func test_an_old_file_with_shake_off_migrates_to_zero() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("Graphics", "screenshake", false)
	_load_screenshake(config)
	assert_eq(Globals.screenshake_intensity, 0.0)


func test_an_old_file_with_shake_on_migrates_to_full() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("Graphics", "screenshake", true)
	Globals.screenshake_intensity = 0.0
	_load_screenshake(config)
	assert_eq(Globals.screenshake_intensity, 1.0)


func test_a_new_file_keeps_its_intensity() -> void:
	# What save_options_settings() writes for a slider at 60%.
	Globals.screenshake_intensity = 0.6
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in [OptionsSettings.SCREENSHAKE_INTENSITY, OptionsSettings.SCREENSHAKE]:
		config.set_value(OptionsSettings._section(key), OptionsSettings._name(key), OptionsSettings.get_option(key))
	assert_eq(config.get_value("Graphics", "screenshake"), true)

	Globals.screenshake_intensity = 1.0
	_load_screenshake(config)
	assert_almost_eq(Globals.screenshake_intensity, 0.6, 0.0001)


func test_the_old_flag_still_reads_on_or_off() -> void:
	Globals.screenshake_intensity = 0.25
	assert_true(Globals.screenshake_enabled)
	Globals.screenshake_intensity = 0.0
	assert_false(Globals.screenshake_enabled)


func test_the_slider_clamps_to_its_range() -> void:
	OptionsSettings.set_option(OptionsSettings.SCREENSHAKE_INTENSITY, 1.7)
	assert_eq(Globals.screenshake_intensity, 1.0)
	OptionsSettings.set_option(OptionsSettings.SCREENSHAKE_INTENSITY, -0.5)
	assert_eq(Globals.screenshake_intensity, 0.0)


func test_zoom_shrinks_with_intensity() -> void:
	assert_almost_eq(_CAMERA_SCRIPT.scaled_zoom(1.4, 1.0), 1.4, 0.0001)
	assert_almost_eq(_CAMERA_SCRIPT.scaled_zoom(1.4, 0.5), 1.2, 0.0001)
	assert_eq(_CAMERA_SCRIPT.scaled_zoom(1.4, 0.0), 1.0)


func test_camera_shakes_scale_with_intensity() -> void:
	var camera: Camera2D = _make_camera()
	var shakeable: Shakeable = camera.get_node("Shakeable")

	Globals.screenshake_intensity = 0.5
	Events.camera_shake_small.emit()
	assert_almost_eq(shakeable.shake_intensity, shakeable.small_shake_intensity * 0.5, 0.0001)
	Events.camera_shake_large.emit(false)
	assert_almost_eq(shakeable.shake_intensity, shakeable.large_shake_intensity * 0.5, 0.0001)


func test_no_camera_motion_at_zero() -> void:
	var camera: Camera2D = _make_camera()
	var shakeable: Shakeable = camera.get_node("Shakeable")

	Globals.screenshake_intensity = 0.0
	Events.camera_shake_large.emit(false)
	Events.camera_zoom_punch.emit(1.3, Vector2.ZERO, false)
	Events.camera_kill_cam.emit(Vector2.ZERO, 0.3)
	assert_false(shakeable.shaking)
	assert_null(camera.get("_punch_tween"))


func test_kill_cam_push_in_is_gentle_and_scales_with_intensity() -> void:
	var camera: Camera2D = _make_camera()
	Globals.screenshake_intensity = 1.0
	Events.camera_kill_cam.emit(Vector2.ZERO, 0.3)
	var tween: Tween = camera.get("_punch_tween")
	# To the end of the hold, where the push-in peaks.
	tween.custom_step(0.3)
	var full_peak: float = camera.zoom.x
	assert_lt(full_peak, 1.2, "a kill pushes in a little, not a lot")
	assert_gt(full_peak, 1.0)
	tween.kill()
	camera.zoom = Vector2.ONE

	Globals.screenshake_intensity = 0.5
	Events.camera_kill_cam.emit(Vector2.ZERO, 0.3)
	(camera.get("_punch_tween") as Tween).custom_step(0.3)
	assert_almost_eq(camera.zoom.x - 1.0, (full_peak - 1.0) * 0.5, 0.005,
		"half Screenshake, half the push-in")


func _make_camera() -> Camera2D:
	var camera: Camera2D = Camera2D.new()
	camera.set_script(_CAMERA_SCRIPT)
	var shakeable: Shakeable = Shakeable.new()
	shakeable.name = "Shakeable"
	camera.add_child(shakeable)
	add_child_autofree(camera)
	return camera


# --- Reduce Flashing ---

func test_flashes_play_as_authored_normally() -> void:
	assert_eq(Juice.soften_flash(0.8), 0.8)
	assert_eq(Juice.screen_wash_alpha(1.0), 1.0)


func test_reduce_flashing_tones_flashes_down() -> void:
	OptionsSettings.set_option(OptionsSettings.REDUCE_FLASHING, true)
	assert_true(Globals.reduce_flashing)
	assert_lt(Juice.soften_flash(1.0), 0.5)
	assert_lte(Juice.screen_wash_alpha(1.0), 0.1)


func test_a_screen_flash_is_a_faint_tint_and_never_strobes() -> void:
	Globals.reduce_flashing = true
	var context: Node = add_child_autofree(Node.new())
	Juice.screen_flash(context, Color.WHITE, 0.45, 0.1)
	Juice.screen_flash(context, Color.WHITE, 0.45, 0.1)

	var washes: Array[ColorRect] = _screen_washes()
	assert_eq(washes.size(), 1, "the second flash, right after the first, is dropped")
	assert_lte(washes[0].color.a, 0.1)


func test_a_screen_flash_is_full_strength_normally() -> void:
	var context: Node = add_child_autofree(Node.new())
	Juice.screen_flash(context, Color.WHITE, 0.45, 0.1)
	Juice.screen_flash(context, Color.WHITE, 0.45, 0.1)

	var washes: Array[ColorRect] = _screen_washes()
	assert_eq(washes.size(), 2)
	assert_almost_eq(washes[0].color.a, 0.45, 0.0001)


func test_flash_target_brightens_less_under_reduce_flashing() -> void:
	var item: Node2D = add_child_autofree(Node2D.new())
	_flash_item(item)
	var full: float = item.modulate.r

	Globals.reduce_flashing = true
	item.modulate = Color.WHITE
	_flash_item(item)
	assert_eq(full, 2.0)
	assert_lt(item.modulate.r, 1.5)


func test_the_glitch_stays_off_under_reduce_flashing() -> void:
	var glitch: ColorRect = ColorRect.new()
	glitch.set_script(_GLITCH_SCRIPT)
	add_child_autofree(glitch)

	Events.set_glitch.emit(true)
	assert_true(glitch.visible)
	Events.set_glitch.emit(false)

	Globals.reduce_flashing = true
	Events.set_glitch.emit(true)
	assert_false(glitch.visible)


func _flash_item(item: Node2D) -> void:
	var event: FlashTargetEvent = FlashTargetEvent.new()
	event.color = Color.WHITE
	event.targets = [item]
	event.resolve(null)


func _screen_washes() -> Array[ColorRect]:
	var washes: Array[ColorRect] = []
	for child: Node in get_tree().root.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 90 and not child.is_queued_for_deletion():
			washes.append(child.get_child(0) as ColorRect)
	return washes


# --- Hit Pause ---

func test_hit_pause_option_drives_the_time_director() -> void:
	OptionsSettings.set_option(OptionsSettings.HIT_PAUSE, false)
	assert_false(TimeDirector.hitstop_enabled)
	OptionsSettings.set_option(OptionsSettings.HIT_PAUSE, true)
	assert_true(TimeDirector.hitstop_enabled)


func test_hitstop_does_nothing_with_hit_pause_off() -> void:
	var director: Node = autofree(_TIME_DIRECTOR_SCRIPT.new())
	director.hitstop_enabled = false
	await director.hitstop(200)
	assert_eq(director._requests.size(), 0)
	assert_eq(Engine.time_scale, 1.0)


func test_slow_mo_still_plays_with_hit_pause_off() -> void:
	var director: Node = autofree(_TIME_DIRECTOR_SCRIPT.new())
	director.hitstop_enabled = false
	director.slow_mo(0.5, 200)
	assert_eq(director._requests.size(), 1)
	director.clear()


# --- In the background ---

func test_losing_focus_silences_the_game_and_regaining_it_restores() -> void:
	var focus: BackgroundFocus = add_child_autofree(BackgroundFocus.new())
	var effects: int = AudioServer.get_bus_effect_count(_master)

	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(focus.is_silenced())
	assert_eq(AudioServer.get_bus_effect_count(_master), effects + 1)

	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(focus.is_silenced())
	assert_eq(AudioServer.get_bus_effect_count(_master), effects)


func test_background_mute_leaves_mute_all_alone() -> void:
	var focus: BackgroundFocus = add_child_autofree(BackgroundFocus.new())
	for mute_all: bool in [false, true]:
		AudioServer.set_bus_mute(_master, mute_all)
		focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		assert_eq(AudioServer.is_bus_mute(_master), mute_all, "Mute All reads the same in the background")
		focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		assert_eq(AudioServer.is_bus_mute(_master), mute_all)


func test_no_background_mute_when_turned_off() -> void:
	var focus: BackgroundFocus = add_child_autofree(BackgroundFocus.new())
	focus.mute_in_background = false
	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(focus.is_silenced())


func test_turning_the_mute_off_in_the_background_brings_the_sound_back() -> void:
	var focus: BackgroundFocus = add_child_autofree(BackgroundFocus.new())
	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	focus.mute_in_background = false
	assert_false(focus.is_silenced())


func test_leaving_the_tree_never_leaves_the_game_silent() -> void:
	var focus: BackgroundFocus = BackgroundFocus.new()
	add_child(focus)
	var effects: int = AudioServer.get_bus_effect_count(_master)
	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	focus.free()
	assert_eq(AudioServer.get_bus_effect_count(_master), effects)


func test_options_bind_to_the_background_watcher() -> void:
	var focus: BackgroundFocus = OptionsSettings.background_focus
	var saved_mute: bool = focus.mute_in_background
	var saved_pause: bool = focus.pause_in_background
	OptionsSettings.set_option(OptionsSettings.MUTE_IN_BACKGROUND, false)
	OptionsSettings.set_option(OptionsSettings.PAUSE_IN_BACKGROUND, true)
	assert_false(focus.mute_in_background)
	assert_true(focus.pause_in_background)
	focus.mute_in_background = saved_mute
	focus.pause_in_background = saved_pause


func test_losing_focus_mid_run_opens_the_pause_menu() -> void:
	var focus: BackgroundFocus = add_child_autofree(BackgroundFocus.new())
	focus.pause_in_background = true
	Globals.state_manager = add_child_autofree(BareStateManager.new())
	watch_signals(Events)

	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_signal_emit_count(Events, "toggle_pause_menu", 1)


func test_no_pause_when_turned_off_or_outside_a_run() -> void:
	var focus: BackgroundFocus = add_child_autofree(BackgroundFocus.new())
	watch_signals(Events)

	# The main menu: no run under way.
	focus.pause_in_background = true
	Globals.state_manager = null
	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	# Mid-run, but the option is off.
	focus.pause_in_background = false
	Globals.state_manager = add_child_autofree(BareStateManager.new())
	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	# The run is over.
	focus.pause_in_background = true
	Globals.state_manager.state = GameStateManager.GameState.GAME_OVER
	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	assert_signal_emit_count(Events, "toggle_pause_menu", 0)


func test_no_pause_when_the_game_is_already_paused() -> void:
	var focus: BackgroundFocus = add_child_autofree(BackgroundFocus.new())
	focus.pause_in_background = true
	Globals.state_manager = add_child_autofree(BareStateManager.new())
	watch_signals(Events)
	# Opening the menu again would toggle it shut.
	get_tree().paused = true
	focus.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	get_tree().paused = false
	assert_signal_emit_count(Events, "toggle_pause_menu", 0)
