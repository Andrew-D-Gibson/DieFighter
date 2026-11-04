extends "res://test/helpers/die_fighter_test.gd"
## The translation lint (tools/loc.sh lint): content text has reached
## content.csv, and every translation in either CSV keeps what the game
## parses (placeholders, tokens, BBCode), fits its length limit and can be
## drawn by its locale's font.

const UI_CSV: String = LocPipeline.UI_CSV
const CONTENT_CSV: String = ContentText.CSV_PATH
## translations.csv's English column as Godot imported it.
const _EN_TRANSLATION: String = "res://Localization/translations.en.translation"

## Matches what Utils.format_text turns into icons or keywords, and BBCode,
## none of which is drawn as letters.
var _not_letters: RegEx = RegEx.create_from_string(r"\[[^\]]*\]|\([a-z_0-9=.]+\)|\{[^}]*\}|%[-+0-9.]*[a-zA-Z]")

## Glyph misses already known, by "locale role U+XXXX", left for the
## per-locale fit pass (C11b) to fix in a profile or the text.
const _KNOWN_GLYPH_MISSES: Array[String] = []

const _PseudoTranslation: GDScript = preload("res://Source/Systems/Localization/pseudo_translation.gd")

var _tables: Array[LocTable] = []
var _pseudo: Translation


func before_all() -> void:
	_tables = [LocTable.read(UI_CSV), LocTable.read(CONTENT_CSV)]


## Every content field has a row with its current English. Fails after an
## edit in the inspector until `tools/loc.sh sync` has run.
func test_content_csv_is_in_sync() -> void:
	var problems: Array[String] = LocPipeline.new().out_of_date(LocCatalog.scan())
	assert_eq(problems, [] as Array[String], "run tools/loc.sh sync:\n" + "\n".join(problems))


func test_translations_keep_placeholders_tokens_and_bbcode() -> void:
	var problems: Array[String] = []
	for table: LocTable in _tables:
		for key: String in table.keys():
			var english: String = table.english(key)
			for locale: String in table.locales():
				var cell: String = table.cell(key, locale)
				if cell.is_empty():
					continue
				for problem: String in LocLint.parity_problems(english, LocTable.unescape(cell)):
					problems.append("%s %s [%s]: %s" % [table.path.get_file(), key, locale, problem])
	assert_eq(problems, [] as Array[String], "\n".join(problems))


func test_text_fits_its_length_limit() -> void:
	var problems: Array[String] = []
	for table: LocTable in _tables:
		for key: String in table.keys():
			var limit: int = table.cell(key, LocTable.MAX_CHARS_COLUMN).to_int()
			if limit <= 0:
				continue
			for locale: String in [LocTable.SOURCE_COLUMN] + table.locales():
				var too_long: String = LocLint.length_problem(LocTable.unescape(table.cell(key, locale)), limit)
				if not too_long.is_empty():
					problems.append("%s %s [%s]: %s" % [table.path.get_file(), key, locale, too_long])
	assert_eq(problems, [] as Array[String], "\n".join(problems))


## What Godot imported is what the CSV says, row for row: a column added to
## the header (`?plural`) or a row short of cells mustn't shift any English.
func test_every_ui_row_reaches_the_game_unchanged() -> void:
	var english: Translation = load(_EN_TRANSLATION)
	var ui: LocTable = _tables[0]
	var problems: Array[String] = []
	for key: String in ui.keys():
		if LocTable.is_plural_form(key):
			continue
		var imported: String = english.get_message(key)
		if imported != ui.english(key):
			problems.append("%s: CSV says %s, the game reads %s" % [key, ui.english(key).c_escape(), imported.c_escape()])
	assert_eq(problems, [] as Array[String], "\n".join(problems))


## A plural row reaches tr_n() with its forms in order: English takes the
## row itself for one and the row under it for more.
func test_plural_rows_resolve_through_tr_n() -> void:
	var english: Translation = load(_EN_TRANSLATION)
	var ui: LocTable = _tables[0]
	var checked: int = 0
	for key: String in ui.keys():
		var plural_id: String = ui.cell(key, LocTable.PLURAL_COLUMN)
		if plural_id.is_empty():
			continue
		checked += 1
		assert_eq(english.get_plural_message(key, plural_id, 1), ui.english(key), key + " for one")
		for n: int in [0, 2, 5, 21]:
			assert_eq(english.get_plural_message(key, plural_id, n),
				ui.english(LocTable.plural_form_key(key, 2)), "%s for %d" % [key, n])
	assert_gt(checked, 0, "translations.csv has plural rows")


