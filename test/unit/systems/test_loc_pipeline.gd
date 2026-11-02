extends "res://test/helpers/die_fighter_test.gd"
## The translation round trip on throwaway CSVs: sync the English in, notice
## when it changes, export what a locale needs, and import the translations
## back. (test_content_text covers reading them in the game.)

const DIR: String = "user://test_loc_pipeline"

var pipeline: LocPipeline


func before_each() -> void:
	super()
	DirAccess.make_dir_recursive_absolute(DIR)
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	_write(DIR.path_join("translations.csv"),
		"keys,en,de,_context,_max_chars,_status,_en_hash\n" +
		"UI_HELLO,Hello,,a greeting,,,\n" +
		"UI_DONE,\"Done, {n} left\",\"Fertig, {n} übrig\",hand-written row,,machine,\n")
	pipeline = LocPipeline.new()
	pipeline.ui_path = DIR.path_join("translations.csv")
	pipeline.content_path = DIR.path_join("content.csv")
	pipeline.pending_dir = DIR.path_join("pending")


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


func _catalog(texts: Dictionary) -> LocCatalog:
	var catalog: LocCatalog = LocCatalog.new()
	for key: String in texts:
		var entry: LocCatalog.Entry = LocCatalog.Entry.new()
		entry.key = key
		entry.english = texts[key]
		entry.context = "generated note"
		entry.max_chars = 12 if key.ends_with("BANNER") else 0
		entry.source_path = "res://fake.tres"
		catalog.entries[key] = entry
	return catalog


func _content() -> LocTable:
	return LocTable.read(pipeline.content_path)


# ── Sync ─────────────────────────────────────────────────────────────────────

func test_sync_writes_english_sorted_with_hashes_and_notes() -> void:
	assert_true(pipeline.sync(_catalog({"HAZARD.B.NAME": "Bee", "HAZARD.A.BANNER": "AY!"})))
	var content: LocTable = _content()
	assert_eq(content.keys(), ["HAZARD.A.BANNER", "HAZARD.B.NAME"] as Array[String])
	assert_eq(content.columns, LocTable.read(pipeline.ui_path).columns, "same columns as translations.csv")
	assert_eq(content.english("HAZARD.B.NAME"), "Bee")
	assert_eq(content.cell("HAZARD.B.NAME", LocTable.HASH_COLUMN), LocTable.hash_of("Bee"))
	assert_eq(content.cell("HAZARD.A.BANNER", LocTable.CONTEXT_COLUMN), "generated note")
	assert_eq(content.cell("HAZARD.A.BANNER", LocTable.MAX_CHARS_COLUMN), "12")


func test_line_breaks_travel_escaped_one_row_per_line() -> void:
	pipeline.sync(_catalog({"HAZARD.A.DESC": "Line one\nline two"}))
	var csv: String = FileAccess.get_file_as_string(pipeline.content_path)
	assert_string_contains(csv, "Line one\\nline two")
	assert_eq(_content().english("HAZARD.A.DESC"), "Line one\nline two")


func test_changed_english_marks_translations_stale_and_keeps_them() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Old"}))
	var content: LocTable = _content()
	content.set_cell("HAZARD.A.NAME", "de", "Alt")
	content.set_status("HAZARD.A.NAME", "de", LocTable.REVIEWED)
	content.save()

	pipeline.sync(_catalog({"HAZARD.A.NAME": "New"}))
	content = _content()
	assert_eq(content.english("HAZARD.A.NAME"), "New")
	assert_eq(content.cell("HAZARD.A.NAME", "de"), "Alt")
	assert_eq(content.status_of("HAZARD.A.NAME", "de"), LocTable.STALE)


func test_unchanged_english_leaves_the_file_alone() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Same"}))
	var before: String = FileAccess.get_file_as_string(pipeline.content_path)
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Same"}))
	assert_eq(FileAccess.get_file_as_string(pipeline.content_path), before)


func test_a_hand_written_note_survives_a_sync() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	var content: LocTable = _content()
	content.set_cell("HAZARD.A.NAME", LocTable.CONTEXT_COLUMN, "a better note")
	content.save()
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	assert_eq(_content().cell("HAZARD.A.NAME", LocTable.CONTEXT_COLUMN), "a better note")


func test_orphans_are_reported_not_deleted() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay", "HAZARD.GONE.NAME": "Gone"}))
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	assert_true(_content().has("HAZARD.GONE.NAME"))
	assert_true(Array(pipeline.messages).any(func(line: String) -> bool:
		return line.begins_with("orphan") and line.contains("HAZARD.GONE.NAME")))


