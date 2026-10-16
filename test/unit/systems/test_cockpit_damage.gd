extends "res://test/helpers/die_fighter_test.gd"
## CockpitDamage: how many breaks show at a given hull. Spread evenly, so a
## full hull shows none, any damage at all starts showing them, and only zero
## hull shows every one.


func test_full_hull_shows_no_damage() -> void:
	assert_eq(CockpitDamage.sites_open_at(32, 32, 9), 0)


func test_zero_hull_shows_every_break() -> void:
	assert_eq(CockpitDamage.sites_open_at(0, 32, 9), 9)


func test_breaks_open_evenly_as_hull_drops() -> void:
	# Nine sites over 32 hull: one per tenth of the bar lost.
	assert_eq(CockpitDamage.sites_open_at(29, 32, 9), 0)
	assert_eq(CockpitDamage.sites_open_at(28, 32, 9), 1)
	assert_eq(CockpitDamage.sites_open_at(16, 32, 9), 5)
	assert_eq(CockpitDamage.sites_open_at(1, 32, 9), 9)


func test_count_never_falls_as_hull_drops() -> void:
	var previous: int = 0
	for hull: int in range(40, -1, -1):
		var open: int = CockpitDamage.sites_open_at(hull, 40, 9)
		assert_true(open >= previous, "hull %d opened fewer breaks than %d" % [hull, hull + 1])
		previous = open


func test_no_max_hull_shows_nothing() -> void:
	assert_eq(CockpitDamage.sites_open_at(0, 0, 9), 0)


# --- Smoke ---

func _damage() -> CockpitDamage:
	return autofree(CockpitDamage.new())


func test_small_hit_at_full_hull_billows_gently() -> void:
	# Right on the big-hit line, with plenty of hull left. Read from the
	# exports so tuning the line doesn't break the test.
	var damage: CockpitDamage = _damage()
	var lost: int = ceili(damage.big_hit_fraction * 100.0)
	assert_almost_eq(damage.billow_intensity(lost, 100 - lost, 100), 0.0, 0.05)


func test_bigger_hits_billow_harder() -> void:
	var damage: CockpitDamage = _damage()
	var previous: float = -1.0
	for lost: int in range(5, 17):
		var intensity: float = damage.billow_intensity(lost, 30, 40)
		assert_true(intensity >= previous, "a %d hull hit billowed less than a smaller one" % lost)
		previous = intensity


func test_the_same_hit_billows_harder_near_the_end() -> void:
	var damage: CockpitDamage = _damage()
	assert_gt(damage.billow_intensity(6, 4, 40), damage.billow_intensity(6, 30, 40))


func test_a_huge_hit_at_zero_billows_flat_out() -> void:
	assert_almost_eq(_damage().billow_intensity(20, 0, 40), 1.0, 0.001)


# --- Cracks on death ---

func test_cracks_come_back_faster_and_faster() -> void:
	var previous_time: float = -1.0
	var previous_gap: float = INF
	for i: int in 5:
		var at: float = CockpitDestruction.crack_return_at(i, 5)
		if i > 0:
			var gap: float = at - previous_time
			assert_true(gap <= previous_gap, "crack %d came back after a longer gap" % i)
			previous_gap = gap
		previous_time = at


func test_last_crack_lands_inside_the_rupture() -> void:
	assert_lt(CockpitDestruction.crack_return_at(4, 5), 1.0)
	assert_gt(CockpitDestruction.crack_return_at(0, 5), 0.0)


# --- Glass shards ---

## Shards over a fake cockpit: open glass, with a ledge filling row 50 down.
func _shards_over_ledge() -> CockpitGlassShards:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 50, 64, 14), Color.WHITE)
	var walls: Sprite2D = Sprite2D.new()
	walls.centered = false
	walls.texture = ImageTexture.create_from_image(image)
	add_child_autofree(walls)
	var shards: CockpitGlassShards = CockpitGlassShards.new()
	add_child_autofree(shards)
	shards.set_walls(walls)
	return shards


func _step(shards: CockpitGlassShards, seconds: float) -> void:
	for i: int in roundi(seconds * 60.0):
		shards._process(1.0 / 60.0)


func test_shards_land_on_the_ledge_below() -> void:
	var shards: CockpitGlassShards = _shards_over_ledge()
	shards.rest_time = Vector2(10.0, 10.0)
	shards.spill(Vector2(32, 10), 6)
	_step(shards, 2.0)
	assert_eq(shards.get_shard_count(), 6, "every shard should still be lying on the ledge")
	for shard: CockpitGlassShards.Shard in shards._shards:
		assert_eq(shard.state, CockpitGlassShards.State.RESTING)
		assert_almost_eq(shard.position.y, 48.5, 0.01)


func test_landed_shards_fade_away() -> void:
	var shards: CockpitGlassShards = _shards_over_ledge()
	shards.rest_time = Vector2(0.5, 0.5)
	shards.spill(Vector2(32, 10), 4)
	_step(shards, 4.0)
	assert_eq(shards.get_shard_count(), 0)


func test_shards_starting_inside_the_shell_fall_clear_of_it() -> void:
	# A crack at the canopy's edge: the shard begins on solid shell and must
	# not land on the very pixel it started in.
	var shards: CockpitGlassShards = _shards_over_ledge()
	shards.spill(Vector2(32, 55), 3)
	_step(shards, 2.0)
	assert_eq(shards.get_shard_count(), 0, "shards should drop out of the bottom")


func test_shards_land_on_a_panel_in_front_of_the_shell() -> void:
	var shards: CockpitGlassShards = _shards_over_ledge()
	shards.rest_time = Vector2(10.0, 10.0)
	var image: Image = Image.create(20, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var panel: Sprite2D = Sprite2D.new()
	panel.texture = ImageTexture.create_from_image(image)
	panel.position = Vector2(32, 35)  # Centred: its top edge is row 30.
	panel.add_to_group(CockpitGlassShards.SURFACE_GROUP)
	add_child_autofree(panel)
	shards.spill(Vector2(32, 10), 1, 0.0)
	_step(shards, 2.0)
	assert_almost_eq(shards._shards[0].position.y, 28.5, 0.01)


func test_a_shard_falls_again_when_its_panel_goes() -> void:
	var shards: CockpitGlassShards = _shards_over_ledge()
	shards.rest_time = Vector2(10.0, 10.0)
	var image: Image = Image.create(20, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var panel: Sprite2D = Sprite2D.new()
	panel.texture = ImageTexture.create_from_image(image)
	panel.position = Vector2(32, 35)
	panel.add_to_group(CockpitGlassShards.SURFACE_GROUP)
	add_child_autofree(panel)
	shards.spill(Vector2(32, 10), 1, 0.0)
	_step(shards, 2.0)
	panel.hide()
	_step(shards, 2.0)
	assert_almost_eq(shards._shards[0].position.y, 48.5, 0.01, "should end up on the ledge below")


func test_blown_glass_lands_on_nothing() -> void:
	var shards: CockpitGlassShards = _shards_over_ledge()
	shards.rest_time = Vector2(10.0, 10.0)
	shards.spill(Vector2(32, 10), 4)
	_step(shards, 2.0)
	var points: Array[Vector2] = [Vector2(20, 20)]
	shards.blow_away(Vector2(32, 60), points, 2)
	_step(shards, 3.0)
	assert_eq(shards.get_shard_count(), 0)
