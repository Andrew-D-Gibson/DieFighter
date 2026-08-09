extends Control

@export var num_of_stars: int = 100
@export var num_of_twinkling_stars: int = 25
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

var _screen_size: Vector2 = Vector2(320, 180)
var _stars: Array[Node2D]


func _ready() -> void:
	# Create new stars
	for i in range(num_of_stars):
		_add_star(star_pixel_scene)

	for i in range(num_of_twinkling_stars):
		_add_star(star_twinkle_scene)


func _add_star(star_scene: PackedScene) -> void:
	var star = star_scene.instantiate()
	star.z_index = -2
	add_child(star)
	star.global_position = Vector2(
		RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 0, _screen_size.x),
		RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 0, (_screen_size.y * 2)) - 180
	)

	# Randomize the opacity of the star to simulate brightness/distance
	star.modulate = Color(1, 1, 1, RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.25, 0.75))
	
	_stars.append(star)
