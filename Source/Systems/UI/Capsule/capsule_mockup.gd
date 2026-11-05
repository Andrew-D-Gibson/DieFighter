extends Control
## The store capsule's scene (planet_mockup.tscn), staged for capture.

@export var num_of_stars: int = 100
@export var num_of_twinkling_stars: int = 25
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

## Matches the main menu's sky. Whole pixels, so the stars stay crisp in a
## 1x capture.
const _STAR_AREA: Rect2 = Rect2(0, -180, 320, 360)


func _ready() -> void:
	StarScatter.scatter(self, star_pixel_scene, num_of_stars, _STAR_AREA, true)
	StarScatter.scatter(self, star_twinkle_scene, num_of_twinkling_stars, _STAR_AREA, true)
