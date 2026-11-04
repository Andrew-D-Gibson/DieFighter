extends "res://test/helpers/die_fighter_test.gd"

var advisor: CockpitAdvisor
var health: Health
var ship: Enemy


func before_each() -> void:
	super()
	health = add_child_autofree(Health.new())
	health.max_health = 30
	health.health = 30
	health.shields = 10
	var player: Player = make_player()
	player.health = health
	Globals.player = player
	var scenarios: ScenarioManager = autofree(ScenarioManager.new())
	scenarios.current_scenario = load("res://Source/Content/ScenarioResources/Scenarios/EVENT_DeniableAssets/EVENT_deniable_assets.tres")
	Globals.scenario_manager = scenarios
	ship = autofree(Enemy.new())
	ship.enemy_resource = EnemyResource.new()
	ship.enemy_resource.enemy_name = "Sentinel"
	ship.scenario_state = ScenarioShipState.new()
	ship.scenario_state.dialogue = "Keep your hands off the salvage."
	ship.scenario_state.transitions[ScenarioManager.ScenarioEvent.PLAYER_TOOK_REWARD_TILE] = ScenarioShipState.new()
	var enemies: EnemyManager = autofree(EnemyManager.new())
	enemies.enemies = [ship]
	Globals.enemy_manager = enemies
	var tutorial_parent: Node2D = add_child_autofree(Node2D.new())
	tutorial_parent.position = Vector2(156, 37)
	advisor = CockpitAdvisor.new()
	tutorial_parent.add_child(advisor)


func test_event_cue_opens_a_briefing_of_current_dialogue_and_reactions() -> void:
	assert_eq(advisor.global_position, Vector2(18, 70), "independent of tutorial layout")
	assert_true(advisor._unread)
	advisor._portrait_button.pressed.emit()
	assert_true(advisor._panel.visible)
	assert_false(advisor._unread)
	assert_string_contains(advisor._briefing.text, "Sentinel")
	assert_string_contains(advisor._briefing.text, "Keep your hands off the salvage.")
	assert_string_contains(advisor._briefing.text, tr("ADVISOR_REACT_SALVAGE"))
	ship.scenario_state.dialogue = "You took it."
	Events.ship_scenario_state_changed.emit(ship)
	assert_string_contains(advisor._briefing.text, "You took it.")


func test_damage_severity_and_encounter_win_change_expression() -> void:
	health.change_health(-2)
	Events.player_health_hit.emit()
	assert_eq(advisor._head.frame, 2, "wince for a small hit")
	health.change_health(-8)
	Events.player_health_hit.emit()
	assert_eq(advisor._head.frame, 3, "grimace for a big hit")
	Events.combat_finished.emit()
	assert_eq(advisor._head.frame, 4, "smile after the encounter")
	advisor._process(2.5)
	assert_eq(advisor._head.frame, 0, "settle back to idle")


func test_large_shield_hits_survive_healths_second_clamping_signal() -> void:
	health.change_shields(-8)
	Events.player_shields_hit.emit()
	assert_eq(advisor._head.frame, 3, "grimace for a big shield hit")


func test_spending_shields_does_not_make_the_next_small_hit_look_large() -> void:
	health.change_shields(-7)
	health.change_shields(-1)
	Events.player_shields_hit.emit()
	assert_eq(advisor._head.frame, 2)


func test_back_closes_the_briefing_and_tutorial_finish_reveals_the_advisor() -> void:
	advisor._portrait_button.pressed.emit()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"cursor_back"
	event.pressed = true
	advisor._unhandled_input(event)
	assert_false(advisor._panel.visible)
	advisor.hide()
	Events.tutorial_finished.emit()
	assert_true(advisor.visible)
