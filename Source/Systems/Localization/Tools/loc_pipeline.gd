class_name LocPipeline
extends RefCounted
## The steps of the translation round trip, run by loc_sync.gd (and
## tools/loc.sh) and by tests against throwaway copies of the CSVs:
##
##   sync    content English (.tres fields) -> content.csv `en` + hashes;
##           translations of changed English are marked stale
##   check   what sync would change, without writing (for the lint)
##   export  one locale's missing and stale rows -> pending/<locale>.csv
##   import  a translated pending file -> back into whichever CSV owns each key
##
## UI text (translations.csv) is written in the CSV itself and keyed by hand;
## content text (content.csv) is generated and owned by sync, sorted by key.

const UI_CSV: String = "res://Localization/translations.csv"
const PENDING_DIR: String = "res://Localization/pending"

var ui_path: String = UI_CSV
var content_path: String = ContentText.CSV_PATH
var pending_dir: String = PENDING_DIR

## What the last step did and anything it warned about, one line each.
var messages: PackedStringArray = []


## Brings content.csv up to date with [param catalog]. With
## [param include_ui], also records English hashes in translations.csv, so
## its rows get the same stale tracking. Returns false (writing nothing) if
## the catalog has key clashes.
func sync(catalog: LocCatalog, include_ui: bool = false) -> bool:
	messages.clear()
	if not catalog.problems.is_empty():
		for problem: String in catalog.problems:
			messages.append("ERROR " + problem)
		return false

	var ui: LocTable = LocTable.read(ui_path)
	var content: LocTable = LocTable.read(content_path, ui.columns)
	var added: int = 0
	for key: String in catalog.keys():
		var entry: LocCatalog.Entry = catalog.entries[key]
		if not content.has(key):
			added += 1
		_apply_entry(content, entry)
	var changed: Array[String] = content.refresh_hashes()
	content.sort_by_key()

	for key: String in changed:
		messages.append("changed  %s%s" % [key, _stale_note(content, key)])
	for key: String in _orphans(content, catalog):
		messages.append("orphan   %s (no content field makes this key any more; move or delete its translations by hand)" % key)
	messages.append("%s: %d rows, %d new, %d changed" % [content_path.get_file(), content.keys().size(), added, changed.size()])
	_save_if_changed(content)

	if include_ui:
		var ui_changed: Array[String] = ui.refresh_hashes()
		for key: String in ui_changed:
			messages.append("changed  %s%s" % [key, _stale_note(ui, key)])
		messages.append("%s: %d changed" % [ui_path.get_file(), ui_changed.size()])
		_save_if_changed(ui)
	return true


## Why content.csv doesn't match [param catalog]: a field with no row, or a
## row whose English is behind its field. Empty when sync would change
## nothing a player could see.
func out_of_date(catalog: LocCatalog) -> Array[String]:
	var problems: Array[String] = catalog.problems.duplicate()
	var content: LocTable = LocTable.read(content_path)
	for key: String in catalog.keys():
		var entry: LocCatalog.Entry = catalog.entries[key]
		if not content.has(key):
			problems.append("%s: %s has no row in %s" % [entry.source_path, key, content_path.get_file()])
		elif content.english(key) != entry.english:
			problems.append("%s: %s changed since the last sync" % [entry.source_path, key])
		elif content.cell(key, LocTable.HASH_COLUMN) != LocTable.hash_of(entry.english):
			problems.append("%s: %s has no up-to-date hash" % [entry.source_path, key])
	return problems


## Writes the rows [param locale] still needs, from both CSVs, to
## pending/<locale>.csv. Returns how many rows it wrote.
func export_locale(locale: String) -> int:
	messages.clear()
	var pending: LocTable = LocTable.new()
	pending.path = pending_file(locale)
	pending.columns = PackedStringArray([
		LocTable.KEY_COLUMN, LocTable.SOURCE_COLUMN, locale,
		LocTable.CONTEXT_COLUMN, LocTable.MAX_CHARS_COLUMN, LocTable.STATUS_COLUMN, LocTable.HASH_COLUMN,
	])
	for table: LocTable in [LocTable.read(ui_path), LocTable.read(content_path)]:
		if locale not in table.locales():
			messages.append("note     %s has no %s column yet; import will add one" % [table.path.get_file(), locale])
		for key: String in table.pending_keys(locale):
			var stale: bool = table.status_of(key, locale) == LocTable.STALE
			pending.set_cell(key, LocTable.SOURCE_COLUMN, table.cell(key, LocTable.SOURCE_COLUMN))
			# A stale translation goes out with its row: amending it is
			# quicker than starting again.
			pending.set_cell(key, locale, table.cell(key, locale) if stale else "")
			pending.set_cell(key, LocTable.CONTEXT_COLUMN, table.cell(key, LocTable.CONTEXT_COLUMN))
			pending.set_cell(key, LocTable.MAX_CHARS_COLUMN, table.cell(key, LocTable.MAX_CHARS_COLUMN))
			pending.set_cell(key, LocTable.STATUS_COLUMN, LocTable.STALE if stale else LocTable.MISSING)
			pending.set_cell(key, LocTable.HASH_COLUMN, LocTable.hash_of(table.english(key)))
	_ensure_pending_dir()
	var error: Error = pending.save()
	if error != OK:
		messages.append("ERROR can't write %s (%s)" % [pending.path, error_string(error)])
		return 0
	var count: int = pending.keys().size()
	messages.append("%s: %d rows to translate" % [pending.path, count])
	return count


