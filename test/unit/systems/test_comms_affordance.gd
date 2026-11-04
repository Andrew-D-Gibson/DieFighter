extends "res://test/helpers/die_fighter_test.gd"
## The targeting computer's portrait replays the targeted ship's last line
## when clicked, and says so with a waveform badge in its corner: dim at rest,
## lit under the pointer, playing once when the ship's first line folds into
## it. The targeted ship's speech folds into the badge when its line runs out
## and unfolds out of it on a replay; the badge only shows while a line is
## tucked away. The pointer stays the plain arrow.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const CURSOR_SCRIPT: GDScript = preload("res://Source/Systems/UI/MouseCursor/mouse_cursor.gd")

var computer: TargetingComputer
var manager: EnemyManager

## The player's saved Controller Mode reaches the test run; FOCUS turns the
## live virtual cursor on, which these tests assume is off.
var _previous_scheme: InputBindings.ControlScheme
var _previous_cursor_active: bool


func before_each() -> void:
	super()
	_previous_scheme = InputManager.control_scheme
	_previous_cursor_active = InputManager.cursor.active
	InputManager.control_scheme = InputBindings.ControlScheme.CURSOR
	InputManager.cursor.active = false
	add_child_autofree(PLAYER_SCENE.instantiate())
	manager = autofree(EnemyManager.new())
	Globals.enemy_manager = manager
	Globals.state_manager = autofree(GameStateManager.new())
	computer = add_child_autofree(COMPUTER_SCENE.instantiate())
	# Lines from an earlier test mustn't make this one wait its turn.
	EnemyDialogueManager.time_last_dialogue_was_shown = 0


func after_each() -> void:
	InputManager.control_scheme = _previous_scheme
	InputManager.cursor.active = _previous_cursor_active
	super()


func _ship() -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	var state_manager: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(ship)
	Globals.state_manager = state_manager
	manager.enemies.append(ship)
	return ship


func _badge() -> Sprite2D:
	return computer.get_node("%CommsBadge")


func _button() -> Clickable:
	return computer.get_node("%CommsButton")


## Has [param ship] say a line and lets it run out, as its fade-out timer
## would, then waits for the box to fold away or fade.
func _line_runs_out(ship: Enemy) -> void:
	var comms: EnemyDialogueManager = ship.dialogue_manager
	comms.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	comms.fadeout_timer.timeout.emit()
	await wait_for_signal(comms.put_away, 2.0)


# ── Dialogue ──────────────────────────────────────────────────────────────────

func test_a_line_running_out_is_announced_and_counted() -> void:
	var ship: Enemy = _ship()
	watch_signals(ship.dialogue_manager)
	await _line_runs_out(ship)
	assert_signal_emitted(ship.dialogue_manager, "line_finished")
	assert_eq(ship.dialogue_manager.lines_finished, 1)


func test_a_line_cut_off_does_not_count_as_run_out() -> void:
	var ship: Enemy = _ship()
	watch_signals(ship.dialogue_manager)
	ship.dialogue_manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	ship.dialogue_manager.show_dialogue("")
	ship.dialogue_manager._on_jump()
	assert_signal_not_emitted(ship.dialogue_manager, "line_finished")


# ── Folding into the badge ────────────────────────────────────────────────────

func _box_middle(comms: EnemyDialogueManager) -> Vector2:
	return comms.to_global(comms.get_node("%Sprite2D").position)


func test_the_targeted_ships_line_folds_into_the_badge() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	var comms: EnemyDialogueManager = ship.dialogue_manager
	watch_signals(comms)
	comms.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	var start: float = _box_middle(comms).distance_to(computer.comms_point())
	comms.fadeout_timer.timeout.emit()
	await wait_seconds(EnemyDialogueManager._FOLD_SECONDS * 0.8)
	assert_lt(comms.scale.x, 0.6, "shrinking on the way in")
	assert_lt(_box_middle(comms).distance_to(computer.comms_point()), start * 0.6, "and closing on the badge")
	await wait_for_signal(comms.put_away, 2.0)
	assert_signal_emitted_with_parameters(comms, "put_away", [true])
	assert_false(comms.visible)
	assert_eq(comms.scale, Vector2.ONE, "back at full size for the next line")


func test_a_ship_that_is_not_targeted_fades_where_it_is() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(_ship())
	watch_signals(ship.dialogue_manager)
	await _line_runs_out(ship)
	assert_signal_emitted_with_parameters(ship.dialogue_manager, "put_away", [false])
	assert_eq(ship.dialogue_manager.scale, Vector2.ONE)


