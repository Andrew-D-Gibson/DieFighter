extends "res://test/helpers/die_fighter_test.gd"
## EngineChargeInfoArt: the Engine Charger's info panel picture shows the drive
## as it stands, the gauge filled to the charge and the count under it.

const TILE_ART: Texture2D = preload("res://Assets/Textures/Tiles/PurpleTiles/engine_charger.png")
const FILL: Texture2D = preload("res://Assets/Textures/MainViewer/EngineCharger/fill.png")
const PURPLE: Color = Color("#c552f1")
## The gauge's column of the picture, between the fill head's overhangs.
const GAUGE_X: int = 36
const GAUGE_TOP: int = 2
const GAUGE_HEIGHT: int = 34
const COUNT_AREA: Rect2i = Rect2i(24, 40, 24, 6)


## How many of the gauge's rows show the fill colour.
func _filled_rows(image: Image) -> int:
	var fill_colour: Color = FILL.get_image().get_pixel(8, 17)
	var rows: int = 0
	for y: int in range(GAUGE_TOP, GAUGE_TOP + GAUGE_HEIGHT):
		if image.get_pixel(GAUGE_X, y).is_equal_approx(fill_colour):
			rows += 1
	return rows


func _count_pixels(image: Image) -> int:
	var pixels: int = 0
	for y: int in range(COUNT_AREA.position.y, COUNT_AREA.end.y):
		for x: int in range(COUNT_AREA.position.x, COUNT_AREA.end.x):
			if image.get_pixel(x, y).is_equal_approx(PURPLE):
				pixels += 1
	return pixels


func test_the_gauge_fills_with_the_charge() -> void:
	var empty: int = _filled_rows(EngineChargeInfoArt.compose(0, 10, TILE_ART))
	var half: int = _filled_rows(EngineChargeInfoArt.compose(5, 10, TILE_ART))
	var full: int = _filled_rows(EngineChargeInfoArt.compose(10, 10, TILE_ART))
	assert_lt(empty, half)
	assert_lt(half, full)
	assert_gt(full, GAUGE_HEIGHT - 4, "a full drive fills the gauge")


func test_the_count_follows_the_charge() -> void:
	assert_eq(EngineChargeInfoArt.count_text(7, 10), "7/10")
	assert_ne(_count_pixels(EngineChargeInfoArt.compose(7, 10, TILE_ART)),
		_count_pixels(EngineChargeInfoArt.compose(4, 10, TILE_ART)))
	assert_gt(_count_pixels(EngineChargeInfoArt.compose(0, 10, TILE_ART)), 0, "a cold drive still reads 0/10")


func test_a_long_count_drops_the_gate() -> void:
	assert_eq(EngineChargeInfoArt.count_text(188, 200), "188")


func test_the_tile_sits_beside_the_gauge() -> void:
	var built: Image = EngineChargeInfoArt.compose(3, 10, TILE_ART)
	var art: Image = TILE_ART.get_image()
	art.convert(Image.FORMAT_RGBA8)
	assert_true(built.get_pixel(2 + 12, 12 + 12).is_equal_approx(art.get_pixel(12, 12)))


func test_a_tile_with_a_live_picture_shows_it_in_its_info() -> void:
	var tile: Tile = load("res://Source/Content/Tiles/tile.tscn").instantiate()
	tile.tile_resource = load("res://Source/Content/Tiles/MapTileResources/engine_charger.tres")
	add_child_autofree(tile)
	var live: Texture2D = EngineChargeInfoArt.texture_for(4, 10, TILE_ART)
	tile.info_picture = func() -> Texture2D: return live
	assert_eq(tile._get_tile_info().texture, live)
