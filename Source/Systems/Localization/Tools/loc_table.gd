class_name LocTable
extends RefCounted
## One translation CSV (Localization/translations.csv or content.csv) as the
## loc tools see it: a key column, an `en` column, one column per locale, and
## `_`-prefixed note columns Godot's importer ignores.
##
## Cells are kept exactly as the CSV holds them, and a row nobody changed is
## written back as the very line it was read from, so a hand-edited file
## (translations.csv) only shows the rows a tool touched in its diff. The
## importer unescapes \n, \t and \\ in translations, so a cell's text is
## `unescape(cell)`.
##
## `_status` tracks each locale's translation of a row. Either one word for
## every filled locale ("machine") or one `locale=state` pair per filled
## locale ("de=reviewed fr=stale"). States: `machine` (drafted by a tool),
## `reviewed` (checked by a person), `stale` (the English changed after it was
## translated). `_en_hash` is a short hash of the English it was last synced
## from, which is how a changed English gets noticed.

const KEY_COLUMN: String = "keys"
const SOURCE_COLUMN: String = "en"
const CONTEXT_COLUMN: String = "_context"
const MAX_CHARS_COLUMN: String = "_max_chars"
const STATUS_COLUMN: String = "_status"
const HASH_COLUMN: String = "_en_hash"

const STALE: String = "stale"
const MACHINE: String = "machine"
const REVIEWED: String = "reviewed"
## Written into an export's _status for a row with nothing translated yet.
const MISSING: String = "missing"

## Columns every table carries, in this order, when a new file is started
## without a template.
const DEFAULT_COLUMNS: PackedStringArray = [
	"keys", "en", "zh_CN", "ja", "ru", "de", "fr", "es", "pt_BR",
	"_context", "_max_chars", "_status", "_en_hash",
]

var path: String = ""
var columns: PackedStringArray = DEFAULT_COLUMNS.duplicate()
## Row cells by key, each a column -> cell dictionary.
var _rows: Dictionary[String, Dictionary] = {}
## Keys in file order.
var _order: Array[String] = []
## The line each untouched row was read from, by key, and the header's.
## Changing a row (or the columns) drops its line, so it is written fresh.
var _raw_lines: Dictionary[String, String] = {}
var _raw_header: String = ""


## Reads [param csv_path]. A missing file gives an empty table with
## [param template_columns] (or the default columns), ready to be saved there.
static func read(csv_path: String, template_columns: PackedStringArray = PackedStringArray()) -> LocTable:
	var table: LocTable = LocTable.new()
	table.path = csv_path
	if not template_columns.is_empty():
		table.columns = template_columns.duplicate()
	if not FileAccess.file_exists(csv_path):
		return table
	var file: FileAccess = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("LocTable: can't read %s" % csv_path)
		return table
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(csv_path)
	var start: int = file.get_position()
	var header: PackedStringArray = file.get_csv_line()
	if header.is_empty() or not header[0].strip_edges().ends_with(KEY_COLUMN):
		push_error("LocTable: %s doesn't start with a '%s' column" % [csv_path, KEY_COLUMN])
		return table
	table._raw_header = _raw_line(bytes, start, file.get_position())
	# A UTF-8 byte-order mark from a spreadsheet app would otherwise glue
	# itself to the first column's name.
	header[0] = KEY_COLUMN
	table.columns = header
	while not file.eof_reached():
		start = file.get_position()
		var line: PackedStringArray = file.get_csv_line()
		if line.size() == 0 or (line.size() == 1 and line[0].is_empty()):
			continue
		var cells: Dictionary = {}
		for i: int in mini(line.size(), header.size()):
			cells[header[i]] = line[i]
		var key: String = cells.get(KEY_COLUMN, "")
		if key.is_empty():
			continue
		if table._rows.has(key):
			push_warning("LocTable: %s has key %s twice; keeping the first" % [csv_path, key])
			continue
		table._rows[key] = cells
		table._order.append(key)
		table._raw_lines[key] = _raw_line(bytes, start, file.get_position())
	return table


static func _raw_line(bytes: PackedByteArray, from: int, to: int) -> String:
	return bytes.slice(from, to).get_string_from_utf8().trim_suffix("\n").trim_suffix("\r")


func save() -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_csv())
	return OK


func to_csv() -> String:
	var lines: PackedStringArray = [_raw_header if not _raw_header.is_empty() else _csv_line(columns)]
	for key: String in _order:
		if _raw_lines.has(key):
			lines.append(_raw_lines[key])
			continue
		var row: Dictionary = _rows[key]
		var cells: PackedStringArray = []
		for column: String in columns:
			cells.append(row.get(column, ""))
		lines.append(_csv_line(cells))
	return "\n".join(lines) + "\n"


# ── Rows ─────────────────────────────────────────────────────────────────────

func keys() -> Array[String]:
	return _order.duplicate()


func has(key: String) -> bool:
	return _rows.has(key)


## The raw CSV cell, "" if the row or column doesn't exist.
func cell(key: String, column: String) -> String:
	if not _rows.has(key):
		return ""
	return _rows[key].get(column, "")


func set_cell(key: String, column: String, value: String) -> void:
	if not _rows.has(key):
		_rows[key] = {KEY_COLUMN: key}
		_order.append(key)
	if cell(key, column) == value and _rows[key].has(column):
		return
	_rows[key][column] = value
	_raw_lines.erase(key)