func test_a_replay_unfolds_out_of_the_badge() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	await _line_runs_out(ship)
	var comms: EnemyDialogueManager = ship.dialogue_manager
	_button().clicked.emit()
	assert_true(comms.visible)
	assert_almost_eq(comms.scale.x, EnemyDialogueManager._STOWED_SCALE, 0.01, "starts at the badge's size")
	assert_almost_eq(_box_middle(comms).distance_to(computer.comms_point()), 0.0, 1.0, "and at the badge")
	assert_false(_badge().visible, "the line is out of the badge")
	await wait_seconds(EnemyDialogueManager._UNFOLD_SECONDS + 0.1)
	assert_almost_eq(comms.scale.x, 1.0, 0.01)
	assert_eq(comms.modulate.a, 1.0)


# ── The badge ─────────────────────────────────────────────────────────────────

func test_no_badge_and_no_click_for_a_ship_that_has_said_nothing() -> void:
	computer.target_enemy(_ship())
	assert_false(_badge().visible)
	assert_false(_button().input_pickable)


func test_the_badge_waits_for_the_line_to_fold_in() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	ship.dialogue_manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	assert_false(_badge().visible, "nothing to replay while the line is out")
	assert_false(_button().input_pickable)
	ship.dialogue_manager.fadeout_timer.timeout.emit()
	await wait_for_signal(ship.dialogue_manager.put_away, 2.0)
	assert_true(_badge().visible)
	assert_true(_button().input_pickable)


func test_the_badge_lights_under_the_pointer() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	await _line_runs_out(ship)
	await wait_seconds(1.5)	# past the first-time pulse
	assert_eq(_badge().frame, TargetingComputer._BADGE_IDLE)
	_button()._on_mouse_entered()
	assert_eq(_badge().frame, TargetingComputer._BADGE_LIT)
	_button().reset_hover_state()
	assert_eq(_badge().frame, TargetingComputer._BADGE_IDLE)


func test_the_first_line_folding_in_pulses_the_badge_once() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	await _line_runs_out(ship)
	assert_true(computer.is_badge_pulsing())
	await wait_seconds(1.5)
	assert_false(computer.is_badge_pulsing())
	assert_eq(_badge().frame, TargetingComputer._BADGE_IDLE, "back at rest")

	await _line_runs_out(ship)
	assert_false(computer.is_badge_pulsing(), "only the first time")


func test_switching_to_a_silent_ship_hides_the_badge() -> void:
	var talker: Enemy = _ship()
	var silent: Enemy = _ship()
	computer.target_enemy(talker)
	await _line_runs_out(talker)
	computer.target_enemy(silent)
	assert_false(_badge().visible)
	assert_false(computer.is_badge_pulsing(), "the pulse was the other ship's")


func test_targeting_a_ship_that_spoke_earlier_shows_its_badge() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(_ship())
	await _line_runs_out(ship)
	computer.target_enemy(ship)
	assert_true(_badge().visible)


func test_a_ship_left_behind_in_a_jump_loses_its_badge() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	await _line_runs_out(ship)
	ship.dialogue_manager._on_jump()
	computer._refresh_comms()
	assert_false(_badge().visible)


# ── The pointer ───────────────────────────────────────────────────────────────

func _cursor() -> Sprite2D:
	var layer: CanvasLayer = add_child_autofree(CanvasLayer.new())
	var cursor: Sprite2D = Sprite2D.new()
	cursor.scale = Vector2(6, 6)
	cursor.centered = false
	cursor.set_script(CURSOR_SCRIPT)
	layer.add_child(cursor)
	return cursor


func _hint_of(cursor: Sprite2D) -> Label:
	for child: Node in cursor.get_children():
		if child is Label:
			return child
	return null


## Only the badge lighting up says the portrait can be clicked: no pointer of
## its own, no hint line, no info "i".
func test_the_portrait_keeps_the_plain_arrow() -> void:
	var cursor: Sprite2D = _cursor()
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	await _line_runs_out(ship)
	var arrow: Texture2D = cursor.default_cursor_texture
	_button()._on_mouse_entered()
	_button()._process(_button().hover_delay + 0.1)
	cursor._process(_button().hover_delay + 0.1)
	assert_eq(cursor.texture, arrow)
	assert_null(_hint_of(cursor), "hovering shows no text popup")
	_button().reset_hover_state()
