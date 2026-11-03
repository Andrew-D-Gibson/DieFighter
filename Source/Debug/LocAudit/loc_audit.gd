class_name LocAudit
extends Node
## "Check everything in every language": for each locale, poses every text
## surface the game has (LocAuditSurfaces), runs the overflow watcher over it,
## photographs it, and writes user://loc_audit/report.html, a contact sheet
## per locale with flagged items first, each beside its English. Items a
## locale hasn't translated (their text reads exactly as in English) are only
## counted, and a locale with nothing translated at all is skipped.
##
## It runs in a process of its own (loc_audit_cli.gd), started by
## tools/loc.sh audit or the dev console's loc_audit, so a game in progress is
## left alone and the game's MCP port is never opened. A headless run draws
## nothing, so it writes the flags without photos.

signal finished(report_path: String)

const OUTPUT_DIR: String = "user://loc_audit"
const REPORT_PATH: String = OUTPUT_DIR + "/report.html"
const CLI_SCRIPT: String = "res://Source/Debug/LocAudit/loc_audit_cli.gd"
## The pseudo-locale's name on the command line and in the report's folders.
const PSEUDO: String = "pseudo"
## Joins a text locale to the locale whose font profile draws it:
## "pseudo@de" is pseudo text in German's fonts. No language has translations
## yet, so this is how a font profile meets long text before one does.
const FONTS_SEPARATOR: String = "@"
## Requests en plus pseudo text in every distinct font profile.
const FONTS: String = "fonts"
## Game speed while posing: the info panel's art takes half a second to zoom
## into place, and nothing posed here needs watching.
const _FAST_SCALE: float = 40.0
const _UI_TRANSLATION: String = "res://Localization/translations.%s.translation"
const _CONTENT_TRANSLATION: String = "res://Localization/content.%s.translation"

var _stage: LocAuditStage
var _watcher: OverflowWatcher
## Each item's text in English ("surface/id" -> every label's text in order),
## to tell which items another locale actually translates.
var _english_text: Dictionary[String, String] = {}


## The locales [param requested] names: one locale, "pseudo", "all"
## (every language the game knows, shipped or previewed, plus pseudo; run()
## skips those with nothing translated yet), "fonts" (pseudo text in each
## distinct font profile, see font_profile_locales()), or "<text>@<fonts>",
## e.g. "pseudo@zh_CN". English always comes first, as everything else is
## compared with it.
static func locales_for(requested: String) -> Array[String]:
	var locales: Array[String] = ["en"]
	if requested == FONTS:
		for fonts: String in font_profile_locales():
			locales.append(PSEUDO if fonts == Localization.PSEUDO_LOCALE else PSEUDO + FONTS_SEPARATOR + fonts)
	elif requested == "all":
		var known: Array[String] = Localization.get_available_locales()
		known.append_array(Localization.get_preview_locales())
		for locale: String in known:
			var name: String = PSEUDO if locale == Localization.PSEUDO_LOCALE else locale
			if name not in locales:
				locales.append(name)
		if PSEUDO not in locales:
			locales.append(PSEUDO)
	elif requested != "" and requested != "en":
		locales.append(requested)
	return locales


## One locale per distinct font profile (locales whose profiles name the
## same faces share one), pseudo's own first: the fonts a "fonts" audit
## dresses pseudo text in.
static func font_profile_locales() -> Array[String]:
	var found: Array[String] = [Localization.PSEUDO_LOCALE]
	var seen: Array[String] = [_faces_of(FontRoles.profile_for(Localization.PSEUDO_LOCALE))]
	var known: Array[String] = Localization.get_available_locales()
	known.append_array(Localization.get_preview_locales())
	for locale: String in Localization.LOCALE_NAMES:
		if locale not in known:
			known.append(locale)
	for locale: String in known:
		var faces: String = _faces_of(FontRoles.profile_for(locale))
		if faces not in seen:
			seen.append(faces)
			found.append(locale)
	return found


static func _faces_of(profile: FontProfile) -> String:
	var paths: PackedStringArray = []
	for role: StringName in FontRoles.ROLES:
		paths.append(profile.face(role).resource_path)
	return ",".join(paths)


## Whether [param locale] has any text translated yet. Every planned
## language has (empty) translation files long before it does, and auditing
## one of those would only photograph the English again.
static func has_translations(locale: String) -> bool:
	for path: String in [_UI_TRANSLATION % locale, _CONTENT_TRANSLATION % locale]:
		if ResourceLoader.exists(path):
			var translation: Translation = load(path)
			if translation and translation.get_message_count() > 0:
				return true
	return false


## Starts the audit in a separate process, the same run tools/loc.sh audit
## makes, and returns its process id (-1 if it couldn't start).
static func launch(requested: String) -> int:
	var args: PackedStringArray = [
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", CLI_SCRIPT, "--", requested,
	]
	return OS.create_process(OS.get_executable_path(), args)


