class_name ArrivalStarfield
extends Node2D
## The sky with no Fate in it (RECKONING_ENDINGS.md §6): the first sky in the
## game with no black hole. Fewer stars than any sky the run crossed, a few of
## them in faint colours the player hasn't seen up there, and no purple
## anywhere. "Off the table" is planning shorthand; there is no table here.
##
## Lives on the 1080p star layer, as the first ending's stars do, so the stars
## glide rather than step; positions are in art pixels.

@export var num_of_stars: int = 70
@export var num_of_twinkling_stars: int = 12
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

## How fast the stars stream past, in art pixels per second: next to nothing
## while the ships hold station, picking up as the convoy sets off.
var speed: float = 1.0

## The few stars that aren't white: the palette's cyan, orange, green and
## bone. Nothing blue-violet, nothing purple: that was Fate's sky.
const _UNFAMILIAR: Array[Color] = [Color("#8df1f4"), Color("#f29c5d"), Color("#7abd33"), Color("#c4c1bc")]
## One star in this many takes one of those colours.
const _TINTED_EVERY: int = 6

var _stars: Array[Node2D] = []
var _depths: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	for i: int in range(num_of_stars + num_of_twinkling_stars):
		var scene: PackedScene = star_pixel_scene if i < num_of_stars else star_twinkle_scene
		var star: Node2D = scene.instantiate()
		add_child(star)
		star.position = Vector2(_randf(0, Globals.SCREEN_SIZE.x), _randf(0, Globals.SCREEN_SIZE.y))
		var depth: float = _randf(0.25, 1.0)
		var tint: Color = Color("#cef0f1")
		if i % _TINTED_EVERY == 0:
			tint = _UNFAMILIAR[(i / _TINTED_EVERY) % _UNFAMILIAR.size()]
		# Dimmer than the run's skies: a quieter place.
		star.modulate = Color(tint, lerpf(0.18, 0.65, depth))
		_stars.append(star)
		_depths.append(depth)


func _process(delta: float) -> void:
	for i: int in range(_stars.size()):
		var star: Node2D = _stars[i]
		star.position.x -= speed * _depths[i] * delta
		if star.position.x < -1.0:
			star.position.x = Globals.SCREEN_SIZE.x + 1.0
			star.position.y = _randf(0, Globals.SCREEN_SIZE.y)


## Where a near, bright star is, for a twinkle the shot calls for. Picked away
## from [param avoid] and the edges, so it isn't lost behind a ship.
func bright_star_point(avoid: Vector2, clearance: float = 40.0) -> Vector2:
	var best: Vector2 = Vector2(60, 40)
	var best_depth: float = -1.0
	for i: int in range(_stars.size()):
		var at: Vector2 = _stars[i].position
		if at.distance_to(avoid) < clearance or not Rect2(12, 12, 296, 156).has_point(at):
			continue
		var depth: float = _depths[i] + _randf(0.0, 0.3)
		if depth > best_depth:
			best_depth = depth
			best = at
	return best.round()


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
