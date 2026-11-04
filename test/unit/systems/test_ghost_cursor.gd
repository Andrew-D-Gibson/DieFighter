extends "res://test/helpers/die_fighter_test.gd"
## The tutorial's ghost cursor: its timeline, how its targets are found, when
## it shows and hides, and that every step asking for a drag or click has one.

const STEP_DIR: String = "res://Source/Systems/TutorialManager/TutorialStepResources/"
const MAIN_SCENE: String = "res://Source/Scenes/main.tscn"

## Steps that close when the player does something with the mouse.
const PLAYER_ACTIONS: Array[TutorialStep.TutorialSignals] = [
	TutorialStep.TutorialSignals.TILE_ACTIVATED,
	TutorialStep.TutorialSignals.PLAYER_TURN_OVER,
	TutorialStep.TutorialSignals.ENEMY_DEFEATED,
	TutorialStep.TutorialSignals.REWARD_CLAIMED,
	TutorialStep.TutorialSignals.MAP_OPENED,
	TutorialStep.TutorialSignals.ON_JUMP,
	TutorialStep.TutorialSignals.ON_TARGET_SWITCH,
]

const FROM: Vector2 = Vector2(40, 150)
const TO: Vector2 = Vector2(120, 110)

var root: Node2D
var ghost: GhostCursor
## What the stand-in mouse is doing.
var busy: bool = false


func before_each() -> void:
	super()
	busy = false
	root = add_child_autofree(Node2D.new())
	ghost = GhostCursor.new()
	ghost.is_player_busy = func() -> bool: return busy
	root.add_child(ghost)


static func _node_target(path: String, offset: Vector2 = Vector2.ZERO) -> GhostTarget:
	var target: GhostTarget = GhostTarget.new()
	target.kind = GhostTarget.Kind.NODE
	target.node_path = NodePath(path)
	target.offset = offset
	return target


static func _drag(from: GhostTarget, to: GhostTarget) -> GhostDemo:
	var demo: GhostDemo = GhostDemo.new()
	demo.gesture = GhostDemo.Gesture.DRAG
	demo.at = from
	demo.to = to
	return demo


static func _click(at: GhostTarget) -> GhostDemo:
	var demo: GhostDemo = GhostDemo.new()
	demo.gesture = GhostDemo.Gesture.CLICK
	demo.at = at
	return demo


func _add_marker(marker_name: String, at: Vector2) -> Node2D:
	var marker: Node2D = Node2D.new()
	marker.name = marker_name
	root.add_child(marker)
	marker.global_position = at
	return marker


## A drag and the two markers it runs between.
func _marked_drag() -> Array[GhostDemo]:
	_add_marker("From", FROM)
	_add_marker("To", TO)
	var demos: Array[GhostDemo] = [_drag(_node_target("From"), _node_target("To"))]
	return demos


# --- Timeline ---

func test_a_drag_fades_in_on_its_start_presses_carries_and_lets_go() -> void:
	var start: GhostCursor.Pose = GhostCursor.pose_at(GhostDemo.Gesture.DRAG, FROM, TO, 0.0)
	assert_eq(start.position, FROM)
	assert_eq(start.alpha, 0.0)
	assert_false(start.pressed)

	var gripped_at: float = GhostCursor.FADE_SECONDS + GhostCursor.SETTLE_SECONDS + 0.05
	var gripped: GhostCursor.Pose = GhostCursor.pose_at(GhostDemo.Gesture.DRAG, FROM, TO, gripped_at)
	assert_true(gripped.pressed, "pressed before it moves")
	assert_eq(gripped.position, FROM)

	var move: float = GhostCursor.move_seconds(FROM, TO)
	var halfway_at: float = gripped_at - 0.05 + GhostCursor.PRESS_SECONDS + move / 2.0
	var halfway: GhostCursor.Pose = GhostCursor.pose_at(GhostDemo.Gesture.DRAG, FROM, TO, halfway_at)
	assert_true(halfway.pressed)
	assert_almost_eq(halfway.position, FROM.lerp(TO, 0.5), Vector2(0.5, 0.5), "eased, symmetric")

	var arrived_at: float = halfway_at + move / 2.0 + 0.05
	var arrived: GhostCursor.Pose = GhostCursor.pose_at(GhostDemo.Gesture.DRAG, FROM, TO, arrived_at)
	assert_eq(arrived.position, TO)
	assert_true(arrived.pressed, "held a moment at the drop")

	var let_go: GhostCursor.Pose = GhostCursor.pose_at(
		GhostDemo.Gesture.DRAG, FROM, TO, arrived_at + GhostCursor.PRESS_SECONDS)
	assert_false(let_go.pressed)
	assert_eq(let_go.alpha, 1.0)

	var done: GhostCursor.Pose = GhostCursor.pose_at(GhostDemo.Gesture.DRAG, FROM, TO,
		GhostCursor.duration_of(GhostDemo.Gesture.DRAG, FROM, TO))
	assert_eq(done.alpha, 0.0, "hidden through the pause before the next loop")


