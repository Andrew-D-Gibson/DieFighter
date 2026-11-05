class_name StarScatter
extends RefCounted
## A still starfield: stars strewn at random over a rectangle, each dimmed to
## its own brightness so they read as near and far. For backdrops that don't
## move (the main menu, the store capsule mockup). BackgroundManager and the
## opening cutscene give every star a depth and stream it past, so they spawn
## their own.


## Adds [param count] of [param star_scene] to [param parent], scattered over
## [param area] (global coordinates), and returns them. [param whole_pixels]
## keeps every star on the pixel grid, for art that's captured at 1x.
static func scatter(
	parent: Node,
	star_scene: PackedScene,
	count: int,
	area: Rect2,
	whole_pixels: bool = false,
	z_index: int = -2
) -> Array[Node2D]:
	var stars: Array[Node2D] = []
	for i: int in range(count):
		var star: Node2D = star_scene.instantiate()
		star.z_index = z_index
		parent.add_child(star)
		star.global_position = _random_point(area, whole_pixels)
		star.modulate = Color(1, 1, 1, RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.25, 0.75))
		stars.append(star)
	return stars


static func _random_point(area: Rect2, whole_pixels: bool) -> Vector2:
	if whole_pixels:
		return Vector2(
			RNGManager.randi_range(RNGManager.Bucket.COSMETIC, int(area.position.x), int(area.end.x)),
			RNGManager.randi_range(RNGManager.Bucket.COSMETIC, int(area.position.y), int(area.end.y))
		)
	return Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, area.position.x, area.end.x),
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, area.position.y, area.end.y)
	)
