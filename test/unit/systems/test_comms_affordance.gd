extends "res://test/helpers/die_fighter_test.gd"
## The targeting computer's portrait replays the targeted ship's last line
## when clicked, and says so: a waveform badge in its corner (dim at rest, lit
## under the pointer, playing once when the ship's first line runs out), the
## comms pointer and a "Click to replay comms" hint. None of it shows for a
## ship with nothing to replay.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const CURSOR_SCRIPT: GDScript = preload("res://Source/Systems/UI/MouseCursor/mouse_cursor.gd")
const COMMS_CURSOR: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/comms_cursor_raw.png")

var computer: TargetingComputer
var manager: EnemyManager


func before_each() -> void:
	super()
	add_child_autofree(PLAYER_SCENE.instantiate())
	manager = autofree(EnemyManager.new())
	Globals.enemy_manager = manager
	Globals.state_manager = autofree(GameStateManager.new())
	computer = add_child_autofree(COMPUTER_SCENE.instantiate())
	# Lines from an earlier test mustn't make this one wait its turn.
	EnemyDialogueManager.time_last_dialogue_was_shown = 0


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


## Has [param ship] say a line and lets it run out, as its fade-out timer would.
func _line_runs_out(ship: Enemy) -> void:
	var comms: EnemyDialogueManager = ship.dialogue_manager
	comms.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	comms.fadeout_timer.timeout.emit()


# ── Dialogue ──────────────────────────────────────────────────────────────────

func test_a_line_running_out_is_announced_and_counted() -> void:
	var ship: Enemy = _ship()
	watch_signals(ship.dialogue_manager)
	_line_runs_out(ship)
	assert_signal_emitted(ship.dialogue_manager, "line_finished")
	assert_eq(ship.dialogue_manager.lines_finished, 1)


func test_a_line_cut_off_does_not_count_as_run_out() -> void:
	var ship: Enemy = _ship()
	watch_signals(ship.dialogue_manager)
	ship.dialogue_manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	ship.dialogue_manager.show_dialogue("")
	ship.dialogue_manager._on_jump()
	assert_signal_not_emitted(ship.dialogue_manager, "line_finished")


# ── The badge ─────────────────────────────────────────────────────────────────

func test_no_badge_and_no_click_for_a_ship_that_has_said_nothing() -> void:
	computer.target_enemy(_ship())
	assert_false(_badge().visible)
	assert_false(_button().input_pickable)


func test_the_badge_shows_dim_once_the_ship_has_spoken() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	ship.dialogue_manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	assert_true(_badge().visible)
	assert_eq(_badge().frame, TargetingComputer._BADGE_IDLE)
	assert_true(_button().input_pickable)


func test_the_badge_lights_under_the_pointer() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	ship.dialogue_manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	_button()._on_mouse_entered()
	assert_eq(_badge().frame, TargetingComputer._BADGE_LIT)
	_button().reset_hover_state()
	assert_eq(_badge().frame, TargetingComputer._BADGE_IDLE)


func test_the_first_line_running_out_pulses_the_badge_once() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	_line_runs_out(ship)
	assert_true(computer.is_badge_pulsing())
	await wait_seconds(1.5)
	assert_false(computer.is_badge_pulsing())
	assert_eq(_badge().frame, TargetingComputer._BADGE_IDLE, "back at rest")

	_line_runs_out(ship)
	assert_false(computer.is_badge_pulsing(), "only the first time")


func test_switching_to_a_silent_ship_hides_the_badge() -> void:
	var talker: Enemy = _ship()
	var silent: Enemy = _ship()
	computer.target_enemy(talker)
	_line_runs_out(talker)
	computer.target_enemy(silent)
	assert_false(_badge().visible)
	assert_false(computer.is_badge_pulsing(), "the pulse was the other ship's")


func test_a_ship_left_behind_in_a_jump_loses_its_badge() -> void:
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	ship.dialogue_manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
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


func test_the_portrait_wears_the_comms_pointer_then_the_hint() -> void:
	var cursor: Sprite2D = _cursor()
	var ship: Enemy = _ship()
	computer.target_enemy(ship)
	ship.dialogue_manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
	_button()._on_mouse_entered()
	cursor._process(0.0)
	assert_eq(cursor.texture, COMMS_CURSOR, "the pointer says so at once")
	assert_false(_hint_of(cursor).visible, "the hint waits for the pointer to rest")

	cursor._process(_button().hover_delay)
	assert_true(_hint_of(cursor).visible)
	assert_eq(_hint_of(cursor).text, tr(&"CURSOR_HINT_REPLAY_COMMS"))

	_button().reset_hover_state()
	cursor._process(0.0)
	assert_ne(cursor.texture, COMMS_CURSOR)
	assert_false(_hint_of(cursor).visible)


func test_a_portrait_with_nothing_to_replay_keeps_the_arrow() -> void:
	var cursor: Sprite2D = _cursor()
	computer.target_enemy(_ship())
	# The area takes no input with nothing to replay, but even a stray
	# enter shouldn't promise a replay.
	_button()._on_mouse_entered()
	cursor._process(1.0)
	assert_ne(cursor.texture, COMMS_CURSOR)
	assert_false(_hint_of(cursor).visible)
	_button().reset_hover_state()


func test_the_hint_is_a_translation_key() -> void:
	assert_ne(tr(_button().hover_hint), String(_button().hover_hint), "the key has English text")
