extends "res://test/helpers/die_fighter_test.gd"
## The translation lint (tools/loc.sh lint): content text has reached
## content.csv, and every translation in either CSV keeps what the game
## parses (placeholders, tokens, BBCode), fits its length limit and can be
## drawn by its locale's font.

const UI_CSV: String = LocPipeline.UI_CSV
const CONTENT_CSV: String = ContentText.CSV_PATH

## Matches what Utils.format_text turns into icons or keywords, and BBCode,
## none of which is drawn as letters.
var _not_letters: RegEx = RegEx.create_from_string(r"\[[^\]]*\]|\([a-z_0-9=.]+\)|\{[^}]*\}|%[-+0-9.]*[a-zA-Z]")

var _tables: Array[LocTable] = []


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


func test_no_key_is_in_both_csvs() -> void:
	var ui: LocTable = _tables[0]
	var clashes: Array[String] = []
	for key: String in _tables[1].keys():
		if ui.has(key):
			clashes.append(key)
	assert_eq(clashes, [] as Array[String])


## A letter the locale's font lacks draws as a box (or in a fallback font).
## Until the per-locale font profiles exist (localization plan Phase 4, LF2)
## this only reports: English is checked against the default theme font,
## which most but not all labels use, and other locales have no font yet.
## Once LF2 lands, missing glyphs should fail here.
func test_every_character_has_a_glyph() -> void:
	var missing: Array[String] = []
	var unchecked: Array[String] = []
	for locale: String in _filled_locales():
		var font: Font = _font_for(locale)
		if font == null:
			unchecked.append(locale)
			continue
		for table: LocTable in _tables:
			for key: String in table.keys():
				var text: String = LocTable.unescape(table.cell(key, locale))
				for character: String in _not_letters.sub(text, "", true):
					if character.strip_edges().is_empty():
						continue
					if not font.has_char(character.unicode_at(0)):
						missing.append("%s [%s]: no glyph for '%s' (U+%04X)" % [key, locale, character, character.unicode_at(0)])
	var report: PackedStringArray = []
	if not unchecked.is_empty():
		report.append("no font chosen yet for %s; glyphs unchecked" % ", ".join(unchecked))
	report.append_array(missing)
	if report.is_empty():
		pass_test("every character has a glyph")
	else:
		pending("\n".join(report))


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


## The font [param locale]'s text is drawn in. Only English has one so far;
## the per-locale font profiles (LF2) take over here.
func _font_for(locale: String) -> Font:
	if locale == LocTable.SOURCE_COLUMN:
		return load(ProjectSettings.get_setting("gui/theme/custom_font")) as Font
	return null
