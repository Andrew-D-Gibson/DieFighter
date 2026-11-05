extends "res://test/helpers/die_fighter_test.gd"
## Font roles (FontRoles): every locale has a profile with a face per role,
## switching language swaps fonts and sizes live and comes back exactly, the
## theme's slot types match the table, and no text a scene translates carries
## a raw font or size of its own.

## The role wrappers, read through variables: GDScript folds a property read
## on a const preload (`CONST.base_font`) at compile time, so it would never
## see a swap.
var _small: FontVariation = FontRoles.font(FontRoles.SMALL)
var _body: FontVariation = FontRoles.font(FontRoles.BODY)

## Text node types whose `text` a scene can translate.
const _TEXT_TYPES: Array[String] = [
	"Label", "RichTextLabel", "Button", "LinkButton", "CheckBox", "CheckButton", "OptionButton",
]
## Scene text allowed a raw font or size, by "scene path:node name", with why.
const _SCENE_OVERRIDES_ALLOWED: Dictionary[String, String] = {
	"res://Source/Systems/UI/MainMenu/main_menu.tscn:TitleText": "the logo; its font and size are the user's call",
	"res://Source/Scenes/planet_mockup.tscn:TitleText": "an art mock-up, not the game",
	"res://Source/Systems/UI/DevConsole/dev_console.tscn:RichTextLabel": "dev tool, never translated",
}
## Scripts allowed to set a font or size on a Control, with why.
const _CODE_OVERRIDES_ALLOWED: Dictionary[String, String] = {
	"res://Source/Systems/UI/Buttons/pixel_dropdown.gd": "copies the theme's PopupMenu size, which FontRoles sets",
	"res://Source/Systems/UI/DevConsole/dev_text_box.gd": "dev tool, never translated",
	"res://Source/Systems/UI/DevConsole/ScenarioLab/scenario_lab_ui.gd": "dev tool, never translated",
	"res://Source/Systems/UI/DevConsole/TilePalette/tile_palette.gd": "dev tool, never translated",
	"res://Source/Systems/Autoloads/mcp_interaction_server.gd": "the MCP test bridge applies what it's sent",
}

var _locale_before: String = ""


func before_each() -> void:
	super()
	_locale_before = TranslationServer.get_locale()


func after_each() -> void:
	FontRoles.set_readable(false)
	FontRoles.use_locale(_locale_before)
	super()


func test_every_locale_has_its_own_profile_with_every_role() -> void:
	var locales: Array[String] = []
	locales.assign(Localization.LOCALE_NAMES.keys())
	locales.append(Localization.PSEUDO_LOCALE)
	for locale: String in locales:
		var profile: FontProfile = FontRoles.profile_for(locale)
		assert_eq(profile.resource_path, FontRoles.PROFILE_DIR + locale + ".tres", locale)
		for role: StringName in FontRoles.ROLES:
			var face: FontFace = profile.face(role)
			assert_not_null(face, "%s %s" % [locale, role])
			if face:
				assert_not_null(face.font, "%s %s font" % [locale, role])
				assert_gt(face.size, 0, "%s %s size" % [locale, role])


func test_a_locale_without_a_profile_borrows_its_language_or_english() -> void:
	assert_eq(FontRoles.profile_for("de_AT").resource_path, FontRoles.PROFILE_DIR + "de.tres")
	assert_eq(FontRoles.profile_for("xx_YY").resource_path, FontRoles.PROFILE_DIR + "en.tres")


