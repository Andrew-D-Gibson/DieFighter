extends "res://test/helpers/die_fighter_test.gd"
## The soft outline around every ship's health bar says how that ship feels
## about the player at a glance: green friendly, grey neutral, red hostile,
## the targeting computer's own colours, and it follows a ship that changes
## sides.

const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const OUTLINE_MASK: Texture2D = preload("res://Assets/Textures/Enemies/EnemyHealthBar/bar_outline.png")

## The approved palette's light steps.
const GREEN: Color = Color("7abd33")
const GREY: Color = Color("c4c1bc")
const RED: Color = Color("d03656")


func _state(attitude: Enemy.Attitude) -> ScenarioShipState:
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.CIVILIAN
	state.attitude = attitude
	return state


func _ship(attitude: Enemy.Attitude) -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	ship.scenario_state = _state(attitude)
	# A bare test has no save to scale hull by; the ship asks as it readies.
	var state_manager: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(ship)
	Globals.state_manager = state_manager
	return ship


func _outline_of(ship: Enemy) -> Sprite2D:
	return ship.graphics_manager.health_bar.get_node("%Outline")


func _rgb(colour: Color) -> Color:
	return Color(colour.r, colour.g, colour.b)


func test_each_attitude_has_its_palette_colour() -> void:
	var expected: Dictionary[Enemy.Attitude, Color] = {
		Enemy.Attitude.FRIENDLY: GREEN,
		Enemy.Attitude.NEUTRAL: GREY,
		Enemy.Attitude.AGGRESSIVE: RED,
	}
	for attitude: Enemy.Attitude in expected:
		var ship: Enemy = _ship(attitude)
		assert_eq(_rgb(_outline_of(ship).modulate), expected[attitude], Enemy.Attitude.find_key(attitude))


func test_the_outline_stays_a_soft_edge() -> void:
	var outline: Sprite2D = _outline_of(_ship(Enemy.Attitude.AGGRESSIVE))
	assert_true(outline.modulate.a > 0.0 and outline.modulate.a < 1.0)


func test_it_matches_the_targeting_computer() -> void:
	for attitude: Enemy.Attitude in [Enemy.Attitude.FRIENDLY, Enemy.Attitude.NEUTRAL, Enemy.Attitude.AGGRESSIVE]:
		assert_eq(AttitudeDisplay.attitude_colour(attitude), AttitudeDisplay.bezel_colour(attitude))


func test_a_ship_turning_hostile_turns_red_at_once() -> void:
	var ship: Enemy = _ship(Enemy.Attitude.NEUTRAL)
	assert_eq(_rgb(_outline_of(ship).modulate), GREY)
	ship.force_scenario_state(_state(Enemy.Attitude.AGGRESSIVE))
	assert_eq(_rgb(_outline_of(ship).modulate), RED)


func test_a_raider_standing_down_turns_green() -> void:
	var ship: Enemy = _ship(Enemy.Attitude.AGGRESSIVE)
	ship.force_scenario_state(_state(Enemy.Attitude.FRIENDLY))
	assert_eq(_rgb(_outline_of(ship).modulate), GREEN)


func test_any_new_state_recolours_it_not_only_scenario_events() -> void:
	# A save restore assigns the state straight in.
	var ship: Enemy = _ship(Enemy.Attitude.FRIENDLY)
	ship.scenario_state = _state(Enemy.Attitude.AGGRESSIVE)
	assert_eq(_rgb(_outline_of(ship).modulate), RED)


func test_a_change_of_sides_blinks_but_the_first_colouring_does_not() -> void:
	var ship: Enemy = _ship(Enemy.Attitude.NEUTRAL)
	var bar: EnemyHealthBar = ship.graphics_manager.health_bar
	assert_null(bar._blink_tween, "a fresh ship just shows its colour")
	ship.force_scenario_state(_state(Enemy.Attitude.AGGRESSIVE))
	assert_not_null(bar._blink_tween)
	await wait_seconds(1.0)
	assert_true(bar.get_node("%Outline").visible, "lit again once the blink is over")


func test_the_outline_art_is_a_white_mask_for_tinting() -> void:
	var image: Image = OUTLINE_MASK.get_image()
	var opaque: int = 0
	var tinted: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a == 0.0:
				continue
			opaque += 1
			if Color(pixel.r, pixel.g, pixel.b) != Color.WHITE:
				tinted += 1
	assert_gt(opaque, 0)
	assert_eq(tinted, 0, "the colour comes from the attitude, not the art")