## Audits [param locales] across [param surfaces] (all of them if empty) and
## writes the report. Returns the report's path.
func run(locales: Array[String], surfaces: Array[LocAuditSurface] = []) -> String:
	if surfaces.is_empty():
		surfaces = LocAuditSurfaces.all()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_stage = LocAuditStage.new()
	add_child(_stage)
	# The game's own watcher would outline the stage on its own schedule.
	if Localization.overflow_watcher:
		Localization.overflow_watcher.live = false
		Localization.overflow_watcher.clear_outlines()
	_watcher = OverflowWatcher.new()
	_watcher.live = false
	add_child(_watcher)
	await _stage.settle(2)

	var start_locale: String = TranslationServer.get_locale()
	var start_scale: float = TimeDirector.base_scale
	var results: Dictionary[String, Array] = {}
	var skipped: Array[String] = []
	for locale: String in locales:
		# A language with nothing translated would only show the English
		# again, item by item.
		if locale != "en" and _text_locale(locale) != PSEUDO and not has_translations(_text_locale(locale)):
			skipped.append(locale)
			_say("%s: no translations yet; skipped" % locale)
			continue
		if not _switch_locale(locale):
			push_warning("loc_audit: no translation for %s; skipped" % locale)
			continue
		await _stage.settle(2)
		# Last run's photos would otherwise linger beside this run's.
		_remove_tree(OUTPUT_DIR.path_join(locale))
		results[locale] = await _audit_locale(locale, surfaces)
		_say("%s: %d items, %d untranslated, %d flagged" % [locale, results[locale].size(),
			results[locale].filter(func(r: Dictionary) -> bool: return r["untranslated"]).size(),
			results[locale].filter(func(r: Dictionary) -> bool: return not r["flags"].is_empty()).size()])

	TimeDirector.set_base_scale(start_scale)
	Localization.set_locale(start_locale, true)
	var report: String = LocAuditReport.write(REPORT_PATH, results, surfaces, skipped)
	_say("report: %s" % ProjectSettings.globalize_path(report))
	finished.emit(report)
	return report


func _audit_locale(locale: String, surfaces: Array[LocAuditSurface]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for surface: LocAuditSurface in surfaces:
		var items: Array[Dictionary] = surface.items()
		_say("%s: %s (%d)" % [locale, surface.id, items.size()])
		TimeDirector.set_base_scale(_FAST_SCALE if surface.fast else 1.0)
		await surface.setup(_stage)
		await _stage.settle(4)
		for item: Dictionary in items:
			records.append(await _audit_item(locale, surface, item))
			surface.unpose(item, _stage)
		_stage.clear()
		await _stage.settle(2)
	return records


func _audit_item(locale: String, surface: LocAuditSurface, item: Dictionary) -> Dictionary:
	await surface.pose(item, _stage)
	# Tweens finish (fast) and containers lay out.
	await _stage.settle(6 if surface.fast else 3)
	var subject: Node = surface.subject(_stage, item)
	var record: Dictionary = {
		"surface": surface.id,
		"id": str(item["id"]),
		"label": str(item["label"]),
		"image": "",
		"flags": [],
		"untranslated": false,
	}
	# English is checked and photographed once; an item that reads exactly
	# as it does in English is only counted.
	var item_key: String = "%s/%s" % [surface.id, item["id"]]
	var text: String = _text_of(subject) if is_instance_valid(subject) else ""
	if locale == "en":
		_english_text[item_key] = text
	elif _english_text.get(item_key, "") == text:
		record["untranslated"] = true
		return record
	var flags: Array[Dictionary] = []
	if is_instance_valid(subject):
		flags = _watcher.scan(subject)
	# The outlines are drawn on the next frame, which the photo waits for.
	await _stage.settle(1)
	var image_path: String = ""
	var image: Image = await _stage.photograph(subject if is_instance_valid(subject) else _stage.viewport)
	if image:
		var relative: String = "%s/%s/%s.png" % [locale, surface.id, str(item["id"]).validate_filename()]
		var absolute: String = OUTPUT_DIR.path_join(relative)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		if image.save_png(absolute) == OK:
			image_path = relative
	_watcher.clear_outlines()
	record["image"] = image_path
	record["flags"] = flags
	return record


## Every visible label's text under [param subject], in tree order.
static func _text_of(subject: Node) -> String:
	var texts: PackedStringArray = []
	for type: String in ["Label", "RichTextLabel"]:
		for node: Node in subject.find_children("*", type, true, false):
			if (node as CanvasItem).is_visible_in_tree():
				texts.append(OverflowWatcher.shown_text(node as Control))
	return "\u001f".join(texts)


## Switches the game to [param locale] (a code, "pseudo", or
## "<text>@<fonts>"); false if this build has no translation for it.
func _switch_locale(locale: String) -> bool:
	var text_locale: String = _text_locale(locale)
	var code: String = Localization.PSEUDO_LOCALE if text_locale == PSEUDO else text_locale
	var offered: Array[String] = Localization.get_available_locales()
	offered.append_array(Localization.get_preview_locales())
	if code not in offered and code != "en":
		return false
	Localization.set_locale(code, true)
	if locale.contains(FONTS_SEPARATOR):
		FontRoles.use_locale(locale.get_slice(FONTS_SEPARATOR, 1))
	return TranslationServer.get_locale() == code


## The locale whose text [param locale] shows: "pseudo" for "pseudo@de".
static func _text_locale(locale: String) -> String:
	return locale.get_slice(FONTS_SEPARATOR, 0)


static func _remove_tree(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _say(line: String) -> void:
	print("loc_audit: " + line)
