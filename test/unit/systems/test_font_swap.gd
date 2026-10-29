extends "res://test/helpers/die_fighter_test.gd"
## Readable Font: the option swaps every pixel font wrapper to its readable
## replacement and back, text re-lays out, and nothing bypasses the wrappers.
## Nothing here saves, so the player's options file is never touched.

const M3X6_UI: FontVariation = preload("res://Assets/Fonts/m3x6/m3x6_ui.tres")
const M5X7_UI: FontVariation = preload("res://Assets/Fonts/m5x7/m5x7_ui.tres")

## Files that may name a pixel font file: the wrappers, and the swap table.
const _ALLOWED_REFERENCES: Array[String] = [
	"res://Assets/Fonts/m3x6/m3x6_ui.tres",
	"res://Assets/Fonts/m5x7/m5x7_ui.tres",
	"res://Source/Systems/Display/font_swap.gd",
]
## A pixel font file named by path or by uid.
const _PIXEL_FONT_REFERENCES: Array[String] = [
	"m3x6.ttf", "m5x7.ttf", "uid://d18mhx31l6gjo", "uid://bekus7kljl5ap",
]
const _SENTENCE: String = "Any die -> Tiles above and below get +2 to effects this turn"
## Button scenes with the longest labels they carry.
const _BUTTON_LABELS: Dictionary[String, Array] = {
	"res://Source/Systems/UI/Buttons/large_button.tscn": ["CONTINUE", "NEW GAME"],
	"res://Source/Systems/UI/Buttons/medium_button.tscn": ["WISHLIST", "OPTIONS", "DEFAULTS"],
	"res://Source/Systems/UI/Buttons/small_button.tscn": ["CLOSE"],
}

var _was_readable: bool = false


func before_each() -> void:
	super()
	_was_readable = FontSwap.is_readable()
	FontSwap.set_readable(false)


func after_each() -> void:
	FontSwap.set_readable(_was_readable)
	super()


func test_wrappers_show_the_pixel_fonts_by_default() -> void:
	assert_eq(FontSwap.wrappers(), [M3X6_UI, M5X7_UI] as Array[FontVariation])
	assert_false(FontSwap.is_readable())
	assert_eq(M3X6_UI.base_font, load("res://Assets/Fonts/m3x6/m3x6.ttf"))
	assert_eq(M5X7_UI.base_font, load("res://Assets/Fonts/m5x7/m5x7.ttf"))


func test_toggling_swaps_every_wrapper_and_restores_the_same_fonts() -> void:
	var originals: Array[Font] = [M3X6_UI.base_font, M5X7_UI.base_font]

	FontSwap.set_readable(true)
	assert_true(FontSwap.is_readable())
	for wrapper: FontVariation in FontSwap.wrappers():
		assert_eq(wrapper.base_font, FontSwap.font_for(wrapper, true))
		assert_ne(wrapper.base_font, FontSwap.font_for(wrapper, false))

	FontSwap.set_readable(false)
	assert_false(FontSwap.is_readable())
	assert_same(M3X6_UI.base_font, originals[0])
	assert_same(M5X7_UI.base_font, originals[1])


## The readable fonts ride up or down so their capitals centre where the
## pixel fonts' do; the pixel look comes back with no offset at all.
func test_readable_fonts_wear_their_cap_centring_offset() -> void:
	FontSwap.set_readable(true)
	for wrapper: FontVariation in FontSwap.wrappers():
		assert_ne(wrapper.baseline_offset, 0.0, wrapper.resource_path)
		assert_almost_eq(wrapper.baseline_offset, FontSwap.baseline_offset_for(wrapper, true), 0.0001)
	FontSwap.set_readable(false)
	for wrapper: FontVariation in FontSwap.wrappers():
		assert_eq(wrapper.baseline_offset, 0.0, wrapper.resource_path)


## Nearest-filtered MSDF needs a field finer than the screen: at the stock 64
## the strokes stair-step through the 6x camera.
func test_readable_fonts_import_a_fine_enough_msdf() -> void:
	for wrapper: FontVariation in FontSwap.wrappers():
		var readable: FontFile = FontSwap.font_for(wrapper, true) as FontFile
		assert_true(readable.multichannel_signed_distance_field, readable.resource_path)
		assert_gte(readable.msdf_size, 128, readable.resource_path)


