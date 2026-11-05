class_name ShipHull
extends Node2D
## The body of a ship made of separately targetable parts (see
## ShipHullResource). It can't be shot and never acts; EnemyManager carries the
## mounted parts along with it, so the whole ship arrives, bobs and leaves as
## one. Each socket whose part is destroyed is left scarred, and once the last
## part goes the hull breaks up.

## Sprite or scene that bobs; parts follow its offset, not the hull's origin.
@export var body: Node2D
## Left where a destroyed part was.
@export var scar_texture: Texture2D
@export var explosion_scene: PackedScene

@export var bob_height: float = 2.0
@export var bob_period: float = 3.2

## How many blasts the breakup chains across the hull, and how far apart.
@export var breakup_blasts: int = 6
@export var breakup_spread: Vector2 = Vector2(90, 18)

## The bob as it stands this frame. Mounted parts add it to their offset.
var bob: Vector2 = Vector2.ZERO

var _clock: float = 0.0
var _breaking_up: bool = false


func _process(delta: float) -> void:
	_clock += delta
	bob = Vector2(0.0, sin(_clock * TAU / bob_period) * bob_height)
	body.position = bob


## Where a part mounted at [param offset] stands right now.
func mount_position(offset: Vector2) -> Vector2:
	return position + bob + offset


## A part's socket is empty now. A quiet scar is one that was already there,
## for a Continue that restores a hull missing some of its parts.
func scar(offset: Vector2, quiet: bool = false) -> void:
	var crater: Sprite2D = Sprite2D.new()
	crater.texture = scar_texture
	crater.position = offset
	body.add_child(crater)
	# Wrecked sockets keep venting, including those restored by Continue.
	var smoke: ShipDamageSmoke = ShipDamageSmoke.attach(crater)
	for plume: CPUParticles2D in smoke.get_children():
		plume.amount = 36
		plume.lifetime = 1.8
		plume.scale_amount_min = 2.0
		plume.scale_amount_max = 4.0
	smoke.set_hull_fraction(0.0)
	if quiet:
		return
	Juice.sparkle(get_parent(), global_position + bob + offset, Globals.orange, 14, 50.0)
	Juice.ring(get_parent(), global_position + bob + offset, Globals.red, 28.0, 0.4, 4.0)


## The last part is gone. Blasts chain across the hull, then it drifts, tumbles, dissolves and fades out.
func break_up() -> void:
	if _breaking_up:
		return
	_breaking_up = true
	set_process(false)
	Events.camera_shake_large.emit(false)
	for i: int in range(breakup_blasts):
		var spot: Vector2 = Vector2(
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -breakup_spread.x, breakup_spread.x),
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -breakup_spread.y, breakup_spread.y)
		)
		_blast(global_position + bob + spot)
		Juice.sparkle(get_parent(), global_position + bob + spot, Globals.orange, 6, 30.0)
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree():
			return

	Juice.ring(get_parent(), global_position + bob, Globals.white, 120.0, 0.6, 12.0)
	Events.camera_shake_large.emit(true)
	for s: int in range(5):
		var spark_spot: Vector2 = Vector2(
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -breakup_spread.x, breakup_spread.x),
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -breakup_spread.y, breakup_spread.y)
		)
		Juice.sparkle(get_parent(), global_position + bob + spark_spot, Globals.orange, 8, 40.0)
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(self, "position", position + Vector2(0, 16), 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(self, "rotation", 0.05, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(self, "modulate:a", 0.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fade.finished
	queue_free()


func _blast(at: Vector2) -> void:
	if explosion_scene == null:
		return
	var blast: Node2D = explosion_scene.instantiate()
	get_parent().add_child(blast)
	# The explosion scene frees itself once it has played.
	blast.global_position = at
