extends "res://test/helpers/die_fighter_test.gd"
## The tutorial: its authored steps, and the waits that move it along.
##
## The manager is added to the tree with no steps, so _ready() returns before
## it seeds a run, connects to Events or locks anything.

const STEP_DIR: String = "res://Source/Systems/TutorialManager/TutorialStepResources/"
const MAIN_SCENE: String = "res://Source/Scenes/main.tscn"

## Steps that end themselves rather than on a gameplay event.
const SELF_CLOSING: Array[TutorialStep.TutorialSignals] = [
	TutorialStep.TutorialSignals.NONE,
	TutorialStep.TutorialSignals.CLOSED_MANUALLY,
	TutorialStep.TutorialSignals.CLOSED_AFTER_TIME,
]

signal _opening_event

var manager: TutorialManager


func before_each() -> void:
	super()
	manager = add_child_autofree(TutorialManager.new())


static func _step_paths() -> Array[String]:
	var paths: Array[String] = []
	for file: String in DirAccess.get_files_at(STEP_DIR):
		if file.ends_with(".tres"):
			paths.append(STEP_DIR.path_join(file))
	return paths


func test_step_text_has_no_unknown_tokens() -> void:
	var leftover := RegEx.create_from_string("\\([a-z_0-9]+\\)")
	for path: String in _step_paths():
		var step: TutorialStep = load(path)
		var shown: String = Utils.format_with_delays(step.tutorial_text)["text"]
		var stray: RegExMatch = leftover.search(shown)
		assert_null(stray, "%s: unknown token %s" % [path, stray.get_string() if stray else ""])


func test_every_step_waits_on_a_real_signal() -> void:
	for path: String in _step_paths():
		var step: TutorialStep = load(path)
		if step.close_on_signal in SELF_CLOSING:
			continue
		assert_false(manager._closing_signal_for(step).is_null(),
			"%s closes on %s, which no signal is wired to" % [
				path, TutorialStep.TutorialSignals.keys()[step.close_on_signal]
			])


## A step file the scene doesn't list is dead weight that looks live; a listed
## one that fails to load would silently drop out of the tutorial.
func test_main_scene_plays_every_step_file() -> void:
	var state: SceneState = (load(MAIN_SCENE) as PackedScene).get_state()
	var listed: Array[String] = []
	for node: int in state.get_node_count():
		if state.get_node_name(node) != &"TutorialManager":
			continue
		for prop: int in state.get_node_property_count(node):
			var value: Variant = state.get_node_property_value(node, prop)
			match state.get_node_property_name(node, prop):
				&"tutorial_steps":
					for step: TutorialStep in value:
						listed.append(step.resource_path)
				&"opening_setup":
					listed.append((value as TutorialStep).resource_path)

	var files: Array[String] = _step_paths()
	files.sort()
	listed.sort()
	assert_eq(listed, files)


func test_open_wait_gives_up_after_its_timeout() -> void:
	var step := TutorialStep.new()
	step.max_wait_time = 0.2
	var opened: Array[bool] = [false]
	var wait: Callable = func() -> void:
		await manager._await_open_signal(_opening_event, step)
		opened[0] = true
	# A slow frame before this one (loading main.tscn) would otherwise land
	# its whole delta on the new timer and fire it at once.
	await wait_physics_frames(2)
	wait.call()
	await wait_physics_frames(1)
	assert_false(opened[0], "gave up before its timeout")
	await wait_seconds(0.4)
	assert_true(opened[0], "still waiting after its timeout")


func test_open_wait_ends_on_its_signal() -> void:
	var step := TutorialStep.new()
	step.max_wait_time = 5.0
	var opened: Array[bool] = [false]
	var wait: Callable = func() -> void:
		await manager._await_open_signal(_opening_event, step)
		opened[0] = true
	wait.call()
	_opening_event.emit()
	await wait_physics_frames(1)
	assert_true(opened[0])