## Adds a column at [param at] (the end by default). Every row is written
## fresh afterwards, since its line no longer has the right cells.
func add_column(column: String, at: int = -1) -> void:
	if column in columns:
		return
	if at < 0 or at > columns.size():
		at = columns.size()
	columns.insert(at, column)
	_raw_header = ""
	_raw_lines.clear()


## The English of [param key], unescaped.
func english(key: String) -> String:
	return unescape(cell(key, SOURCE_COLUMN))


## Tool-owned files (content.csv) are kept sorted, so regenerating one gives
## the same file and diffs show only what changed.
func sort_by_key() -> void:
	_order.sort()


## The locale columns: everything but the key, the English and the notes.
func locales() -> Array[String]:
	var found: Array[String] = []
	for column: String in columns:
		if column == KEY_COLUMN or column == SOURCE_COLUMN or column.begins_with("_") or "?" in column:
			continue
		found.append(column)
	return found


# ── Status ───────────────────────────────────────────────────────────────────

## The state of [param locale]'s translation of [param key], "" when the cell
## is empty.
func status_of(key: String, locale: String) -> String:
	if cell(key, locale).is_empty():
		return ""
	var parsed: Dictionary = _parse_status(cell(key, STATUS_COLUMN))
	return parsed.get(locale, parsed.get("", ""))


func set_status(key: String, locale: String, state: String) -> void:
	var states: Dictionary = {}
	for each: String in locales():
		if each == locale:
			states[each] = state
		elif not cell(key, each).is_empty():
			states[each] = status_of(key, each)
	set_cell(key, STATUS_COLUMN, _format_status(states))


## One word when every filled locale agrees, else locale=state pairs.
## [param states] holds only the locales whose cell is filled.
func _format_status(states: Dictionary) -> String:
	var distinct: Array[String] = []
	for locale: String in states:
		if String(states[locale]) not in distinct:
			distinct.append(states[locale])
	if distinct.is_empty():
		return ""
	if distinct.size() == 1:
		return distinct[0]
	var pairs: PackedStringArray = []
	for locale: String in locales():
		if not String(states.get(locale, "")).is_empty():
			pairs.append("%s=%s" % [locale, states[locale]])
	return " ".join(pairs)


static func _parse_status(raw: String) -> Dictionary:
	var parsed: Dictionary = {}
	for token: String in raw.strip_edges().split(" ", false):
		if "=" in token:
			parsed[token.get_slice("=", 0)] = token.get_slice("=", 1)
		else:
			parsed[""] = token
	return parsed


# ── Sync ─────────────────────────────────────────────────────────────────────

## Records each row's English hash, marking every translation of a row whose
## English changed since the last sync as stale (and keeping it: a stale
## translation is a better start than none). A row seen for the first time
## just gets its hash. Returns the keys whose English changed.
func refresh_hashes() -> Array[String]:
	var changed: Array[String] = []
	for key: String in _order:
		var english_text: String = english(key)
		if english_text.is_empty():
			continue
		var fresh: String = hash_of(english_text)
		var recorded: String = cell(key, HASH_COLUMN)
		if recorded == fresh:
			continue
		if not recorded.is_empty():
			changed.append(key)
			for locale: String in locales():
				if not cell(key, locale).is_empty():
					set_status(key, locale, STALE)
		set_cell(key, HASH_COLUMN, fresh)
	return changed


## Rows [param locale] still needs: untranslated, or translated from English
## that has since changed. Rows without English are skipped.
func pending_keys(locale: String) -> Array[String]:
	var found: Array[String] = []
	for key: String in _order:
		if english(key).is_empty():
			continue
		if cell(key, locale).is_empty() or status_of(key, locale) == STALE:
			found.append(key)
	return found


# ── Text helpers ─────────────────────────────────────────────────────────────

static func hash_of(english_text: String) -> String:
	return english_text.sha256_text().substr(0, 10)


## Text as a CSV cell: line breaks become \n (one row per line keeps the file
## diffable), and backslashes are doubled so the importer's unescape gives
## them back.
static func escape(text: String) -> String:
	return text.replace("\\", "\\\\").replace("\r", "").replace("\n", "\\n").replace("\t", "\\t")


## A CSV cell as the game sees it, after Godot's importer unescapes it.
static func unescape(cell_text: String) -> String:
	var result: String = ""
	var i: int = 0
	while i < cell_text.length():
		var character: String = cell_text[i]
		if character == "\\" and i + 1 < cell_text.length():
			var next: String = cell_text[i + 1]
			match next:
				"n":
					result += "\n"
				"t":
					result += "\t"
				"\\", "\"", "'":
					result += next
				_:
					result += character + next
			i += 2
			continue
		result += character
		i += 1
	return result


## Quotes a cell only when it has to (a comma, quote or line break), the way
## spreadsheet apps and Python's csv module do, so rows round-trip unchanged.
static func _csv_line(cells: PackedStringArray) -> String:
	var quoted: PackedStringArray = []
	for value: String in cells:
		if value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
			quoted.append("\"%s\"" % value.replace("\"", "\"\""))
		else:
			quoted.append(value)
	return ",".join(quoted)
