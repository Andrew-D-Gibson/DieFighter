class_name PointOfLight
extends Node2D
## What is left of a ship far down the hole: one pixel of light, and while it
## is bright a faint cross of Fate's purple round it. Drawn on the art grid.

const _CORE: Color = Color("#cef0f1")
const _HALO: Color = Color("#c552f1")

## 0 gone, 1 as bright as it gets. Over 0.5 it has a halo.
var brightness: float = 0.0:
	set(value):
		if is_equal_approx(value, brightness):
			return
		brightness = value
		queue_redraw()


func _draw() -> void:
	if brightness <= 0.0:
		return
	# Whole pixels, so the light never smears between two.
	var at: Vector2 = (global_position.round() - global_position)
	draw_rect(Rect2(at, Vector2.ONE), Color(_CORE, clampf(brightness * 1.5, 0.0, 1.0)))
	if brightness > 0.5:
		var halo: Color = Color(_HALO, (brightness - 0.5) * 1.2)
		for side: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_rect(Rect2(at + side, Vector2.ONE), halo)


func _process(_delta: float) -> void:
	# It moves with the hull; keep it on the grid as it does.
	if brightness > 0.0:
		queue_redraw()
