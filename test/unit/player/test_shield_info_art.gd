extends "res://test/helpers/die_fighter_test.gd"
## ShieldInfoArt: the shield info panel's picture shows the shields as they
## stand instead of a fixed 10.

## The hand-drawn picture the panel used to show, which read 10.
const ORIGINAL_10: Texture2D = preload("res://Assets/Textures/Player/PlayerHealthBar/shield_info.png")
const SHIELD_BLUE: Color = Color("43a6fc")
## Inside the small bubble, round where the count is drawn.
const COUNT_AREA: Rect2i = Rect2i(9, 39, 14, 9)


func _count_pixels(image: Image) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	for y: int in range(COUNT_AREA.position.y, COUNT_AREA.end.y):
		for x: int in range(COUNT_AREA.position.x, COUNT_AREA.end.x):
			if image.get_pixel(x, y).is_equal_approx(SHIELD_BLUE):
				pixels.append(Vector2i(x, y))
	return pixels


func test_only_the_count_differs_from_the_hand_drawn_art() -> void:
	var original: Image = ORIGINAL_10.get_image()
	original.convert(Image.FORMAT_RGBA8)
	var built: Image = ShieldInfoArt.compose(37)
	assert_eq(built.get_size(), original.get_size())
	var mismatches: int = 0
	for y: int in range(original.get_height()):
		for x: int in range(original.get_width()):
			if COUNT_AREA.has_point(Vector2i(x, y)):
				continue
			var want: Color = original.get_pixel(x, y)
			var got: Color = built.get_pixel(x, y)
			if want.a == 0.0 and got.a == 0.0:
				continue
			if not got.is_equal_approx(want):
				mismatches += 1
	assert_eq(mismatches, 0, "pixels outside the count that differ from the original art")


func test_the_count_follows_the_shields() -> void:
	var seven: Array[Vector2i] = _count_pixels(ShieldInfoArt.compose(7))
	var twelve: Array[Vector2i] = _count_pixels(ShieldInfoArt.compose(12))
	assert_gt(seven.size(), 0, "a count is drawn")
	assert_ne(seven, twelve, "different shields draw different counts")
	assert_eq(_count_pixels(ShieldInfoArt.compose(-3)), _count_pixels(ShieldInfoArt.compose(0)),
		"shields below zero read 0")


func test_a_three_digit_count_stays_inside_the_bubble() -> void:
	var image: Image = ShieldInfoArt.compose(888)
	var inside: int = _count_pixels(image).size()
	var blank: int = _count_pixels(ShieldInfoArt.compose(0)).size()
	assert_gt(inside, blank, "every digit lands in the count area")
	# The bubble's dark middle still rings the count on both sides.
	for y: int in range(40, 46):
		assert_eq(image.get_pixel(COUNT_AREA.position.x, y), Color("040217"), "left clearance, row %d" % y)
		assert_eq(image.get_pixel(COUNT_AREA.end.x - 1, y), Color("040217"), "right clearance, row %d" % y)