func test_the_option_drives_the_swap_and_defaults_to_off() -> void:
	assert_true(OptionsSettings.has_option(OptionsSettings.READABLE_FONT))
	assert_eq(OptionsSettings.get_default(OptionsSettings.READABLE_FONT), false)

	OptionsSettings.set_option(OptionsSettings.READABLE_FONT, true)
	assert_true(FontSwap.is_readable())
	assert_eq(OptionsSettings.get_option(OptionsSettings.READABLE_FONT), true)

	OptionsSettings.reset_options([OptionsSettings.READABLE_FONT])
	assert_false(FontSwap.is_readable())


func test_the_theme_draws_through_the_wrapper() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	assert_eq(theme.default_font, M3X6_UI)
	assert_eq(theme.get_font(&"font", &"Label"), M3X6_UI)
	assert_eq(theme.get_font(&"font", &"PopupMenu"), M3X6_UI)


func test_text_relayouts_and_comes_back_exactly() -> void:
	var label: Label = Label.new()
	label.text = "Show Tutorial"
	var overridden: Label = Label.new()
	overridden.text = "Overload 12/20"
	overridden.add_theme_font_override(&"font", M5X7_UI)
	add_child_autofree(label)
	add_child_autofree(overridden)
	var pixel_sizes: Array[Vector2] = [label.get_minimum_size(), overridden.get_minimum_size()]

	FontSwap.set_readable(true)
	assert_ne(label.get_minimum_size(), pixel_sizes[0], "theme text re-shaped in the readable font")
	assert_ne(overridden.get_minimum_size(), pixel_sizes[1], "overridden text re-shaped too")

	FontSwap.set_readable(false)
	assert_eq(label.get_minimum_size(), pixel_sizes[0])
	assert_eq(overridden.get_minimum_size(), pixel_sizes[1])


## The readable fonts are fitted to take the pixel fonts' room: the same line
## height, and sentences no wider.
func test_readable_text_takes_the_pixel_fonts_room() -> void:
	for wrapper: FontVariation in FontSwap.wrappers():
		var pixel: Font = FontSwap.font_for(wrapper, false)
		var readable: Font = FontSwap.font_for(wrapper, true)
		for size: int in [16, 32]:
			var context: String = "%s at %d" % [wrapper.resource_path, size]
			assert_eq(readable.get_height(size), pixel.get_height(size), "line height, " + context)
			assert_eq(readable.get_ascent(size), pixel.get_ascent(size), "baseline, " + context)
			assert_lte(readable.get_string_size(_SENTENCE, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
				pixel.get_string_size(_SENTENCE, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, "sentence width, " + context)


## Capitals are the tight spot: the pixel fonts' are unusually narrow.
func test_button_labels_stay_on_one_line() -> void:
	FontSwap.set_readable(true)
	for scene_path: String in _BUTTON_LABELS:
		for text: String in _BUTTON_LABELS[scene_path]:
			var button: Button = load(scene_path).instantiate()
			add_child_autofree(button)
			button.set_button_text(text)
			var label: RichTextLabel = button.get_node("RichTextLabel")
			await wait_process_frames(2)
			assert_eq(label.get_line_count(), 1, "'%s' in %s" % [text, scene_path.get_file()])


## Text that used a pixel font file directly would ignore Readable Font.
func test_nothing_uses_a_pixel_font_file_directly() -> void:
	var offenders: Array[String] = []
	for root: String in ["res://Source", "res://Assets", "res://test"]:
		_collect_offenders(root, offenders)
	assert_eq(offenders, [] as Array[String], "use m3x6_ui.tres / m5x7_ui.tres instead")


func _collect_offenders(dir_path: String, offenders: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect_offenders(dir_path.path_join(sub), offenders)
	for file: String in DirAccess.get_files_at(dir_path):
		var path: String = dir_path.path_join(file)
		if path.get_extension() not in ["tscn", "tres", "gd"] or path in _ALLOWED_REFERENCES:
			continue
		if path == get_script().resource_path:
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for reference: String in _PIXEL_FONT_REFERENCES:
			if text.contains(reference):
				offenders.append(path)
				break
