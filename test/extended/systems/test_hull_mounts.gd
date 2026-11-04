extends "res://test/helpers/die_fighter_test.gd"
## A ship built from parts: the hull holds its stretch of the formation, its
## parts ride it, and it breaks up once the last part is gone.

const HULL_SCENE: PackedScene = preload("res://Source/Content/Enemies/ShipHull/bastion_hull.tscn")
const ENEMY_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyManager/enemy_manager.tscn")
const BASTION: ScenarioResource = preload("res://Source/Content/ScenarioResources/Scenarios/GATE_Bastion/GATE_bastion.tres")

var formation: EnemyFormation
var mounts: HullMounts
var parent: Node2D


func before_each() -> void:
	super()
	formation = EnemyFormation.new()
	mounts = HullMounts.new(formation)
	parent = add_child_autofree(Node2D.new())


func _spec() -> ShipHullResource:
	var spec: ShipHullResource = ShipHullResource.new()
	spec.hull_scene = HULL_SCENE
	spec.width = 100.0
	return spec


func _part(offset: Vector2) -> Enemy:
	var part: Enemy = autofree(Enemy.new())
	mounts.mount(part, offset)
	return part


func _build(roster: Array[Enemy], starting: Array[EnemyStateRewardResource] = []) -> void:
	mounts.build(_spec(), parent, Vector2(160, 40), 160.0, 100.0, starting, roster)


func test_the_hull_holds_its_width_of_the_formation_and_seats_its_parts() -> void:
	var part: Enemy = _part(Vector2(20, 0))
	_build([part] as Array[Enemy])

	assert_true(mounts.has_hull())
	assert_eq(formation.get_free_stretches().size(), 2, "the hull splits the free span")
	assert_true(formation.has_reservation(EnemyFormation.ship_key(part)))
	assert_almost_eq(part.position.x, 180.0, 0.01)
	assert_almost_eq(part.position.y, -60.0, 2.1, "seated on a hull still waiting to fly in")


func test_losing_the_last_part_breaks_up_the_hull_and_frees_its_space() -> void:
	var left: Enemy = _part(Vector2(-20, 0))
	var right: Enemy = _part(Vector2(20, 0))
	_build([left, right] as Array[Enemy])

	mounts.unmount(left, false)
	assert_true(mounts.has_hull())
	mounts.unmount(right, false)
	assert_false(mounts.has_hull())
	assert_eq(formation.get_free_stretches(), [formation.usable_span] as Array[Vector2])


func test_a_part_lost_mid_jump_leaves_the_hull_to_fall_away() -> void:
	var part: Enemy = _part(Vector2.ZERO)
	_build([part] as Array[Enemy])
	mounts.unmount(part, true)
	assert_true(mounts.has_hull())


func test_a_continue_drops_parts_that_were_already_gone() -> void:
	var survivor: Enemy = _part(Vector2(-20, 0))
	var gone: Enemy = _part(Vector2(20, 0))
	_build([survivor] as Array[Enemy])
	assert_true(mounts.is_mounted(survivor))
	assert_false(mounts.is_mounted(gone))


func test_no_hull_scene_means_no_hull_and_no_mounts() -> void:
	var part: Enemy = _part(Vector2.ZERO)
	mounts.build(null, parent, Vector2.ZERO, 160.0, 0.0, [], [part] as Array[Enemy])
	assert_false(mounts.has_hull())
	assert_false(mounts.is_mounted(part))


# ── Through EnemyManager ──────────────────────────────────────────────────────


func test_the_bastion_flies_in_whole_and_breaks_up_with_its_last_part() -> void:
	var manager: EnemyManager = add_child_autofree(ENEMY_MANAGER_SCENE.instantiate())
	Events.load_scenario.emit(BASTION)
	var parts: Array[Enemy] = manager.enemies.duplicate()
	assert_eq(parts.size(), 3)
	assert_true(manager.formation.has_reservation(&"hull"))

	await manager.start_enemy_fly_in()
	for part: Enemy in parts:
		assert_eq(part.turn_actions.size(), EnemyActionSelector.SLOT_COUNT)

	for part: Enemy in parts:
		part.health.take_damage(10000)
	assert_true(manager.enemies.is_empty())
	assert_false(manager.formation.has_reservation(&"hull"), "the hull broke up")
	assert_eq(manager.formation.get_free_stretches(), [manager.formation.usable_span] as Array[Vector2])
