extends "res://test/helpers/die_fighter_test.gd"
## ShipWreck: a killed ship's pieces blow up and the wreck reports it's done,
## since the dying Enemy waits on that before freeing itself. A wreck that
## never finished would leave a dead ship in play.

const _EXPLOSION: PackedScene = preload("res://Assets/Particles/enemy_death_explosion.tscn")
const _BLAST_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres")
## The explosion art runs 2.5 s; the wreck's own deadline is a little later.
const _EXPLOSION_SECONDS_MAX: float = 3.0
const _WRECK_SECONDS_MAX: float = 4.5


func _hull() -> Sprite2D:
	var image: Image = Image.create(32, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var hull: Sprite2D = Sprite2D.new()
	hull.texture = ImageTexture.create_from_image(image)
	add_child_autofree(hull)
	return hull


func test_the_explosion_frees_itself_once_it_has_played() -> void:
	var explosion: AnimatedSprite2D = _EXPLOSION.instantiate()
	add_child(explosion)
	await wait_for_signal(explosion.tree_exited, _EXPLOSION_SECONDS_MAX)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(explosion))


func test_a_wreck_finishes_and_frees_itself() -> void:
	var parent: Node2D = add_child_autofree(Node2D.new())
	var wreck: ShipWreck = ShipWreck.shatter(parent, _hull(), Vector2.RIGHT, _EXPLOSION, _BLAST_SFX)
	var done: Array[bool] = [false]
	wreck.finished.connect(func() -> void: done[0] = true)
	await wait_for_signal(wreck.finished, _WRECK_SECONDS_MAX)
	assert_true(done[0])
	await wait_physics_frames(2)
	assert_false(is_instance_valid(wreck))


func test_a_wreck_whose_explosions_never_end_still_finishes() -> void:
	var stuck: AnimatedSprite2D = _EXPLOSION.instantiate()
	stuck.sprite_frames = stuck.sprite_frames.duplicate()
	stuck.sprite_frames.set_animation_loop(&"default", true)
	var looping: PackedScene = PackedScene.new()
	looping.pack(stuck)
	stuck.free()

	var parent: Node2D = add_child_autofree(Node2D.new())
	var wreck: ShipWreck = ShipWreck.shatter(parent, _hull(), Vector2.ZERO, looping, _BLAST_SFX)
	var done: Array[bool] = [false]
	wreck.finished.connect(func() -> void: done[0] = true)
	await wait_seconds(2.5)
	assert_false(done[0], "the looping blasts really are stuck")
	await wait_for_signal(wreck.finished, _WRECK_SECONDS_MAX)
	assert_true(done[0], "the deadline gives up on them")