func test_a_click_glides_in_and_rings_where_it_presses() -> void:
	var start: GhostCursor.Pose = GhostCursor.pose_at(GhostDemo.Gesture.CLICK, TO, TO, 0.0)
	assert_eq(start.position, TO + GhostCursor.CLICK_APPROACH)
	assert_lt(start.ripple, 0.0)

	var press_at: float = GhostCursor.FADE_SECONDS + GhostCursor.APPROACH_SECONDS \
		+ GhostCursor.SETTLE_SECONDS + 0.05
	var press: GhostCursor.Pose = GhostCursor.pose_at(GhostDemo.Gesture.CLICK, TO, TO, press_at)
	assert_eq(press.position, TO)
	assert_true(press.pressed)
	assert_between(press.ripple, 0.0, 1.0)

	var after: GhostCursor.Pose = GhostCursor.pose_at(
		GhostDemo.Gesture.CLICK, TO, TO, press_at + GhostCursor.PRESS_SECONDS)
	assert_false(after.pressed, "a click lets straight go")
	assert_eq(after.position, TO)


func test_drag_speed_stays_within_its_bounds() -> void:
	assert_eq(GhostCursor.move_seconds(FROM, FROM + Vector2(2, 0)), GhostCursor.MIN_MOVE_SECONDS)
	assert_eq(GhostCursor.move_seconds(FROM, FROM + Vector2(1000, 0)), GhostCursor.MAX_MOVE_SECONDS)


# --- Targets ---

func test_a_node_target_points_at_a_node2d_plus_its_offset() -> void:
	_add_marker("Marker", Vector2(30, 40))
	assert_eq(_node_target("Marker").resolve(root), Vector2(30, 40))
	assert_eq(_node_target("Marker", Vector2(5, -2)).resolve(root), Vector2(35, 38))


func test_a_node_target_points_at_a_controls_middle() -> void:
	var button: Control = Control.new()
	button.name = "Button"
	root.add_child(button)
	button.position = Vector2(10, 20)
	button.size = Vector2(40, 12)
	assert_eq(_node_target("Button").resolve(root), Vector2(30, 26))


func test_a_node_target_points_at_an_areas_shape() -> void:
	var area: Area2D = Area2D.new()
	area.name = "Area"
	root.add_child(area)
	area.position = Vector2(50, 50)
	var shape: CollisionShape2D = CollisionShape2D.new()
	area.add_child(shape)
	shape.position = Vector2(20, 7)
	assert_eq(_node_target("Area").resolve(root), Vector2(70, 57))


func test_a_missing_or_hidden_node_is_unresolved() -> void:
	assert_false(GhostTarget.is_resolved(_node_target("Nobody").resolve(root)))
	var hidden: Node2D = _add_marker("Hidden", Vector2(1, 1))
	hidden.hide()
	assert_false(GhostTarget.is_resolved(_node_target("Hidden").resolve(root)))
	assert_false(GhostTarget.is_resolved(_node_target("Hidden").resolve(null)))


func test_game_targets_are_unresolved_without_the_game() -> void:
	Globals.player = null
	Globals.tile_grid = null
	Globals.reward_manager = null
	Globals.map = null
	Globals.enemy_manager = null
	Globals.targeting_computer = null
	for kind: int in GhostTarget.Kind.values():
		if kind == GhostTarget.Kind.NODE:
			continue
		var target: GhostTarget = GhostTarget.new()
		target.kind = kind
		assert_false(GhostTarget.is_resolved(target.resolve(root)),
			"%s with no game" % GhostTarget.Kind.keys()[kind])


