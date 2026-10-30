extends "res://test/helpers/die_fighter_test.gd"
## The options registry: an option reads and writes its live value, resets to
## its default, and the menu's pages bind to it. Nothing here saves, so the
## player's options file is never touched.

const TEST_KEY: StringName = &"Test/sample"

var _live_value: int = 3


func before_each() -> void:
	super()
	_live_value = 3
	OptionsSettings.register(TEST_KEY, 7,
		func() -> int: return _live_value,
		func(value: Variant) -> void: _live_value = int(value))


func after_each() -> void:
	OptionsSettings._options.erase(TEST_KEY)
	super()


func test_get_reads_the_live_value() -> void:
	_live_value = 11
	assert_eq(OptionsSettings.get_option(TEST_KEY), 11)


func test_set_writes_and_announces_the_new_value() -> void:
	watch_signals(OptionsSettings)
	OptionsSettings.set_option(TEST_KEY, 5)
	assert_eq(_live_value, 5)
	assert_signal_emitted_with_parameters(OptionsSettings, "option_changed", [TEST_KEY, 5])


func test_reset_restores_the_default_and_skips_unknown_keys() -> void:
	OptionsSettings.reset_options([TEST_KEY, &"Test/not_registered"])
	assert_eq(_live_value, 7)


func test_old_label_values_still_read_as_numbers() -> void:
	assert_eq(OptionsSettings._read_number("2x"), 2.0)
	assert_eq(OptionsSettings._read_number("Unlimited"), 0.0)
	assert_eq(OptionsSettings._read_number(60), 60.0)


func test_a_page_row_follows_the_option() -> void:
	var page: OptionsPage = OptionsPage.new()
	add_child_autofree(page)
	var dropdown: PixelDropdown = page.choice(TEST_KEY, "label", ["a", "b", "c"], [3, 5, 7])
	page.refresh()
	assert_eq(dropdown.selected, 0)

	dropdown.item_selected.emit(2)
	assert_eq(_live_value, 7)

	_live_value = 5
	page.refresh()
	assert_eq(dropdown.selected, 1)
	assert_eq(page.option_keys(), [TEST_KEY] as Array[StringName])


func test_numbers_match_across_int_and_float() -> void:
	assert_eq(OptionsPage.index_of([30, 60, 120], 60.0), 1)
	assert_eq(OptionsPage.index_of([0.5, 1.0], 1), 1)
	assert_eq(OptionsPage.index_of(["en", "de"], "de"), 1)
	assert_eq(OptionsPage.index_of([1, 2], 3), -1)


func test_art_scale_is_the_largest_whole_fit() -> void:
	assert_eq(PixelPerfectScaler.art_scale_for(Vector2i(3456, 2234)), 10)
	assert_eq(PixelPerfectScaler.art_scale_for(Vector2i(1920, 1080)), 6)
	assert_eq(PixelPerfectScaler.art_scale_for(Vector2i(5120, 1440)), 8)
	assert_eq(PixelPerfectScaler.art_scale_for(Vector2i(200, 100)), 1)


func test_pixel_perfect_frame_is_centred_on_whole_pixels() -> void:
	assert_eq(PixelPerfectScaler.frame_rect_for(Vector2i(3456, 2168), 10), Rect2i(128, 184, 3200, 1800))
	assert_eq(PixelPerfectScaler.frame_rect_for(Vector2i(1920, 1080), 6), Rect2i(0, 0, 1920, 1080))
	assert_eq(PixelPerfectScaler.frame_rect_for(Vector2i(5120, 1440), 8), Rect2i(1280, 0, 2560, 1440))


## --- Window recovery ---

const _LAPTOP: Rect2i = Rect2i(0, 25, 1440, 875)
const _MONITOR_TO_THE_RIGHT: Rect2i = Rect2i(1440, 0, 2560, 1415)


func test_a_window_on_a_screen_stays_put() -> void:
	var screens: Array[Rect2i] = [_LAPTOP]
	assert_true(OptionsSettings.is_on_screens(Rect2i(80, 100, 1280, 720), screens))


func test_a_window_straddling_two_screens_counts_both() -> void:
	var screens: Array[Rect2i] = [_LAPTOP, _MONITOR_TO_THE_RIGHT]
	assert_true(OptionsSettings.is_on_screens(Rect2i(1000, 100, 1280, 720), screens))


func test_a_window_left_on_an_unplugged_monitor_is_off_screen() -> void:
	var screens: Array[Rect2i] = [_LAPTOP]
	assert_false(OptionsSettings.is_on_screens(Rect2i(2000, 200, 1920, 1080), screens))


func test_a_window_mostly_off_the_edge_is_off_screen() -> void:
	var screens: Array[Rect2i] = [_LAPTOP]
	assert_false(OptionsSettings.is_on_screens(Rect2i(1200, 100, 1280, 720), screens))
	assert_false(OptionsSettings.is_on_screens(Rect2i(0, 0, 0, 0), screens), "an empty window is never on screen")


func test_a_brought_back_window_takes_the_largest_scale_that_fits() -> void:
	assert_eq(OptionsSettings.scale_to_fit(_LAPTOP.size), 4)
	assert_eq(OptionsSettings.scale_to_fit(_MONITOR_TO_THE_RIGHT.size), 6)
	assert_eq(OptionsSettings.scale_to_fit(Vector2i(500, 300)), 2, "the smallest when none fits")


func test_a_screen_of_unknown_size_gets_four_times() -> void:
	assert_eq(OptionsSettings.scale_to_fit(Vector2i.ZERO), 4)