func test_an_earlier_waits_timeout_doesnt_end_a_later_wait() -> void:
	var quick := TutorialStep.new()
	quick.max_wait_time = 0.05
	var first: Callable = func() -> void:
		await manager._await_open_signal(_opening_event, quick)
	first.call()
	_opening_event.emit()

	var slow := TutorialStep.new()
	slow.max_wait_time = 5.0
	var opened: Array[bool] = [false]
	var second: Callable = func() -> void:
		await manager._await_open_signal(_opening_event, slow)
		opened[0] = true
	second.call()

	await wait_seconds(0.15)
	assert_false(opened[0], "the first wait's timer fired into the second")
	_opening_event.emit()
	await wait_physics_frames(1)
	assert_true(opened[0])


func test_end_turn_prompt_counts_a_turn_already_ended() -> void:
	var step := TutorialStep.new()
	step.close_on_signal = TutorialStep.TutorialSignals.PLAYER_TURN_OVER
	assert_false(manager._already_satisfied(step))
	manager._on_player_turn_over()
	assert_true(manager._already_satisfied(step))
	manager._on_player_turn_start()
	assert_false(manager._already_satisfied(step))


func test_instruction_steps_are_never_skipped() -> void:
	var step := TutorialStep.new()
	step.close_on_signal = TutorialStep.TutorialSignals.ENEMY_RECEIVED_DIE
	manager._on_player_turn_over()
	manager._on_reward_picked()
	assert_false(manager._already_satisfied(step))


func test_steps_waiting_on_the_player_never_time_out() -> void:
	var step := TutorialStep.new()
	step.close_on_signal = TutorialStep.TutorialSignals.PLAYER_TURN_OVER
	assert_eq(manager._closing_timeout(step), 0.0)


func test_steps_waiting_on_the_game_keep_the_backstop() -> void:
	var step := TutorialStep.new()
	step.close_on_signal = TutorialStep.TutorialSignals.PLAYER_TURN_STARTED
	assert_eq(manager._closing_timeout(step), manager.default_step_timeout)
	step.max_wait_time = 7.0
	assert_eq(manager._closing_timeout(step), 7.0)


## The retarget step opens the highlight round each ship with an ellipse
## worked out on the spot, so it can't be checked by eye in the art.
func test_target_cutout_clears_an_ellipse_and_nothing_else() -> void:
	var image := Image.create(20, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	TutorialManager._cut_ellipse(image, Rect2(2, 2, 10, 6))
	assert_eq(image.get_pixel(7, 5).a, 0.0, "the middle is cleared")
	assert_eq(image.get_pixel(2, 2).a, 1.0, "the box's corner stays dark")
	assert_eq(image.get_pixel(15, 5).a, 1.0, "outside the box stays dark")


## The opening raider has to survive the first turn and fall on the second:
## the steps between are about its turn. It spawns on its authored hull, so a
## balance pass on everyone else can't shorten the fight.
func test_opening_raider_arrives_on_twelve_hull() -> void:
	var ambush: ScenarioResource = load("res://Source/Content/ScenarioResources/Scenarios/COMBAT_OpeningAmbush/COMBAT_opening_ambush.tres")
	var raider: EnemyStateRewardResource = ambush.starting_enemies[0]
	assert_true(raider.unscaled_hull)
	assert_eq(Enemy.starting_hull(raider.enemy_resource.max_health, raider.starting_health_fraction), 12)


## The hand that finishes the raider is the hand the player jumps with, faces
## and all. Only 6s are safe: Bump would turn a 4 into a 5, and 5 places on
## the seeded map is a fight built round a hazard. See TutorialManager.run_seed.
func test_raider_is_finished_with_dice_bump_cant_change() -> void:
	var step: TutorialStep = load(STEP_DIR.path_join("enemy_response.tres"))
	assert_false(step.forced_dice.is_empty())
	for face: int in step.forced_dice:
		assert_eq(face, 6)