func test_a_tile_target_also_matches_its_upgrade() -> void:
	var base: TileResource = load("res://Source/Content/Tiles/TileResources/damage.tres")
	assert_true(GhostTarget.is_tile(base, base))
	assert_true(GhostTarget.is_tile(base.upgraded_version, base))
	assert_false(GhostTarget.is_tile(load("res://Source/Content/Tiles/TileResources/bump.tres"), base))
	assert_false(GhostTarget.is_tile(null, base))


# --- Playing ---

func test_it_shows_once_its_lead_is_over_and_hides_when_stopped() -> void:
	ghost.play(_marked_drag(), root, 0.5)
	ghost.advance(0.4)
	assert_false(ghost.is_showing(), "still in its lead")
	ghost.advance(0.2)
	ghost.advance(GhostCursor.FADE_SECONDS)
	assert_true(ghost.is_showing())
	assert_almost_eq(ghost.global_position, FROM, Vector2(0.01, 0.01))

	ghost.stop()
	assert_false(ghost.is_playing())
	assert_false(ghost.is_showing())
	ghost.advance(1.0)
	assert_false(ghost.is_showing(), "stays gone")


func test_it_gets_out_of_the_way_while_the_player_holds_something() -> void:
	ghost.play(_marked_drag(), root)
	ghost.advance(GhostCursor.FADE_SECONDS + 0.1)
	assert_true(ghost.is_showing())

	busy = true
	ghost.advance(0.016)
	assert_false(ghost.is_showing())
	ghost.advance(5.0)
	assert_false(ghost.is_showing(), "hidden for as long as they hold on")

	busy = false
	ghost.advance(GhostCursor.RESUME_SECONDS + 0.01)
	ghost.advance(GhostCursor.FADE_SECONDS)
	assert_true(ghost.is_showing(), "back after a pause")
	assert_almost_eq(ghost.global_position, FROM, Vector2(0.01, 0.01), "from the top of its demo")


func test_it_waits_for_a_target_that_isnt_there_yet() -> void:
	var demos: Array[GhostDemo] = [_drag(_node_target("From"), _node_target("To"))]
	ghost.play(demos, root)
	for _frame: int in 20:
		ghost.advance(0.1)
	assert_false(ghost.is_showing())

	_add_marker("From", FROM)
	_add_marker("To", TO)
	for _frame: int in 6:
		ghost.advance(0.1)
	assert_true(ghost.is_showing())


func test_it_follows_a_target_that_moves() -> void:
	var from: Node2D = _add_marker("From", FROM)
	_add_marker("To", TO)
	var demos: Array[GhostDemo] = [_drag(_node_target("From"), _node_target("To"))]
	ghost.play(demos, root)
	ghost.advance(GhostCursor.FADE_SECONDS + 0.05)
	from.global_position = FROM + Vector2(0, -3)
	ghost.advance(0.05)
	assert_almost_eq(ghost.global_position, FROM + Vector2(0, -3), Vector2(0.01, 0.01))


func test_it_plays_its_demos_in_turn_and_loops() -> void:
	_add_marker("From", FROM)
	_add_marker("To", TO)
	_add_marker("Button", Vector2(200, 160))
	var demos: Array[GhostDemo] = [
		_drag(_node_target("From"), _node_target("To")),
		_click(_node_target("Button")),
	]
	ghost.play(demos, root)
	var drag: float = GhostCursor.duration_of(GhostDemo.Gesture.DRAG, FROM, TO)
	var click: float = GhostCursor.duration_of(GhostDemo.Gesture.CLICK, Vector2.ZERO, Vector2.ZERO)

	ghost.advance(drag + 0.01)
	ghost.advance(GhostCursor.FADE_SECONDS)
	assert_almost_eq(ghost.global_position, Vector2(200, 160) + GhostCursor.CLICK_APPROACH,
		Vector2(0.01, 0.01), "on to the click")
	ghost.advance(click - GhostCursor.FADE_SECONDS + 0.01)
	ghost.advance(GhostCursor.FADE_SECONDS)
	assert_almost_eq(ghost.global_position, FROM, Vector2(0.01, 0.01), "and round again")


func test_it_skips_a_demo_missing_an_end() -> void:
	var broken: GhostDemo = _drag(_node_target("From"), null)
	var demos: Array[GhostDemo] = [broken]
	ghost.play(demos, root)
	assert_push_warning("GhostCursor: skipping a demo")
	assert_false(ghost.is_playing())


