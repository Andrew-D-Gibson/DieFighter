class_name LocAuditReport
extends RefCounted
## Writes the localization audit's report: one HTML page with a section per
## locale (flagged items first, each photo beside its English) and a JSON file
## beside it with the same findings, for tools to read.

const _KIND_NAMES: Dictionary[String, String] = {
	OverflowWatcher.HEIGHT: "too tall",
	OverflowWatcher.WIDTH: "too wide",
	OverflowWatcher.HIDDEN_CHARACTERS: "characters hidden",
	OverflowWatcher.OFF_SCREEN: "off screen",
	OverflowWatcher.OUTSIDE_PARENT: "outside its button/panel",
	OverflowWatcher.OVERLAP: "buttons overlap",
	OverflowWatcher.MISSING_GLYPHS: "missing glyphs",
}

const _STYLE: String = """
:root { color-scheme: dark; --bg: #0d0b17; --card: #1b1828; --ink: #e8e4dc; --muted: #9a95a8; --bad: #ff4d5e; --warn: #f2b84b; }
body { background: var(--bg); color: var(--ink); font: 14px/1.4 system-ui, sans-serif; margin: 0 16px 48px; }
h1 { margin: 20px 0 4px; } h2 { margin: 32px 0 6px; border-bottom: 1px solid #333; padding-bottom: 4px; }
h3 { color: var(--muted); font-weight: 600; margin: 18px 0 6px; }
nav a, .muted { color: var(--muted); } nav a { margin-right: 12px; }
.summary { color: var(--muted); margin-bottom: 8px; }
.flagged { display: grid; gap: 12px; }
.card { background: var(--card); border-radius: 6px; padding: 10px; }
.card .pair { display: flex; gap: 10px; flex-wrap: wrap; align-items: flex-start; }
.card figure { margin: 0; } .card figcaption { color: var(--muted); font-size: 12px; }
.card img { max-width: min(720px, 100%); image-rendering: pixelated; border: 1px solid #333; }
.flag { margin: 2px 0; font-family: ui-monospace, monospace; font-size: 12px; }
.flag .kind { color: var(--bad); } .flag.glyph .kind { color: var(--warn); }
.sheet { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 8px; }
.sheet a { display: block; background: var(--card); border-radius: 4px; padding: 4px; color: var(--muted); font-size: 11px; text-decoration: none; overflow: hidden; }
.sheet img { width: 100%; height: 110px; object-fit: contain; image-rendering: pixelated; display: block; }
"""


## Writes [param path] (and the JSON beside it) from [param results],
## locale -> records as LocAudit builds them, in [param surfaces]' order.
## [param skipped] are the locales with nothing translated yet. Returns
## [param path].
static func write(path: String, results: Dictionary, surfaces: Array[LocAuditSurface],
		skipped: Array[String] = []) -> String:
	var html: PackedStringArray = []
	html.append("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">")
	html.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
	html.append("<title>Localization audit</title><style>%s</style></head><body>" % _STYLE)
	html.append("<h1>Localization audit</h1>")
	html.append("<p class=\"summary\">%s. Red: text that doesn't fit its box or is cut short. Amber: characters the font has no glyph for (expected for languages whose font isn't chosen yet).</p>"
		% Time.get_datetime_string_from_system(false, true))
	var nav: PackedStringArray = []
	for locale: String in results:
		nav.append("<a href=\"#%s\">%s</a>" % [locale, _escape(locale)])
	html.append("<nav>%s</nav>" % " ".join(nav))
	if not skipped.is_empty():
		html.append("<p class=\"summary\">No translations yet, skipped: %s.</p>" % _escape(", ".join(skipped)))

	var english: Dictionary[String, String] = _images_by_item(results.get("en", []))
	for locale: String in results:
		html.append(_locale_section(locale, results[locale], english, surfaces))
	html.append("</body></html>")

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(html))
	var data: FileAccess = FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	if data:
		data.store_string(JSON.stringify({"results": results, "no_translations": skipped}, "\t"))
	return path


## How many records in [param records] have a flag of a kind in [param kinds]
## (any kind for an empty list).
static func count_flagged(records: Array, kinds: Array[String] = []) -> int:
	var count: int = 0
	for record: Dictionary in records:
		for flag: Dictionary in record["flags"]:
			if _has_kind(flag, kinds):
				count += 1
				break
	return count


