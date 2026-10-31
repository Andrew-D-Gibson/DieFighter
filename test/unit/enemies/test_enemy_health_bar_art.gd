extends "res://test/helpers/die_fighter_test.gd"
## EnemyHealthBar's REACH constants space the formation, so they have to
## match the bar's art: the attitude outline around the backing is the widest
## thing the bar draws.

const BAR_SCENE: PackedScene = preload("res://Source/Content/Enemies/Components/EnemyHealthBar/enemy_health_bar.tscn")


func test_reach_matches_the_outline_art() -> void:
	var bar: EnemyHealthBar = BAR_SCENE.instantiate()
	autofree(bar)
	var outline: Sprite2D = bar.get_node("Outline")
	var half_width: float = outline.texture.get_width() / 2.0
	assert_true(outline.centered)
	assert_eq(EnemyHealthBar.REACH_LEFT, half_width - outline.position.x)
	assert_eq(EnemyHealthBar.REACH_RIGHT, half_width + outline.position.x)


func test_the_backing_sits_inside_the_outline() -> void:
	var bar: EnemyHealthBar = BAR_SCENE.instantiate()
	autofree(bar)
	var outline: Sprite2D = bar.get_node("Outline")
	var backing: Sprite2D = bar.get_node("Background")
	assert_eq(backing.position, outline.position)
	assert_true(backing.texture.get_width() <= outline.texture.get_width())


func test_the_attitude_lives_on_the_targeting_computer_now() -> void:
	var bar: EnemyHealthBar = BAR_SCENE.instantiate()
	autofree(bar)
	assert_null(bar.get_node_or_null("AttitudeIndicator"))