## The shipped plural callouts resolve and take their count. The words
## themselves are free to change.
func test_plural_callouts_fill_their_count() -> void:
	var english: Translation = load(_EN_TRANSLATION)
	var stacks: Callable = func(n: int) -> String:
		return String(english.get_plural_message(&"STATUS_BADGE_STACKS", &"STATUS_BADGE_STACKS_PLURAL", n)).format({"n": n})
	var dice: Callable = func(n: int) -> String:
		return String(english.get_plural_message(&"CALLOUT_DICE_LOST", &"CALLOUT_DICE_LOST_PLURAL", n)).format({"count": n})
	for form: Callable in [stacks, dice]:
		var one: String = form.call(1)
		var many: String = form.call(3)
		assert_string_contains(one, "1")
		assert_string_contains(many, "3")
		assert_false(one.contains("{") or many.contains("{"), "the count is filled in")


func test_no_key_is_in_both_csvs() -> void:
	var ui: LocTable = _tables[0]
	var clashes: Array[String] = []
	for key: String in _tables[1].keys():
		if ui.has(key):
			clashes.append(key)
	assert_eq(clashes, [] as Array[String])


## A letter a locale's fonts lack draws as a box, or in a system font the
## game didn't pick. Every string is checked against each font role's face in
## its locale's FontProfile, fallbacks included, since any text can land in
## any role but the figure roles. Locales with no translations yet pass
## trivially; the pseudo-locale checks the stretched English it shows.
func test_every_character_has_a_glyph() -> void:
	var problems: Array[String] = []
	var known: Array[String] = []
	for locale: String in _glyph_locales():
		var profile: FontProfile = FontRoles.profile_for(locale)
		if profile == null or not profile.resource_path.get_file().begins_with(locale + "."):
			problems.append("no FontProfile of its own for %s" % locale)
			continue
		for miss: String in _missing_glyphs(locale, profile):
			if miss.get_slice(":", 0) in _KNOWN_GLYPH_MISSES:
				known.append(miss)
			else:
				problems.append(miss)
	if not known.is_empty():
		gut.p("known glyph misses (left for C11b):\n" + "\n".join(known))
	assert_eq(problems, [] as Array[String], "\n".join(problems))


## Each (locale, role, character) a profile can't draw, as
## "locale role U+XXXX: 'c' in KEY, KEY...".
func _missing_glyphs(locale: String, profile: FontProfile) -> Array[String]:
	var keys_by_miss: Dictionary[String, PackedStringArray] = {}
	for table: LocTable in _tables:
		for key: String in table.keys():
			var text: String = _shown_text(table, key, locale)
			for character: String in _not_letters.sub(text, "", true):
				if character.strip_edges().is_empty():
					continue
				var code: int = character.unicode_at(0)
				for role: StringName in FontRoles.ROLES:
					# Only figures land in these (test_font_roles checks them).
					if role in FontRoles.FIGURE_ROLES or profile.face(role).has_char(code):
						continue
					var miss: String = "%s %s U+%04X: '%s'" % [locale, role, code, character]
					if not keys_by_miss.has(miss):
						keys_by_miss[miss] = PackedStringArray()
					if keys_by_miss[miss].size() < 3:
						keys_by_miss[miss].append(key)
	var misses: Array[String] = []
	for miss: String in keys_by_miss:
		misses.append("%s in %s" % [miss, ", ".join(keys_by_miss[miss])])
	return misses


## English, every locale with a translated cell, and the pseudo-locale.
func _glyph_locales() -> Array[String]:
	var locales: Array[String] = _filled_locales()
	locales.append(Localization.PSEUDO_LOCALE)
	return locales


## What [param locale] shows for [param key]: the pseudo-locale stretches the
## English the way the game does.
func _shown_text(table: LocTable, key: String, locale: String) -> String:
	if locale == Localization.PSEUDO_LOCALE:
		if _pseudo == null:
			_pseudo = _PseudoTranslation.new()
		return str(_pseudo.call(&"stretch", LocTable.unescape(table.english(key))))
	return LocTable.unescape(table.cell(key, locale))


## English, plus every locale with at least one translated cell.
func _filled_locales() -> Array[String]:
	var found: Array[String] = [LocTable.SOURCE_COLUMN]
	for table: LocTable in _tables:
		for locale: String in table.locales():
			if locale in found:
				continue
			for key: String in table.keys():
				if not table.cell(key, locale).is_empty():
					found.append(locale)
					break
	return found
