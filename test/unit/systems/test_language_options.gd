extends "res://test/helpers/die_fighter_test.gd"
## The languages a player can pick: all eight, translated or not, never the
## pseudo-locale, each one switching the text and fonts without errors. Also
## that the overflow watcher stays out of play until asked for. Nothing here
## saves, so the player's options file is never touched.

const _OPTIONS_SCENE: PackedScene = preload("res://Source/Systems/UI/OptionsMenu/options_menu.tscn")

## Read through a variable: GDScript folds a property read on a const
## preload at compile time.
var _small: FontVariation = FontRoles.font(FontRoles.SMALL)
var _locale_before: String = ""


func before_each() -> void:
	super()
	_locale_before = TranslationServer.get_locale()


func after_each() -> void:
	Localization.set_locale(_locale_before, true)
	super()


func test_every_language_is_offered_and_pseudo_never() -> void:
	var offered: Array[String] = Localization.get_available_locales()
	var every: Array[String] = []
	every.assign(Localization.LOCALE_NAMES.keys())
	assert_eq(offered, every)
	assert_does_not_have(offered, Localization.PSEUDO_LOCALE)


## Picking one is what Options and the saved file do (OptionsSettings writes
## the LANGUAGE option, which calls set_locale): the locale and its fonts
## follow, whether or not the language has text yet.
func test_picking_a_language_sets_its_locale_and_fonts() -> void:
	for locale: String in ["de", "zh_CN", "ja", "ru", "en"]:
		OptionsSettings._options[OptionsSettings.LANGUAGE].write.call(locale)
		assert_eq(TranslationServer.get_locale(), locale)
		assert_eq(OptionsSettings.get_option(OptionsSettings.LANGUAGE), locale, "what gets saved")
		assert_eq(_small.base_font, FontRoles.profile_for(locale).small.font, "%s fonts" % locale)
	assert_eq(get_errors().size(), 0, "no engine errors switching language")


## A saved pseudo-locale (from a build that offered it) isn't restored; the
## dev console and the audit still reach it.
func test_pseudo_only_by_asking_for_it() -> void:
	Localization.set_locale(Localization.PSEUDO_LOCALE)
	assert_ne(TranslationServer.get_locale(), Localization.PSEUDO_LOCALE)
	Localization.set_locale(Localization.PSEUDO_LOCALE, true)
	assert_eq(TranslationServer.get_locale(), Localization.PSEUDO_LOCALE)


## Each language's UI table is registered at startup, so a column that gets
## text shows up in game with no other step.
func test_every_imported_language_is_registered() -> void:
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	for locale: String in Localization.LOCALE_NAMES:
		if ResourceLoader.exists("res://Localization/translations.%s.translation" % locale):
			assert_has(loaded, locale)


## A translated row reaches the game in its language; an untranslated one
## falls back to English rather than showing its key.
func test_a_registered_language_translates_and_falls_back() -> void:
	var german: Translation = load("res://Localization/translations.de.translation")
	var english: Translation = TranslationServer.get_translation_object("en")
	var translated: StringName = &""
	var untranslated: StringName = &""
	for key: StringName in english.get_message_list():
		if german.get_message(key) == &"":
			untranslated = key
		elif german.get_message(key) != english.get_message(key):
			translated = key
	Localization.set_locale("de")
	if translated != &"":
		assert_eq(tr(translated), String(german.get_message(translated)))
	if untranslated != &"":
		assert_eq(tr(untranslated), String(english.get_message(untranslated)))


func test_english_is_translated_and_an_unknown_language_is_not() -> void:
	assert_true(Localization.is_translated("en"))
	assert_false(Localization.is_translated("xx"))


func test_the_options_menu_lists_all_eight_and_marks_the_untranslated() -> void:
	Localization.set_locale("en")
	var menu: OptionsMenu = _OPTIONS_SCENE.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(1)
	var dropdown: PixelDropdown = menu._language_dropdown
	var names: Array[String] = []
	var short_names: Array[String] = []
	for locale: String in Localization.LOCALE_NAMES:
		names.append(Localization.get_locale_name(locale))
		short_names.append(Localization.get_locale_short_name(locale))
	assert_eq(dropdown.items, short_names, "each language by its own name, on the closed button")
	assert_false(dropdown.items.has(Localization.get_locale_name(Localization.PSEUDO_LOCALE)))

	for i: int in range(names.size()):
		var locale: String = Localization.LOCALE_NAMES.keys()[i]
		var marked: String = names[i] + " " + tr("OPT_LANGUAGE_ENGLISH_TEXT")
		assert_eq(dropdown.list_row_text(i), names[i] if Localization.is_translated(locale) else marked, locale)


## English's fonts have no Chinese or Japanese, so those names draw in their
## own language's face at its own size; the rest, and every "(English text)"
## mark, keep the menu's font. Every row is the same height.
func test_names_the_menu_font_lacks_draw_in_their_own() -> void:
	Localization.set_locale("en")
	var menu: OptionsMenu = _OPTIONS_SCENE.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(1)
	var dropdown: PixelDropdown = menu._language_dropdown
	dropdown._open_popup()
	await wait_process_frames(2)
	var rows: Array[Node] = dropdown._popup_panel.find_children("*", "Button", true, false)
	var locales: Array = Localization.LOCALE_NAMES.keys()
	var heights: Array[float] = []
	for i: int in range(rows.size()):
		var parts: Array[Node] = rows[i].find_children("*", "Label", true, false)
		# A row with a mark writes its name and mark as two Labels.
		var name_part: Control = parts[0] if not parts.is_empty() else rows[i] as Control
		var own_font: bool = name_part.get_theme_font("font") != dropdown.get_theme_font("font", "Button")
		assert_eq(own_font, locales[i] in ["zh_CN", "ja"], locales[i])
		if own_font:
			var face: FontFace = FontRoles.profile_for(locales[i]).small
			assert_eq(name_part.get_theme_font_size("font_size"), face.size, "%s at its own size" % locales[i])
			var font: Font = name_part.get_theme_font("font")
			for character: int in Localization.get_locale_name(locales[i]).to_utf32_buffer().to_int32_array():
				assert_true(font.has_char(character), "%s draws %s" % [locales[i], char(character)])
		if parts.size() > 1:
			assert_eq(parts[1].get_theme_font("font"), dropdown.get_theme_font("font", "Button"),
				"%s mark in the menu's font" % locales[i])
		heights.append((rows[i] as Control).size.y)
	dropdown._close_popup()
	assert_eq(heights.size(), locales.size())
	assert_eq(heights.min(), heights.max(), "every row the same height: %s" % [heights])


func test_the_overflow_watcher_waits_to_be_asked() -> void:
	assert_null(Localization.overflow_watcher, "no watcher until loc_watch on")
	assert_false(Localization.is_watching_overflow())
	assert_true(Localization.watch_overflow(true))
	assert_not_null(Localization.overflow_watcher)
	assert_true(Localization.overflow_watcher.live)
	Localization.watch_overflow(false)
	assert_false(Localization.is_watching_overflow())
	# Back to how play starts.
	Localization.overflow_watcher.free()
	Localization.overflow_watcher = null
