extends "res://test/helpers/die_fighter_test.gd"
## HullInfoArt: the hull info panel's picture follows the hull instead of
## showing one fixed state.

## The hand-drawn picture the panel used to show, which read 15/20. The built
## picture has to reproduce it exactly, so layout stays the artist's.
const ORIGINAL_15_OF_20: Texture2D = preload("res://Assets/Textures/Player/PlayerHealthBar/hull_info.png")
const RING: Texture2D = preload("res://Assets/Textures/Player/PlayerHealthBar/hull_info_ring.png")
const HULL_RED: Color = Color("d03656")


func _ring_pixels() -> Array[Vector2i]:
	var ring: Image = RING.get_image()
	var pixels: Array[Vector2i] = []
	for y: int in range(ring.get_height()):
		for x: int in range(ring.get_width()):
			if ring.get_pixel(x, y).a > 0.0:
				pixels.append(Vector2i(x, y))
	return pixels


func _lit_count(image: Image) -> int:
	var lit: int = 0
	for pixel: Vector2i in _ring_pixels():
		if image.get_pixelv(pixel).is_equal_approx(HULL_RED):
			lit += 1
	return lit


func test_fifteen_of_twenty_matches_the_hand_drawn_art() -> void:
	var built: Image = HullInfoArt.compose(15, 20)
	var original: Image = ORIGINAL_15_OF_20.get_image()
	original.convert(Image.FORMAT_RGBA8)
	assert_eq(built.get_size(), original.get_size())
	var mismatches: int = 0
	for y: int in range(original.get_height()):
		for x: int in range(original.get_width()):
			var want: Color = original.get_pixel(x, y)
			var got: Color = built.get_pixel(x, y)
			# Clear is clear, whatever colour a transparent pixel carries.
			if want.a == 0.0 and got.a == 0.0:
				continue
			if not got.is_equal_approx(want):
				mismatches += 1
	assert_eq(mismatches, 0, "pixels that differ from the original 15/20 art")


func test_the_ring_follows_the_hull() -> void:
	var ring_size: int = _ring_pixels().size()
	assert_eq(_lit_count(HullInfoArt.compose(20, 20)), ring_size, "full hull lights the whole ring")
	assert_eq(_lit_count(HullInfoArt.compose(0, 20)), 0, "no hull lights none of it")
	var half: int = _lit_count(HullInfoArt.compose(10, 20))
	assert_almost_eq(float(half), ring_size / 2.0, 4.0)
	assert_gt(_lit_count(HullInfoArt.compose(11, 20)), half)


func test_the_fill_stays_on_the_ring() -> void:
	assert_eq(HullInfoArt.fill_fraction(30, 20), 1.0)
	assert_eq(HullInfoArt.fill_fraction(-4, 20), 0.0)
	assert_eq(HullInfoArt.fill_fraction(5, 0), 0.0)


func test_the_count_reads_the_hull() -> void:
	assert_eq(HullInfoArt.count_text(12, 20), "12/20")
	assert_eq(HullInfoArt.count_text(-3, 20), "0/20")
	assert_eq(HullInfoArt.count_text(99, 99), "99/99")
	# Too wide to sit inside the ring with its maximum: the hull alone.
	assert_eq(HullInfoArt.count_text(123, 150), "123")


## Every digit has a glyph, so any count draws (the composed count row isn't
## left blank anywhere a digit should be).
func test_every_digit_draws() -> void:
	for digit: int in range(10):
		var text: String = "%d%d/%d%d" % [digit, digit, digit, digit]
		var image: Image = HullInfoArt.compose(digit * 11, digit * 11)
		var ink: int = 0
		for y: int in range(19, 25):
			for x: int in range(6, 30):
				if image.get_pixel(x, y).is_equal_approx(HULL_RED):
					ink += 1
		assert_gt(ink, 4, "count %s drew nothing" % text)
