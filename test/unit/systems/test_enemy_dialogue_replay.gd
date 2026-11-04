extends "res://test/helpers/die_fighter_test.gd"
## EnemyDialogueManager remembers its last line so the targeting computer's
## comms button can have the ship say it again.

const _SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyDialogueManager/enemy_dialogue_manager.tscn")


func _manager() -> EnemyDialogueManager:
	var manager: EnemyDialogueManager = _SCENE.instantiate()
	add_child_autofree(manager)
	# Lines from an earlier test mustn't make this one wait its turn.
	EnemyDialogueManager.time_last_dialogue_was_shown = 0
	return manager


func test_a_ship_that_has_said_nothing_has_nothing_to_replay() -> void:
	assert_false(_manager().has_line_to_replay())


func test_a_line_can_be_replayed_and_is_shown_again() -> void:
	var manager := _manager()
	manager.show_dialogue("Our kill. Back off!")
	manager.hide()
	watch_signals(manager)
	manager.replay_last_line()
	assert_true(manager.has_line_to_replay())
	assert_signal_emitted(manager, "line_shown")
	assert_true(manager.visible)
	assert_eq(manager.get_node("%RichTextLabel").text, "Our kill. Back off!")


func test_clearing_the_box_keeps_the_last_real_line() -> void:
	var manager := _manager()
	manager.show_dialogue("Hold fire!")
	manager.show_dialogue("")
	assert_true(manager.has_line_to_replay())


func test_a_ship_left_behind_in_a_jump_has_nothing_more_to_say() -> void:
	var manager := _manager()
	manager.show_dialogue("Hold fire!")
	manager._on_jump()
	assert_false(manager.has_line_to_replay())


func test_three_dialogue_boxes_stay_separate_and_on_screen() -> void:
	var managers: Array[EnemyDialogueManager] = []
	for x: float in [100.1, 145.3, 296.7]:
		var host: Node2D = add_child_autofree(Node2D.new())
		host.position = Vector2(x, 35.297245)
		var manager: EnemyDialogueManager = _SCENE.instantiate()
		host.add_child(manager)
		manager.show_dialogue("Hold fire!", ScenarioManager.Faction.PIRATE, false)
		managers.append(manager)
	await wait_physics_frames(3)
	var boxes: Array[Rect2] = []
	for manager: EnemyDialogueManager in managers:
		var sprite: Sprite2D = manager.get_node("Sprite2D")
		var box: Rect2 = Rect2(sprite.global_position - sprite.texture.get_size() * 0.5,
			sprite.texture.get_size())
		assert_gte(box.position.x, 4.0)
		assert_gte(box.position.y, 4.0)
		assert_lte(box.end.x, Globals.SCREEN_SIZE.x - 4.0)
		assert_lte(box.end.y, Globals.SCREEN_SIZE.y - 4.0)
		for earlier: Rect2 in boxes:
			assert_false(box.intersects(earlier), "speech boxes do not overlap")
		boxes.append(box)


func test_dialogue_box_clamps_to_stay_on_screen() -> void:
	var enemy: Node2D = Node2D.new()
	enemy.global_position = Vector2(160, 20)
	add_child_autofree(enemy)
	var manager: EnemyDialogueManager = _SCENE.instantiate()
	manager.anchor = Vector2(0, -20)
	enemy.add_child(manager)
	var box_sprite: Sprite2D = manager.get_node("%Sprite2D")
	var half_h: float = box_sprite.texture.get_height() * 0.5
	var global_top: float = manager.global_position.y + box_sprite.position.y - half_h
	assert_gte(global_top, EnemyDialogueManager._TOP_SCREEN_MARGIN - 0.01)