func test_a_moved_step_takes_its_translations_to_its_new_key() -> void:
	pipeline.sync(_catalog({"TILE.A.EFFECT_CHAIN.EFFECTS_2.CALLOUT": "HOLD", "TILE.A.NAME": "Ay"}))
	var content: LocTable = _content()
	content.set_cell("TILE.A.EFFECT_CHAIN.EFFECTS_2.CALLOUT", "de", "HALT")
	content.set_status("TILE.A.EFFECT_CHAIN.EFFECTS_2.CALLOUT", "de", LocTable.REVIEWED)
	content.save()

	# A step inserted before it: same file, same English, new index.
	pipeline.sync(_catalog({"TILE.A.EFFECT_CHAIN.EFFECTS_3.CALLOUT": "HOLD", "TILE.A.NAME": "Ay"}))
	content = _content()
	assert_false(content.has("TILE.A.EFFECT_CHAIN.EFFECTS_2.CALLOUT"), "no orphan left behind")
	assert_eq(content.cell("TILE.A.EFFECT_CHAIN.EFFECTS_3.CALLOUT", "de"), "HALT")
	assert_eq(content.status_of("TILE.A.EFFECT_CHAIN.EFFECTS_3.CALLOUT", "de"), LocTable.REVIEWED)
	assert_true(Array(pipeline.messages).any(func(line: String) -> bool: return line.begins_with("moved")))


func test_a_key_only_moves_on_a_one_to_one_match_in_the_same_file() -> void:
	pipeline.sync(_catalog({
		"TILE.A.EFFECTS_1.CALLOUT": "HOLD", "TILE.A.EFFECTS_2.CALLOUT": "HOLD", "TILE.B.EFFECTS_1.CALLOUT": "GO",
	}))
	# Two HOLDs became one new key: ambiguous. GO moved to another file: not
	# the same text's home.
	pipeline.sync(_catalog({"TILE.A.EFFECTS_5.CALLOUT": "HOLD", "TILE.C.EFFECTS_1.CALLOUT": "GO"}))
	var content: LocTable = _content()
	assert_true(content.has("TILE.A.EFFECTS_1.CALLOUT") and content.has("TILE.A.EFFECTS_2.CALLOUT"))
	assert_true(content.has("TILE.B.EFFECTS_1.CALLOUT"), "another file's row stays an orphan")


func test_a_key_clash_blocks_the_sync() -> void:
	var catalog: LocCatalog = _catalog({"HAZARD.A.NAME": "Ay"})
	catalog.problems.append("two files make HAZARD.A.NAME")
	assert_false(pipeline.sync(catalog))
	assert_false(FileAccess.file_exists(pipeline.content_path))


func test_check_reports_an_edit_that_was_not_synced() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	assert_eq(pipeline.out_of_date(_catalog({"HAZARD.A.NAME": "Ay"})), [] as Array[String])
	assert_eq(pipeline.out_of_date(_catalog({"HAZARD.A.NAME": "Edited"})).size(), 1)
	assert_eq(pipeline.out_of_date(_catalog({"HAZARD.A.NAME": "Ay", "HAZARD.NEW.NAME": "New"})).size(), 1)


# ── Export and import ────────────────────────────────────────────────────────

func test_round_trip_through_a_new_locale() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay", "HAZARD.A.BANNER": "AY!"}))
	assert_eq(pipeline.export_locale("xx"), 4, "two UI rows and two content rows")
	var exported: LocTable = LocTable.read(pipeline.pending_file("xx"))
	assert_eq(exported.status_of("HAZARD.A.NAME", "xx"), "", "nothing translated yet")
	assert_eq(exported.cell("HAZARD.A.NAME", LocTable.STATUS_COLUMN), LocTable.MISSING)
	assert_true(FileAccess.file_exists(pipeline.pending_dir.path_join(".gdignore")),
		"Godot mustn't import the hand-off file as a translation")

	# The translator fills some rows in and leaves the rest.
	exported.set_cell("HAZARD.A.NAME", "xx", "Ai")
	exported.set_cell("UI_DONE", "xx", "Fini, {n} restant")
	exported.save()
	assert_eq(pipeline.import_file(pipeline.pending_file("xx")), 2)

	var content: LocTable = _content()
	var ui: LocTable = LocTable.read(pipeline.ui_path)
	assert_true("xx" in content.columns and "xx" in ui.columns, "a new locale gets a column")
	assert_lt(ui.columns.find("xx"), ui.columns.find(LocTable.CONTEXT_COLUMN), "before the notes")
	assert_eq(content.cell("HAZARD.A.NAME", "xx"), "Ai")
	assert_eq(content.status_of("HAZARD.A.NAME", "xx"), LocTable.MACHINE)
	assert_eq(ui.cell("UI_DONE", "xx"), "Fini, {n} restant")
	assert_eq(ui.cell("UI_DONE", "de"), "Fertig, {n} übrig", "other locales untouched")
	assert_eq(ui.status_of("UI_DONE", "de"), LocTable.MACHINE)

	# What's left is what the next export asks for.
	assert_eq(pipeline.export_locale("xx"), 2)