## The theme file holds the English look, so the editor shows it: every slot
## type is a variation of Control, draws through its role's wrapper, and is
## the English unit times its scale.
func test_the_theme_defines_every_slot_type_in_english_sizes() -> void:
	# The file, not the project theme FontRoles points at the current faces.
	var theme: Theme = ResourceLoader.load(ProjectSettings.get_setting("gui/theme/custom"), "",
		ResourceLoader.CACHE_MODE_IGNORE)
	var english: FontProfile = FontRoles.profile_for("en")
	assert_eq(theme.default_font, _small)
	assert_eq(theme.default_font_size, english.small.size)
	for type: StringName in FontRoles.SLOT_TYPES:
		var role: StringName = FontRoles.SLOT_TYPES[type][0]
		var expected: int = roundi(english.face(role).size * float(FontRoles.SLOT_TYPES[type][1]))
		assert_eq(theme.get_type_variation_base(type), &"Control", type)
		for item: StringName in [&"font", &"normal_font"]:
			assert_eq(theme.get_font(item, type), FontRoles.font(role), "%s %s" % [type, item])
		for item: StringName in [&"font_size", &"normal_font_size"]:
			assert_eq(theme.get_font_size(item, type), expected, "%s %s" % [type, item])
	for type: StringName in theme.get_type_variation_list(&"Control"):
		assert_has(FontRoles.SLOT_TYPES, type, "theme slot type missing from FontRoles.SLOT_TYPES")


func test_switching_language_swaps_fonts_and_sizes_live_and_back_exactly() -> void:
	FontRoles.use_locale("en")
	var plain: Label = Label.new()
	plain.text = "Show Tutorial"
	var title: Label = Label.new()
	title.text = "SECTOR 2"
	title.theme_type_variation = &"BodyX6"
	add_child_autofree(plain)
	add_child_autofree(title)
	var english: Array[Vector2] = [plain.get_minimum_size(), title.get_minimum_size()]
	assert_eq(plain.get_theme_font_size(&"font_size"), 16)
	assert_eq(title.get_theme_font_size(&"font_size"), 96)

	FontRoles.use_locale("de")
	assert_eq(_small.base_font.resource_path, "res://Assets/Fonts/Tiny5/Tiny5.ttf", "German small text is Tiny5")
	assert_eq(plain.get_theme_font_size(&"font_size"), 8, "at Tiny5's native size")
	assert_eq(_body.base_font, FontRoles.profile_for("en").body.font, "German body text stays m5x7")
	assert_eq(title.get_theme_font_size(&"font_size"), 96)
	assert_ne(plain.get_minimum_size(), english[0], "plain text re-laid out")

	FontRoles.use_locale("zh_CN")
	assert_eq(title.get_theme_font_size(&"font_size"), 72, "Fusion Pixel 12 at x6")
	assert_ne(title.get_minimum_size(), english[1])

	FontRoles.use_locale("en")
	var english_fonts: FontProfile = FontRoles.profile_for("en")
	assert_same(_small.base_font, english_fonts.small.font)
	assert_same(_body.base_font, english_fonts.body.font)
	assert_eq(plain.get_minimum_size(), english[0])
	assert_eq(title.get_minimum_size(), english[1])


## Text shaped in the old language's font re-lays out after a switch without
## the TextServer reading freed font data: the profiles stay loaded, so the
## old font outlives the switch. (Freed, every such re-shape logged
## 'Parameter "fd" is null' from _font_get_ascent/descent/spacing.)
func test_text_shaped_before_a_switch_survives_it() -> void:
	FontRoles.use_locale("de")
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string("Hallo Welt", FontRoles.font(FontRoles.SMALL), FontRoles.size(FontRoles.SMALL))
	paragraph.width = 200
	assert_gt(paragraph.get_size().y, 0.0)
	var german_font: WeakRef = weakref(_small.base_font)

	FontRoles.use_locale("en")
	assert_not_null(german_font.get_ref(), "the German font is still loaded")
	paragraph.width = 30
	assert_gt(paragraph.get_size().y, 0.0, "the old text re-shapes in its own font")
	var font_errors: Array = get_errors().filter(func(error: Variant) -> bool: return error.contains_text("fd"))
	assert_eq(font_errors.size(), 0, "no TextServer reads of freed font data")


## Setting the language applies its profile even when the locale is already
## current, which is how the first call at boot takes effect.
func test_set_locale_applies_the_profile_even_when_unchanged() -> void:
	FontRoles.use_locale("de")
	Localization.set_locale(TranslationServer.get_locale())
	assert_eq(_small.base_font, FontRoles.profile_for(TranslationServer.get_locale()).small.font)


