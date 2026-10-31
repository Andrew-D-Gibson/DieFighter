extends "res://test/helpers/die_fighter_test.gd"
## ShipDamageSmoke: plumes break out at hull thresholds, from the same spots
## for every ship of a kind, and follow a ship's Health up and down. The
## opening cutscene relies on the spots matching to hand its holed Survivor
## over to the ambush looking the same.

const GRAPHICS := "res://Source/Content/Enemies/EnemyShipGraphicScenes/"
const ATTACKER_GRAPHICS: PackedScene = preload("res://Source/Content/Enemies/EnemyShipGraphicScenes/attacker_ship_graphics.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const ATTACKER: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/attacker.tres")


func _hull(scene: PackedScene = ATTACKER_GRAPHICS) -> Sprite2D:
	var hull: Sprite2D = scene.instantiate()
	add_child_autofree(hull)
	return hull


func _lit(smoke: ShipDamageSmoke) -> int:
	var lit: int = 0
	for plume: Node in smoke.get_children():
		if (plume as CPUParticles2D).emitting:
			lit += 1
	return lit


func test_plumes_break_out_at_each_threshold() -> void:
	assert_eq(ShipDamageSmoke.plume_count(1.0), 0, "a whole hull doesn't smoke")
	assert_eq(ShipDamageSmoke.plume_count(0.76), 0)
	assert_eq(ShipDamageSmoke.plume_count(0.75), 1)
	assert_eq(ShipDamageSmoke.plume_count(0.5), 2)
	assert_eq(ShipDamageSmoke.plume_count(0.25), 3)
	assert_eq(ShipDamageSmoke.plume_count(0.0), 3)


func test_every_ship_of_a_kind_smokes_from_the_same_spots() -> void:
	var first: PackedVector2Array = ShipDamageSmoke.spots_for(_hull())
	var second: PackedVector2Array = ShipDamageSmoke.spots_for(_hull())
	assert_eq(first.size(), ShipDamageSmoke.THRESHOLDS.size())
	assert_eq(first, second)


func test_every_enemy_hull_gets_a_spot_per_threshold_on_its_hull() -> void:
	for file: String in DirAccess.get_files_at(GRAPHICS):
		if not file.ends_with(".tscn"):
			continue
		var hull: Sprite2D = _hull(load(GRAPHICS + file))
		var image: Image = hull.texture.get_image()
		var spots: PackedVector2Array = ShipDamageSmoke.spots_for(hull)
		assert_eq(spots.size(), ShipDamageSmoke.THRESHOLDS.size(), file)
		for spot: Vector2 in spots:
			var pixel: Vector2i = Vector2i((spot + Vector2(image.get_size()) / 2.0).floor())
			assert_gt(image.get_pixelv(pixel).a, 0.5, "%s smokes from %s, off its hull" % [file, spot])


func test_hand_placed_markers_override_the_picked_spots() -> void:
	var hull: Sprite2D = _hull()
	var points: Node2D = Node2D.new()
	points.name = "DamageSmokePoints"
	hull.add_child(points)
	var marker: Marker2D = Marker2D.new()
	marker.position = Vector2(3, -4)
	points.add_child(marker)
	assert_eq(ShipDamageSmoke.spots_for(hull), PackedVector2Array([Vector2(3, -4)]))


func test_plumes_follow_the_hull_down_and_back_up() -> void:
	var smoke: ShipDamageSmoke = ShipDamageSmoke.attach(_hull())
	var health: Health = autofree(Health.new())
	health.max_health = 20
	health.health = 20
	smoke.track(health)
	assert_eq(_lit(smoke), 0)
	health.change_health(-6)
	assert_eq(_lit(smoke), 1, "14/20 is under three quarters")
	health.change_health(-9)
	assert_eq(_lit(smoke), 3, "5/20 is a quarter")
	health.change_health(10)
	assert_eq(_lit(smoke), 1, "repairs put plumes out")


func test_cutscene_survivor_matches_the_ambush_attacker() -> void:
	var ambush: ScenarioResource = load("res://Source/Content/ScenarioResources/Scenarios/COMBAT_OpeningAmbush/COMBAT_opening_ambush.tres")
	var attacker: EnemyStateRewardResource = ambush.starting_enemies[0]
	assert_eq(attacker.enemy_resource.ship_graphics_scene, ATTACKER_GRAPHICS,
		"the cutscene's Survivor is drawn from attacker_ship_graphics.tscn")
	var max_health: int = attacker.enemy_resource.max_health
	var hull: int = Enemy.starting_hull(max_health, attacker.starting_health_fraction)
	assert_gt(ShipDamageSmoke.plume_count(float(hull) / float(max_health)), 0,
		"the ambush's Attacker arrives smoking")


func test_a_dying_ship_puts_its_smoke_out_at_once() -> void:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = ATTACKER
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	add_child_autofree(ship)
	# Its dice go to the survivors on death; there are none.
	Globals.enemy_manager = autofree(EnemyManager.new())
	Globals.enemy_manager.enemies = [ship] as Array[Enemy]
	ship.health.change_health(-ceili(ship.health.max_health * 0.8))
	var smoke: ShipDamageSmoke = ship.graphics_manager.ship_graphics.get_node("DamageSmoke")
	assert_eq(_lit(smoke), ShipDamageSmoke.THRESHOLDS.size(), "a fifth of its hull: every plume")

	ship.health.change_health(-ship.health.health)
	assert_false(smoke.visible, "the haze already in the air goes with it, not just the emitters")
	assert_true(smoke.is_queued_for_deletion())
	assert_eq(_lit(smoke), 0)
	ship.health.change_health(5)
	assert_eq(_lit(smoke), 0, "nothing relights it on the way out")
	assert_false(smoke.visible)