## Merges the translations in [param file_path] (an export, filled in) back
## into the CSVs. Each imported cell gets [param status], or the status the
## file gives the row if that is a real one, or `machine`. A row whose
## English changed after the export comes in as stale. Returns how many cells
## changed, or -1 if the file can't be used.
func import_file(file_path: String, status: String = "") -> int:
	messages.clear()
	var incoming: LocTable = LocTable.read(file_path)
	var incoming_locales: Array[String] = incoming.locales()
	if incoming_locales.size() != 1:
		messages.append("ERROR %s needs exactly one locale column; it has %s" % [file_path, incoming_locales])
		return -1
	var locale: String = incoming_locales[0]
	var ui: LocTable = LocTable.read(ui_path)
	var content: LocTable = LocTable.read(content_path, ui.columns)
	for table: LocTable in [ui, content]:
		_ensure_locale_column(table, locale)

	var imported: int = 0
	for key: String in incoming.keys():
		var value: String = incoming.cell(key, locale)
		if value.strip_edges().is_empty():
			continue
		var table: LocTable = ui if ui.has(key) else (content if content.has(key) else null)
		if table == null:
			messages.append("skipped  %s: no such key in either CSV" % key)
			continue
		var english: String = table.english(key)
		var state: String = _import_state(incoming.cell(key, LocTable.STATUS_COLUMN), status)
		var exported_hash: String = incoming.cell(key, LocTable.HASH_COLUMN)
		if not exported_hash.is_empty() and exported_hash != LocTable.hash_of(english):
			state = LocTable.STALE
			messages.append("stale    %s: its English changed after the export" % key)
		for problem: String in LocLint.parity_problems(english, LocTable.unescape(value)):
			messages.append("warning  %s: %s" % [key, problem])
		var too_long: String = LocLint.length_problem(
			LocTable.unescape(value), table.cell(key, LocTable.MAX_CHARS_COLUMN).to_int()
		)
		if not too_long.is_empty():
			messages.append("warning  %s: %s" % [key, too_long])
		if table.cell(key, locale) == value and table.status_of(key, locale) == state:
			continue
		table.set_cell(key, locale, value)
		table.set_status(key, locale, state)
		imported += 1

	_save_if_changed(ui)
	_save_if_changed(content)
	messages.append("%s: %d %s cells updated" % [file_path.get_file(), imported, locale])
	return imported


func pending_file(locale: String) -> String:
	return pending_dir.path_join("%s.csv" % locale)


func _apply_entry(content: LocTable, entry: LocCatalog.Entry) -> void:
	content.set_cell(entry.key, LocTable.SOURCE_COLUMN, LocTable.escape(entry.english))
	# A hand-written note (or a richer one carried over from translations.csv)
	# stays; blank it to get the generated one back.
	if content.cell(entry.key, LocTable.CONTEXT_COLUMN).is_empty():
		content.set_cell(entry.key, LocTable.CONTEXT_COLUMN, entry.context)
	if entry.max_chars > 0:
		content.set_cell(entry.key, LocTable.MAX_CHARS_COLUMN, str(entry.max_chars))


static func _stale_note(table: LocTable, key: String) -> String:
	var stale: Array[String] = []
	for locale: String in table.locales():
		if table.status_of(key, locale) == LocTable.STALE:
			stale.append(locale)
	return "" if stale.is_empty() else " (now stale: %s)" % ", ".join(stale)


static func _orphans(content: LocTable, catalog: LocCatalog) -> Array[String]:
	var found: Array[String] = []
	for key: String in content.keys():
		if not catalog.entries.has(key):
			found.append(key)
	return found


## The state an imported cell gets: the caller's, else the file's own if it
## names a finished state, else `machine`.
static func _import_state(file_status: String, override: String) -> String:
	if not override.is_empty():
		return override
	var state: String = file_status.strip_edges()
	if state.is_empty() or state == LocTable.MISSING or state == LocTable.STALE or "=" in state:
		return LocTable.MACHINE
	return state


## A new language gets its column before the notes, where Godot's importer
## and the other locales expect it.
static func _ensure_locale_column(table: LocTable, locale: String) -> void:
	if locale in table.columns:
		return
	var at: int = table.columns.size()
	for i: int in table.columns.size():
		if table.columns[i].begins_with("_"):
			at = i
			break
	table.add_column(locale, at)


## Godot would import a CSV in here as one more translation; .gdignore keeps
## the hand-off files out of the game.
func _ensure_pending_dir() -> void:
	DirAccess.make_dir_recursive_absolute(pending_dir)
	var marker: String = pending_dir.path_join(".gdignore")
	if not FileAccess.file_exists(marker):
		FileAccess.open(marker, FileAccess.WRITE)


func _save_if_changed(table: LocTable) -> void:
	var before: String = FileAccess.get_file_as_string(table.path) if FileAccess.file_exists(table.path) else ""
	if before == table.to_csv():
		return
	var error: Error = table.save()
	if error != OK:
		messages.append("ERROR can't write %s (%s)" % [table.path, error_string(error)])