## Readable Font leads with Atkinson and keeps the language's fonts behind it,
## so a script Atkinson lacks still draws. It changes Latin text only: in
## Chinese and Japanese Atkinson leads at Fusion Pixel's 12 (a copy that draws
## at 12 as the usual one does at 16), so Fusion stays on its own grid.
func test_readable_font_layers_over_the_language() -> void:
	FontRoles.use_locale("zh_CN")
	FontRoles.set_readable(true)
	var zh_small: FontFace = FontRoles.profile_for("zh_CN").small
	assert_eq(_small.base_font, FontSwap.font_for(_small, true))
	assert_eq(FontRoles.size(FontRoles.SMALL), zh_small.size, "Fusion Pixel draws at its native 12")
	assert_true(_small.fallbacks.any(func(font: Font) -> bool:
		return font == zh_small.font or (font is FontVariation and font.base_font == zh_small.font)))
	assert_true(_small.has_char("你".unicode_at(0)))


## Behind Readable Font every language's own fonts are at their unit size,
## and Latin text looks as it does in English with Readable Font.
func test_readable_font_keeps_each_languages_units_and_englishs_latin() -> void:
	FontRoles.use_locale("en")
	FontRoles.set_readable(true)
	var english: Dictionary[StringName, Vector2] = {}
	for type: StringName in [&"", &"BodyX6", &"SmallX6"]:
		english[type] = _measure("Hull 24/32", type)
	var locales: Array[String] = []
	locales.assign(Localization.LOCALE_NAMES.keys())
	locales.append(Localization.PSEUDO_LOCALE)
	for locale: String in locales:
		FontRoles.use_locale(locale)
		for role: StringName in FontRoles.ROLES:
			assert_eq(FontRoles.face(role).size, FontRoles.profile_for(locale).face(role).size,
				"%s %s" % [locale, role])
		for type: StringName in english:
			# unitsPerEm is whole, so the 12 copy can be a hair narrower.
			var size: Vector2 = _measure("Hull 24/32", type)
			assert_almost_eq(size.x, english[type].x, 1.0, "%s Latin width in %s" % [locale, type])
			assert_eq(size.y, english[type].y, "%s Latin height in %s" % [locale, type])


## Under Readable Font every language keeps English's line box at every
## scale, in its own script too: the language font behind the readable one
## carries its own spacing, scaled with the slot.
func test_readable_text_keeps_englishs_line_box() -> void:
	FontRoles.use_locale("en")
	var english: Dictionary[StringName, float] = {}
	for type: StringName in [&"", &"BodyX6", &"SmallX6"]:
		english[type] = _measure("HULL", type).y
	FontRoles.set_readable(true)
	for sample: Array in [["zh_CN", "船体 HULL"], ["ja", "船体 HULL"], ["ru", "Жук HULL"], ["de", "Hülle"]]:
		FontRoles.use_locale(sample[0])
		for type: StringName in english:
			assert_almost_eq(_measure(sample[1], type).y, english[type], 2.0, "%s readable %s" % [sample[0], type])
		var paragraph: RichTextLabel = RichTextLabel.new()
		paragraph.fit_content = true
		paragraph.size = Vector2(400, 10)
		paragraph.text = sample[1] + "\n" + sample[1]
		add_child_autofree(paragraph)
		assert_eq(paragraph.get_content_height(), 22, "%s two readable lines step 9" % sample[0])


func _measure(text: String, type: StringName) -> Vector2:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = type
	add_child_autofree(label)
	return label.get_minimum_size()


## A fallback draws at the primary's size, so it must not make the role's
## lines any taller than its own font's.
func test_fallbacks_keep_each_faces_line_height() -> void:
	for file: String in DirAccess.get_files_at("res://Assets/Fonts/Faces/"):
		if not file.ends_with(".tres"):
			continue
		var face: FontFace = load("res://Assets/Fonts/Faces/" + file)
		for fallback: Font in face.fallbacks:
			assert_lte(fallback.get_ascent(face.size), face.font.get_ascent(face.size), file)
			assert_lte(fallback.get_descent(face.size), face.font.get_descent(face.size), file)