func test_import_can_mark_rows_reviewed() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	pipeline.export_locale("de")
	var exported: LocTable = LocTable.read(pipeline.pending_file("de"))
	exported.set_cell("HAZARD.A.NAME", "de", "Ei")
	exported.save()
	pipeline.import_file(pipeline.pending_file("de"), LocTable.REVIEWED)
	assert_eq(_content().status_of("HAZARD.A.NAME", "de"), LocTable.REVIEWED)


func test_english_that_changed_since_the_export_imports_stale() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	pipeline.export_locale("de")
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay, edited"}))
	var exported: LocTable = LocTable.read(pipeline.pending_file("de"))
	exported.set_cell("HAZARD.A.NAME", "de", "Ei")
	exported.save()
	pipeline.import_file(pipeline.pending_file("de"))
	assert_eq(_content().status_of("HAZARD.A.NAME", "de"), LocTable.STALE)


func test_a_stale_row_exports_with_its_old_translation() -> void:
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	var content: LocTable = _content()
	content.set_cell("HAZARD.A.NAME", "de", "Ei")
	content.set_status("HAZARD.A.NAME", "de", LocTable.REVIEWED)
	content.save()
	assert_eq(pipeline.export_locale("de"), 1, "only UI_HELLO is missing")
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay!"}))
	assert_eq(pipeline.export_locale("de"), 2)
	var exported: LocTable = LocTable.read(pipeline.pending_file("de"))
	assert_eq(exported.cell("HAZARD.A.NAME", "de"), "Ei")
	assert_eq(exported.cell("HAZARD.A.NAME", LocTable.STATUS_COLUMN), LocTable.STALE)


func test_import_warns_about_a_lost_token_or_tag() -> void:
	pipeline.sync(_catalog({"HAZARD.A.DESC": "[color=red]Burn[/color] (die_3)"}))
	pipeline.export_locale("de")
	var exported: LocTable = LocTable.read(pipeline.pending_file("de"))
	exported.set_cell("HAZARD.A.DESC", "de", "[color=red]Brand (die_4)")
	exported.save()
	pipeline.import_file(pipeline.pending_file("de"))
	var warnings: Array = Array(pipeline.messages).filter(func(line: String) -> bool: return line.begins_with("warning"))
	assert_eq(warnings.size(), 2, "a token swapped, a tag never closed: " + "\n".join(PackedStringArray(warnings)))


func test_untouched_rows_keep_their_exact_lines() -> void:
	var original: String = FileAccess.get_file_as_string(pipeline.ui_path)
	pipeline.sync(_catalog({"HAZARD.A.NAME": "Ay"}))
	pipeline.export_locale("de")
	var exported: LocTable = LocTable.read(pipeline.pending_file("de"))
	exported.set_cell("UI_HELLO", "de", "Hallo")
	exported.save()
	pipeline.import_file(pipeline.pending_file("de"))
	var lines: PackedStringArray = FileAccess.get_file_as_string(pipeline.ui_path).split("\n")
	assert_eq(lines[2], original.split("\n")[2], "UI_DONE's quoting is left as written")
	assert_eq(lines[1], "UI_HELLO,Hello,Hallo,a greeting,,machine,")


# ── Lint helpers ─────────────────────────────────────────────────────────────

func test_parity_accepts_reordered_tokens() -> void:
	assert_eq(LocLint.parity_problems("{a} then {b} (die_1)", "(die_1) {b} dann {a}"), [] as Array[String])


func test_parity_catches_a_broken_tag() -> void:
	var problems: Array[String] = LocLint.parity_problems("[color=red]x[/color]", "[color=red]x[/colour]")
	assert_false(problems.is_empty())


func test_length_ignores_bbcode() -> void:
	assert_eq(LocLint.length_problem("[color=red]ABCDE[/color]", 5), "")
	assert_ne(LocLint.length_problem("ABCDEF", 5), "")