func test_a_drag_carries_a_copy_of_what_it_picked_up() -> void:
	var from: Node2D = _add_marker("From", FROM)
	_add_marker("To", TO)
	var face: Sprite2D = Sprite2D.new()
	face.texture = PlaceholderTexture2D.new()
	from.add_child(face)
	face.position = Vector2(1, 2)
	var demos: Array[GhostDemo] = [_drag(_node_target("From"), _node_target("To"))]
	ghost.play(demos, root)

	ghost.advance(GhostCursor.FADE_SECONDS + 0.05)
	assert_false(ghost._carried.visible, "nothing carried before the press")
	ghost.advance(GhostCursor.SETTLE_SECONDS)
	assert_true(ghost._carried.visible)
	assert_eq(ghost._carried.texture, face.texture)
	assert_eq(ghost._carried.position, Vector2(1, 2), "held where it was gripped")

	ghost.advance(GhostCursor.PRESS_SECONDS + GhostCursor.move_seconds(FROM, TO) + GhostCursor.PRESS_SECONDS)
	assert_false(ghost._carried.visible, "let go at the drop")


func test_it_draws_over_the_tutorial_dim_and_cards() -> void:
	assert_false(ghost.z_as_relative)
	assert_gt(ghost.z_index, TutorialTextPopup.SHOWN_THROUGH_DIM_Z_INDEX)


# --- The tutorial ---

func test_the_manager_plays_a_steps_demos_and_stops_them() -> void:
	var manager: TutorialManager = add_child_autofree(TutorialManager.new())
	_marked_drag()
	var step: TutorialStep = TutorialStep.new()
	var demos: Array[GhostDemo] = [_drag(_node_target("From"), _node_target("To"))]
	step.ghost_demos = demos
	manager.play_ghost_demos(step)
	assert_not_null(manager._ghost)
	assert_true(manager._ghost.is_playing())

	manager.stop_ghost_demos()
	assert_false(manager._ghost.is_playing())


func test_a_step_with_nothing_to_show_makes_no_ghost() -> void:
	var manager: TutorialManager = add_child_autofree(TutorialManager.new())
	manager.play_ghost_demos(TutorialStep.new())
	assert_null(manager._ghost)
	manager.stop_ghost_demos()


static func _step_paths() -> Array[String]:
	var paths: Array[String] = []
	for file: String in DirAccess.get_files_at(STEP_DIR):
		if file.ends_with(".tres"):
			paths.append(STEP_DIR.path_join(file))
	return paths


## A step that waits on a mouse action shows the player how. Keyed on the
## signal, not the card's wording, so rewriting a card never trips this.
func test_every_step_asking_for_a_drag_or_click_demonstrates_it() -> void:
	for path: String in _step_paths():
		var step: TutorialStep = load(path)
		if step.close_on_signal in PLAYER_ACTIONS:
			assert_false(step.ghost_demos.is_empty(), "%s asks for a drag or click and shows none" % path)
		for demo: GhostDemo in step.ghost_demos:
			assert_true(demo.is_complete(), "%s has a demo missing an end" % path)


## A NODE target is a path into main.tscn; a renamed node would leave the
## ghost hidden for good, so each is checked against the scene, through the
## scenes it instances.
func test_every_node_target_exists_in_the_game_scene() -> void:
	var main: PackedScene = load(MAIN_SCENE)
	var checked: int = 0
	for path: String in _step_paths():
		var step: TutorialStep = load(path)
		for demo: GhostDemo in step.ghost_demos:
			for target: GhostTarget in [demo.at, demo.to]:
				if target and target.kind == GhostTarget.Kind.NODE:
					checked += 1
					assert_true(_scene_has(main, str(target.node_path)),
						"%s: no %s in main.tscn" % [path, target.node_path])
	assert_gt(checked, 0)


## Whether [param scene] has a node at [param path], counting the nodes of the
## scenes it instances.
static func _scene_has(scene: PackedScene, path: String) -> bool:
	var state: SceneState = scene.get_state()
	for node: int in state.get_node_count():
		var node_path: String = str(state.get_node_path(node)).trim_prefix("./")
		if node_path == path:
			return true
		var instance: PackedScene = state.get_node_instance(node)
		if instance and path.begins_with(node_path + "/") \
				and _scene_has(instance, path.trim_prefix(node_path + "/")):
			return true
	return false