## Every language draws each role in English's line box (11 px above the
## baseline, 2 below at x1), so text sits where English's does in every box
## sized for it, whatever the font.
func test_every_language_keeps_englishs_line_box() -> void:
	var english: FontProfile = FontRoles.profile_for("en")
	var locales: Array[String] = []
	locales.assign(Localization.LOCALE_NAMES.keys())
	locales.append(Localization.PSEUDO_LOCALE)
	for locale: String in locales:
		var profile: FontProfile = FontRoles.profile_for(locale)
		for role: StringName in FontRoles.ROLES:
			var face: FontFace = profile.face(role)
			var base: FontFace = english.face(role)
			var context: String = "%s %s (%s)" % [locale, role, face.resource_path.get_file()]
			assert_eq(face.font.get_ascent(face.size) + face.spacing_top,
				base.font.get_ascent(base.size) + base.spacing_top, context + " above the baseline")
			assert_eq(face.font.get_descent(face.size) + face.spacing_bottom,
				base.font.get_descent(base.size) + base.spacing_bottom, context + " below it")


## A slot at xN gets N times its face's spacing, so a big German or Chinese
## line is exactly English's height too.
func test_line_spacing_scales_with_the_slot() -> void:
	var small_x6: Label = Label.new()
	small_x6.text = "SAVED"
	small_x6.theme_type_variation = &"SmallX6"
	var body_x6: Label = Label.new()
	body_x6.text = "SECTOR"
	body_x6.theme_type_variation = &"BodyX6"
	var plain: Label = Label.new()
	plain.text = "HULL"
	for label: Label in [small_x6, body_x6, plain]:
		add_child_autofree(label)
	FontRoles.use_locale("en")
	var theme: Theme = ThemeDB.get_project_theme()
	var heights: Array[float] = [small_x6.get_minimum_size().y, body_x6.get_minimum_size().y, plain.get_minimum_size().y]

	FontRoles.use_locale("de")
	assert_eq((theme.get_font(&"font", &"SmallX6") as FontVariation).spacing_top, 24, "Tiny5's 4 px at x6")
	assert_eq(small_x6.get_minimum_size().y, heights[0], "German small text at x6")
	assert_eq(plain.get_minimum_size().y, heights[2], "German small text at x1")
	FontRoles.use_locale("zh_CN")
	# m5x7's own ascent is 10.67 px at 16, so English body at x6 is 76, not
	# 6 x 13: whole-pixel spacing gets within a pixel of the slot's scale.
	assert_almost_eq(body_x6.get_minimum_size().y, heights[1], 2.0, "Chinese body text at x6")
	assert_eq(small_x6.get_minimum_size().y, heights[0], "Chinese small text at x6")

	FontRoles.use_locale("en")
	assert_eq(small_x6.get_minimum_size().y, heights[0])


## Popup figures are m5x7 and m3x6 in every language, so "12→3" looks the
## same in all of them, and the drawn arrow sits on m5x7's 7-pixel digits.
func test_popup_figures_are_the_same_in_every_language() -> void:
	var english: FontProfile = FontRoles.profile_for("en")
	var locales: Array[String] = []
	locales.assign(Localization.LOCALE_NAMES.keys())
	locales.append(Localization.PSEUDO_LOCALE)
	for locale: String in locales:
		var profile: FontProfile = FontRoles.profile_for(locale)
		for role: StringName in FontRoles.FIGURE_ROLES:
			assert_same(profile.face(role), english.face(role), "%s %s" % [locale, role])
		FontRoles.use_locale(locale)
		assert_eq(FontRoles.digit_height(FontRoles.DIGITS), 7, locale)
	assert_eq(DamageNumber._CapArrow.first_row_for(7), 1)
	assert_same(english.digits.font, english.body.font, "the result in English's popup font")
	assert_same(english.digits_small.font, english.small.font, "the lead a size down")


