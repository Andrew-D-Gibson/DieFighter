extends "res://test/helpers/die_fighter_test.gd"
## OverflowWatcher flags text that doesn't fit its box, is cut off by the
## screen, is stuck half typed, or uses characters its font lacks; and the
## localization audit's report lists flagged items first.

const _FONT: Font = preload("res://Assets/Fonts/Roles/body.tres")
const _LONG: String = "A sentence long enough to need several lines in a narrow box."
const _REPORT_PATH: String = "user://test_loc_audit/report.html"

var watcher: OverflowWatcher


func before_each() -> void:
	super()
	watcher = OverflowWatcher.new()
	watcher.live = false
	add_child_autofree(watcher)


func _label(text: String, box: Vector2) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override(&"font", _FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.text = text
	label.clip_text = true
	label.position = Vector2(100, 100)
	add_child_autofree(label)
	label.size = box
	return label


func _rich(text: String, box: Vector2) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.add_theme_font_override(&"normal_font", _FONT)
	label.add_theme_font_size_override(&"normal_font_size", 16)
	label.scroll_active = false
	label.text = text
	label.position = Vector2(100, 100)
	add_child_autofree(label)
	label.size = box
	return label


func _kinds(problems: Array[Dictionary]) -> Array[String]:
	var kinds: Array[String] = []
	for problem: Dictionary in problems:
		kinds.append(str(problem["kind"]))
	return kinds


func test_text_that_fits_is_not_flagged() -> void:
	var label: Label = _label("Fits", Vector2(200, 40))
	await wait_process_frames(2)
	assert_eq(OverflowWatcher.inspect(label), [] as Array[Dictionary])


func test_unwrapped_label_wider_than_its_box_is_flagged() -> void:
	var label: Label = _label(_LONG, Vector2(60, 40))
	await wait_process_frames(2)
	assert_has(_kinds(OverflowWatcher.inspect(label)), OverflowWatcher.WIDTH)


func test_rich_text_taller_than_its_box_is_flagged() -> void:
	var label: RichTextLabel = _rich(_LONG + " " + _LONG, Vector2(80, 14))
	await wait_process_frames(2)
	assert_has(_kinds(OverflowWatcher.inspect(label)), OverflowWatcher.HEIGHT)


func test_rich_text_that_scrolls_is_not_flagged_for_height() -> void:
	var label: RichTextLabel = _rich(_LONG + " " + _LONG, Vector2(80, 14))
	label.scroll_active = true
	await wait_process_frames(2)
	assert_does_not_have(_kinds(OverflowWatcher.inspect(label)), OverflowWatcher.HEIGHT)


func test_hidden_characters_are_reported() -> void:
	var label: RichTextLabel = _rich("Typing", Vector2(200, 40))
	label.visible_characters = 3
	await wait_process_frames(2)
	assert_has(_kinds(OverflowWatcher.inspect(label)), OverflowWatcher.HIDDEN_CHARACTERS)


func test_missing_glyphs_lists_each_absent_character_once() -> void:
	# The English body face (m5x7, monogram behind it) has no Chinese.
	assert_eq(OverflowWatcher.missing_glyphs("Soon你 soon你", _FONT), "你")
	assert_eq(OverflowWatcher.missing_glyphs("Plain text\n", _FONT), "")


func test_ignored_labels_are_skipped() -> void:
	var label: Label = _label(_LONG, Vector2(60, 40))
	label.set_meta(OverflowWatcher.IGNORE_META, true)
	await wait_process_frames(2)
	assert_eq(OverflowWatcher.inspect(label), [] as Array[Dictionary])


func test_scan_outlines_a_flagged_label_and_clears_it_once_fixed() -> void:
	var label: Label = _label(_LONG, Vector2(60, 40))
	await wait_process_frames(2)
	var found: Array[Dictionary] = watcher.scan(label)
	assert_eq(found.size(), 1)
	assert_not_null(label.get_node_or_null(^"LocOverflowOutline"), "outlined")

	label.text = "Ok"
	await wait_process_frames(2)
	assert_eq(watcher.scan(label).size(), 0)
	await wait_process_frames(1)
	assert_null(label.get_node_or_null(^"LocOverflowOutline"), "outline removed")


func test_scan_flags_a_label_cut_by_the_screen_edge() -> void:
	var label: Label = _label("Edge", Vector2(80, 20))
	label.position = Vector2(-10, 100)
	await wait_process_frames(2)
	var found: Array[Dictionary] = watcher.scan(label)
	assert_eq(found.size(), 1)
	assert_has(_kinds(found[0]["problems"]), OverflowWatcher.OFF_SCREEN)


## Live, a label still sliding in is judged once it stops, and one faded
## out entirely isn't judged at all: the lead's live pass saw main-menu
## buttons and enemy labels logged off screen mid-entrance.
func test_live_scan_waits_for_a_moving_label_to_settle() -> void:
	watcher.live = true
	watcher.set_process(false)
	var label: Label = _label("Edge", Vector2(80, 20))
	label.position = Vector2(-10, 100)
	await wait_process_frames(2)
	assert_eq(watcher.scan(label).size(), 0, "first sight: it may be on its way in")
	label.position = Vector2(-5, 100)
	assert_eq(watcher.scan(label).size(), 0, "still moving")
	assert_eq(watcher.scan(label).size(), 1, "stopped, and still cut by the edge")


func test_scan_skips_a_label_faded_out() -> void:
	var holder: Control = Control.new()
	holder.modulate.a = 0.0
	add_child_autofree(holder)
	var label: Label = _label(_LONG, Vector2(60, 40))
	label.reparent(holder)
	await wait_process_frames(2)
	assert_eq(watcher.scan(holder).size(), 0, "invisible")
	holder.modulate.a = 1.0
	assert_eq(watcher.scan(holder).size(), 1, "faded in")


func test_scan_names_the_key_an_auto_translated_label_holds() -> void:
	var label: Label = _label("CALLOUT_EVADED", Vector2(4, 20))
	await wait_process_frames(2)
	var found: Array[Dictionary] = watcher.scan(label)
	assert_eq(found.size(), 1)
	assert_eq(found[0]["key"], "CALLOUT_EVADED")


func test_audit_always_starts_with_english() -> void:
	assert_eq(LocAudit.locales_for("pseudo"), ["en", "pseudo"] as Array[String])
	assert_eq(LocAudit.locales_for("en"), ["en"] as Array[String])
	var every: Array[String] = LocAudit.locales_for("all")
	assert_eq(every[0], "en")
	assert_has(every, "pseudo")


## "fonts" dresses pseudo text in each distinct font profile once: German's
## stands for the other Tiny5 languages, and Chinese and Japanese each get
## their own.
func test_a_fonts_audit_covers_each_distinct_profile_once() -> void:
	var fonts: Array[String] = LocAudit.locales_for(LocAudit.FONTS)
	assert_eq(fonts[0], "en")
	assert_eq(fonts[1], "pseudo")
	assert_has(fonts, "pseudo@zh_CN")
	assert_has(fonts, "pseudo@ja")
	var tiny5: Array[String] = fonts.filter(func(name: String) -> bool:
		return name.get_slice("@", 1) in ["de", "fr", "es", "pt_BR", "ru"])
	assert_eq(tiny5.size(), 1, "one Tiny5 profile: %s" % [fonts])


func test_every_surface_has_an_id_and_items() -> void:
	var ids: Array[String] = []
	for surface: LocAuditSurface in LocAuditSurfaces.all():
		assert_ne(surface.id, "", "surface id")
		assert_does_not_have(ids, surface.id, "unique id")
		ids.append(surface.id)
		assert_gt(surface.items().size(), 0, "%s has items" % surface.id)


func test_report_lists_flagged_items_first_and_counts_untranslated() -> void:
	var flag: Dictionary = {
		"path": "/root/LocAudit/SubViewport/UI/Label", "key": "SOME_KEY", "text": "Too long",
		"problems": [{"kind": OverflowWatcher.WIDTH, "detail": "90 px in 60"}],
	}
	var results: Dictionary = {
		"en": [
			{"surface": "tiles", "id": "fine", "label": "Fine", "image": "en/tiles/fine.png", "flags": []},
			{"surface": "tiles", "id": "long", "label": "Long", "image": "en/tiles/long.png", "flags": []},
		],
		"pseudo": [
			{"surface": "tiles", "id": "fine", "label": "Fine", "image": "pseudo/tiles/fine.png", "flags": []},
			{"surface": "tiles", "id": "long", "label": "Long", "image": "pseudo/tiles/long.png", "flags": [flag]},
			{"surface": "tiles", "id": "same", "label": "Same", "image": "", "flags": [], "untranslated": true},
		],
	}
	var surfaces: Array[LocAuditSurface] = LocAuditSurfaces.named(PackedStringArray(["tiles"]))
	LocAuditReport.write(_REPORT_PATH, results, surfaces, ["de"] as Array[String])
	var html: String = FileAccess.get_file_as_string(_REPORT_PATH)
	var pseudo_at: int = html.find("id=\"pseudo\"")
	var card_at: int = html.find("class=\"card\"", pseudo_at)
	assert_gt(card_at, pseudo_at, "flagged card in the pseudo section")
	assert_lt(card_at, html.find("class=\"sheet\"", pseudo_at), "flagged before the contact sheet")
	assert_gt(html.find("en/tiles/long.png", card_at), card_at, "English beside it")
	assert_string_contains(html, "SOME_KEY")
	assert_string_contains(html, "1 untranslated")
	assert_string_contains(html, "No translations yet, skipped: de")
	assert_false(html.contains(">Same</a>"), "untranslated item not on the sheet")
	assert_eq(LocAuditReport.count_flagged(results["pseudo"]), 1)
	assert_true(FileAccess.file_exists("user://test_loc_audit/report.json"))
	DirAccess.remove_absolute(_REPORT_PATH)
	DirAccess.remove_absolute("user://test_loc_audit/report.json")
	DirAccess.remove_absolute("user://test_loc_audit")


func test_scan_flags_buttons_whose_neighbour_overlaps_them() -> void:
	var row: Control = Control.new()
	add_child_autofree(row)
	var labels: Array[Label] = []
	for x: float in [100.0, 130.0]:
		var button: Button = Button.new()
		button.position = Vector2(x, 100)
		row.add_child(button)
		button.size = Vector2(40, 20)
		var label: Label = Label.new()
		label.text = "Tab"
		button.add_child(label)
		label.size = Vector2(30, 16)
		labels.append(label)
	await wait_process_frames(2)
	var found: Array[Dictionary] = watcher.scan(row)
	assert_eq(found.size(), 2)
	assert_has(_kinds(found[0]["problems"]), OverflowWatcher.OVERLAP)