static func _locale_section(locale: String, records: Array, english: Dictionary[String, String],
		surfaces: Array[LocAuditSurface]) -> String:
	var out: PackedStringArray = []
	var overflow_kinds: Array[String] = [OverflowWatcher.HEIGHT, OverflowWatcher.WIDTH,
		OverflowWatcher.HIDDEN_CHARACTERS, OverflowWatcher.OFF_SCREEN, OverflowWatcher.OUTSIDE_PARENT,
		OverflowWatcher.OVERLAP]
	out.append("<h2 id=\"%s\">%s</h2>" % [locale, _escape(locale)])
	var untranslated: int = records.filter(_is_untranslated).size()
	out.append("<p class=\"summary\">%d items, %d translated; %d with text that doesn't fit; %d with missing glyphs.</p>" % [
		records.size(), records.size() - untranslated, count_flagged(records, overflow_kinds),
		count_flagged(records, [OverflowWatcher.MISSING_GLYPHS])])

	# Overflow first, then items whose only problem is glyphs.
	var flagged: Array = records.filter(func(r: Dictionary) -> bool: return not r["flags"].is_empty())
	flagged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return count_flagged([a], overflow_kinds) > count_flagged([b], overflow_kinds))
	if not flagged.is_empty():
		out.append("<h3>Flagged</h3><div class=\"flagged\">")
		for record: Dictionary in flagged:
			out.append(_card(locale, record, english))
		out.append("</div>")

	for surface: LocAuditSurface in surfaces:
		var of_surface: Array = records.filter(func(r: Dictionary) -> bool: return r["surface"] == surface.id)
		if of_surface.is_empty():
			continue
		var shown: Array = of_surface.filter(func(r: Dictionary) -> bool: return not _is_untranslated(r))
		var heading: String = _escape(surface.title)
		if shown.size() < of_surface.size():
			heading += " <span class=\"muted\">· %d untranslated</span>" % (of_surface.size() - shown.size())
		out.append("<h3>%s</h3>" % heading)
		if shown.is_empty():
			continue
		out.append("<div class=\"sheet\">")
		for record: Dictionary in shown:
			var label: String = _escape(record["label"])
			if record["image"] != "":
				out.append("<a href=\"%s\" title=\"%s\"><img loading=\"lazy\" src=\"%s\" alt=\"%s\">%s</a>"
					% [record["image"], label, record["image"], label, label])
			else:
				out.append("<a title=\"%s\">%s%s</a>" % [label, label, " (flagged)" if not record["flags"].is_empty() else ""])
		out.append("</div>")
	return "\n".join(out)


static func _card(locale: String, record: Dictionary, english: Dictionary[String, String]) -> String:
	var out: PackedStringArray = []
	out.append("<div class=\"card\"><strong>%s</strong> <span class=\"muted\">%s / %s</span>" % [
		_escape(record["label"]), record["surface"], record["id"]])
	out.append("<div class=\"pair\">")
	if record["image"] != "":
		out.append("<figure><a href=\"%s\"><img src=\"%s\" alt=\"\"></a><figcaption>%s</figcaption></figure>"
			% [record["image"], record["image"], _escape(locale)])
	var key: String = "%s/%s" % [record["surface"], record["id"]]
	if locale != "en" and english.get(key, "") != "":
		out.append("<figure><a href=\"%s\"><img src=\"%s\" alt=\"\"></a><figcaption>en</figcaption></figure>"
			% [english[key], english[key]])
	out.append("</div>")
	for flag: Dictionary in record["flags"]:
		for problem: Dictionary in flag["problems"]:
			var glyph: bool = problem["kind"] == OverflowWatcher.MISSING_GLYPHS
			out.append("<div class=\"flag%s\"><span class=\"kind\">%s</span> %s · %s · key %s · “%s”</div>" % [
				" glyph" if glyph else "", _KIND_NAMES.get(problem["kind"], problem["kind"]),
				_escape(problem["detail"]), _escape(_short_path(flag["path"])),
				_escape(flag["key"]) if flag["key"] != "" else "?",
				_escape(str(flag["text"]).replace("\n", " ").left(80))])
	out.append("</div>")
	return "\n".join(out)


## An item that reads exactly as it does in English: counted, not shown.
static func _is_untranslated(record: Dictionary) -> bool:
	return record.get("untranslated", false)


static func _has_kind(flag: Dictionary, kinds: Array[String]) -> bool:
	for problem: Dictionary in flag["problems"]:
		if kinds.is_empty() or problem["kind"] in kinds:
			return true
	return false


static func _images_by_item(records: Array) -> Dictionary[String, String]:
	var images: Dictionary[String, String] = {}
	for record: Dictionary in records:
		images["%s/%s" % [record["surface"], record["id"]]] = record["image"]
	return images


## The node path from the stage down, which is all that says where it is.
static func _short_path(path: String) -> String:
	var at: int = path.find("/SubViewport/")
	return path.substr(at + 13) if at >= 0 else path


static func _escape(text: String) -> String:
	return text.xml_escape(true)