## A popup's figures land in the digits roles and its words in the popup
## role, and "12→3" lays out the same in Chinese as in English.
func test_popup_figures_lay_out_alike_in_every_language() -> void:
	assert_true(DamageNumber.is_figure("+25%"))
	assert_true(DamageNumber.is_figure("4 + 2"))
	assert_false(DamageNumber.is_figure("+2 BURN"))
	assert_false(DamageNumber.is_figure("+"))
	var layouts: Array[String] = []
	for locale: String in ["en", "zh_CN"]:
		FontRoles.use_locale(locale)
		var holder: Node2D = Node2D.new()
		add_child_autofree(holder)
		DamageNumber._spawn_label(holder, Vector2.ZERO, "3", Color.WHITE, false, Vector2.ZERO, 1.0, 0.8, "12")
		var layout: PackedStringArray = []
		for child: Node in holder.get_child(0).get_children():
			if child is Label:
				layout.append("%s %s %s %s" % [child.text, child.theme_type_variation, child.position, child.size])
			else:
				layout.append("arrow %s" % child.position)
		layouts.append(" | ".join(layout))
	assert_string_contains(layouts[0], "12 DigitsSmallX1")
	assert_eq(layouts[1], layouts[0])


## Every figure a popup shows draws in the figure roles' own fonts.
func test_figure_roles_draw_every_figure_character() -> void:
	for file: String in DirAccess.get_files_at(FontRoles.PROFILE_DIR):
		if not file.ends_with(".tres"):
			continue
		var profile: FontProfile = load(FontRoles.PROFILE_DIR + file)
		for role: StringName in FontRoles.FIGURE_ROLES:
			for character: String in FontRoles.FIGURE_CHARACTERS:
				assert_true(profile.face(role).has_char(character.unicode_at(0)),
					"%s %s '%s'" % [file, role, character])


## The lint: text a scene translates names a role (theme_type_variation),
## never a font or size of its own, so a language can resize the role.
func test_no_scene_gives_translated_text_a_raw_font_or_size() -> void:
	var offenders: Array[String] = []
	for path: String in _files_under("res://Source", "tscn"):
		offenders.append_array(_scene_offenders(path))
	assert_eq(offenders, [] as Array[String],
		"name a slot type in theme_type_variation (FontRoles.SLOT_TYPES) instead:\n" + "\n".join(offenders))


func test_no_script_gives_a_control_a_raw_font_or_size() -> void:
	var calls: RegEx = RegEx.create_from_string(r"add_theme_font(_size)?_override\(")
	var offenders: Array[String] = []
	for path: String in _files_under("res://Source", "gd"):
		if path in _CODE_OVERRIDES_ALLOWED:
			continue
		if calls.search(FileAccess.get_file_as_string(path)):
			offenders.append(path)
	assert_eq(offenders, [] as Array[String],
		"set theme_type_variation = FontRoles.slot(role, scale) instead:\n" + "\n".join(offenders))


func _scene_offenders(path: String) -> Array[String]:
	var offenders: Array[String] = []
	var text: String = FileAccess.get_file_as_string(path)
	for block: String in text.split("\n["):
		if not block.begins_with("node "):
			continue
		var header: RegExMatch = RegEx.create_from_string(r'^node name="([^"]+)" type="([^"]+)"').search(block)
		if header == null or header.get_string(2) not in _TEXT_TYPES:
			continue
		var id: String = "%s:%s" % [path, header.get_string(1)]
		if id in _SCENE_OVERRIDES_ALLOWED:
			continue
		var has_text: bool = block.contains("\ntext = ")
		var translated: bool = not block.contains("\nauto_translate_mode = 2")
		var raw: bool = block.contains("\ntheme_override_fonts/") or block.contains("\ntheme_override_font_sizes/")
		if has_text and translated and raw:
			offenders.append(id)
	return offenders


func _files_under(dir_path: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_files_under(dir_path.path_join(sub), extension))
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == extension:
			found.append(dir_path.path_join(file))
	return found
