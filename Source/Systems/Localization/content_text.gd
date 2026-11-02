class_name ContentText
extends RefCounted
## Player-facing text that content resources carry in English, translated
## through res://Localization/content.csv.
##
## The English lives in the resource's own fields, so a designer edits it in
## the inspector like any other property; tools/loc.sh sync copies it into
## content.csv under a key generated from the resource's file and field
## ("HAZARD.SOLAR_FLARE.HEADLINE"), never from the English, so fixing a typo
## doesn't orphan the translations. In English the game reads the field
## straight off the resource, so an edit shows up before anyone runs the sync;
## in any other language it reads that locale's column of content.csv and
## falls back to the field while the cell is empty.
##
## A content type joins in by implementing two methods (see
## BackgroundHazardResource for an example):
##   func _content_text_prefix() -> String          # "HAZARD"
##   func _content_text_fields() -> Array[ContentText.Field]
## and by giving each display path an accessor that calls ContentText.text().
## A type whose file names repeat in different folders also implements
##   func _content_text_folder_in_key() -> bool     # true
## so its keys name the folder too (SHIP_STATE.EVENT_CONVOY.HAULER_BETRAYED).
## Code that copies content at run time uses copy(), not duplicate(), or the
## copy shows English in every language.
## tools/loc.sh sync (LocCatalog) finds every such resource under res://Source
## by itself.

## Where tools/loc.sh sync writes the generated rows. Godot imports one
## Translation per locale column next to it (content.<locale>.translation).
const CSV_PATH: String = "res://Localization/content.csv"

## English is never looked up: the resource's own field is the source.
const SOURCE_LOCALE: String = "en"

## The debug pseudo-locale (Localization.PSEUDO_LOCALE). Stretches the field's
## live English, so pseudo shows an edit as promptly as English does.
const _PSEUDO_LOCALE: String = "en_XA"

## Metadata a content resource carries the first part of its keys in, once
## worked out (owner_keys_in_file()). Unlike resource_path, duplicate() copies
## it, so a copy keeps translating.
const _OWNER_META: StringName = &"_content_text_owner"

const _PseudoTranslation: GDScript = preload("res://Source/Systems/Localization/pseudo_translation.gd")


## One translatable field of a content type: which property holds the
## English, the key suffix it gets, and notes for the translator.
class Field:
	extends RefCounted
	## The @export property that holds the English.
	var property: StringName
	## The key's last part: HAZARD.SOLAR_FLARE.<suffix>.
	var suffix: String
	## What the text is and where it shows, for the CSV's _context column.
	var context: String
	## A hard length limit for the CSV's _max_chars column, 0 for none.
	var max_chars: int

	func _init(p_property: StringName, p_suffix: String, p_context: String = "", p_max_chars: int = 0) -> void:
		property = p_property
		suffix = p_suffix
		context = p_context
		max_chars = p_max_chars


## Translation per locale, loaded on first use. A locale with no file maps to
## null so it isn't looked for again.
static var _translations: Dictionary[String, Translation] = {}
static var _pseudo: Translation


## [param res]'s [param property] in the current language. The English field
## for English, for a resource with no file of its own (one built in code or
## a test), and for a key the current language hasn't translated yet.
static func text(res: Resource, property: StringName) -> String:
	var english: String = str(res.get(property))
	if english.is_empty():
		return english
	var locale: String = TranslationServer.get_locale()
	if locale == SOURCE_LOCALE:
		return english
	if locale == _PSEUDO_LOCALE:
		return _stretch(english)

	var key: String = key_for(res, property)
	if key.is_empty():
		return english
	var translated: String = _message(locale, key)
	if translated.is_empty() and "_" in locale:
		# A regional locale the game doesn't ship (de_AT) reads its language.
		translated = _message(locale.get_slice("_", 0), key)
	return translated if not translated.is_empty() else english


## The content.csv key for [param res]'s [param property], or "" if [param res]
## isn't content text or has no file to name it by.
##
## A resource saved as its own file is named by the file:
## HAZARD.SOLAR_FLARE.HEADLINE for solar_flare.tres. One embedded in another
## file is named by that file and the property path that reaches it from the
## file's root resource: ENEMY_ACTION.SEIZE.EFFECT_CHAIN.EFFECTS_6.CALLOUT is
## the callout in step 6 of seize.tres's chain. The path is read off the
## file's contents, so a re-save (which may renumber sub-resource ids) never
## changes it; moving the step does, and so does renaming the file. Either
## way the next sync carries the translations over to the new key while the
## English still matches (LocPipeline.sync).
static func key_for(res: Resource, property: StringName) -> String:
	var field: Field = field_of(res, property)
	if field == null:
		return ""
	var owner_part: String = owner_key(res)
	if owner_part.is_empty():
		return ""
	return "%s.%s" % [owner_part, field.suffix]


## Everything before the field suffix: HAZARD.SOLAR_FLARE. "" when [param res]
## has no file (built in code) or isn't content text. A copy made with
## copy() answers for the resource it was copied from.
static func owner_key(res: Resource) -> String:
	if not is_content(res):
		return ""
	if res.has_meta(_OWNER_META):
		return String(res.get_meta(_OWNER_META))
	var path: String = res.resource_path
	if path.is_empty():
		return ""
	var file: String = path.get_slice("::", 0)
	var root: Resource = res if not "::" in path else load(file)
	if root == null:
		return ""
	return owner_keys_in_file(root, file).get(res.get_instance_id(), "")


## A deep copy of [param res] whose content text (its own, and that of every
## resource embedded in it) keeps translating. A plain duplicate() loses the
## file path the keys are made from; game code that copies content (a rolled
## enemy action) copies it through here instead.
static func copy(res: Resource) -> Resource:
	if res == null:
		return null
	var path: String = res.resource_path
	if not path.is_empty():
		var file: String = path.get_slice("::", 0)
		var root: Resource = res if not "::" in path else load(file)
		if root:
			owner_keys_in_file(root, file)
	# The keys ride along as metadata, which duplicate() copies (a copy of a
	# copy included).
	return res.duplicate(true)


## The owner part of the key of every content resource in [param file],
## [param root] (its root resource) and the ones embedded in it, by instance
## id. Outside the editor each one is also stamped with it (see copy()); in
## the editor that metadata would be saved into the .tres, so it isn't.
static func owner_keys_in_file(root: Resource, file: String) -> Dictionary:
	var found: Dictionary = {}
	_collect_owner_keys(root, file, _root_part(root, file), found, {})
	if not Engine.is_editor_hint():
		for id: int in found:
			var res: Resource = instance_from_id(id) as Resource
			if res and not res.has_meta(_OWNER_META):
				res.set_meta(_OWNER_META, found[id])
	return found


## The first part of every key a file makes: its root's prefix and the file
## name (HAZARD.SOLAR_FLARE). A root that isn't content text itself (a tile
## carrying a callout, before tiles are translatable) is named after its class
## (TileResource -> TILE). A type whose file names repeat across folders adds
## the folder (see _content_text_folder_in_key).
static func _root_part(root: Resource, file: String) -> String:
	var prefix: String = String(root.call(&"_content_text_prefix")) if is_content(root) else _class_prefix(root)
	var part: String = _key_segment(prefix)
	if root.has_method(&"_content_text_folder_in_key") and root.call(&"_content_text_folder_in_key"):
		part += "." + _key_segment(file.get_base_dir().get_file())
	return part + "." + _key_segment(file.get_file().get_basename())


## Walks [param res] and every resource embedded in the same file, recording
## the property path to each content resource. Deterministic: properties in
## declaration order, arrays by index, so the same file always gives the same
## keys. A resource reached twice keeps its first path.
static func _collect_owner_keys(res: Resource, file: String, path: String, found: Dictionary, visited: Dictionary) -> void:
	if visited.has(res.get_instance_id()):
		return
	visited[res.get_instance_id()] = true
	if is_content(res):
		found[res.get_instance_id()] = path
	for property: Dictionary in res.get_property_list():
		var name: String = property.name
		if not (property.usage & PROPERTY_USAGE_STORAGE) or name == "script" or name.begins_with("metadata/"):
			continue
		_collect_value(res.get(name), file, path + "." + _key_segment(name), found, visited)


static func _collect_value(value: Variant, file: String, path: String, found: Dictionary, visited: Dictionary) -> void:
	if value is Resource:
		var sub: Resource = value
		# Only what lives in this file: a resource saved on its own is named by
		# its own file.
		if not sub is Script and (sub.resource_path.is_empty() or sub.resource_path.begins_with(file + "::")):
			_collect_owner_keys(sub, file, path, found, visited)
	elif value is Array:
		var items: Array = value
		for i: int in items.size():
			_collect_value(items[i], file, "%s_%d" % [path, i], found, visited)
	elif value is Dictionary:
		# A plain key names its entry (TRANSITIONS_3). A resource key (a tile's
		# TileEvent) has no name that lasts, so its place does: dictionaries
		# keep the order the file lists them in.
		var entries: Dictionary = value
		var index: int = 0
		for entry_key: Variant in entries:
			var segment: String = str(index) if entry_key is Object else _key_segment(str(entry_key))
			_collect_value(entries[entry_key], file, "%s_%s" % [path, segment], found, visited)
			index += 1


## TileResource -> TILE, EnemyTurnActionList -> ENEMY_TURN_ACTION_LIST.
static func _class_prefix(res: Resource) -> String:
	var script: Script = res.get_script()
	var class_title: String = String(script.get_global_name()) if script else ""
	if class_title.is_empty():
		class_title = res.get_class()
	if class_title.ends_with("Resource") and class_title != "Resource":
		class_title = class_title.trim_suffix("Resource")
	return class_title.to_snake_case()


## True when [param res] declares translatable fields.
static func is_content(res: Resource) -> bool:
	return res != null and res.has_method(&"_content_text_fields") and res.has_method(&"_content_text_prefix")


## [param res]'s declared fields, in declaration order. Empty for anything
## that isn't content text.
static func fields_of(res: Resource) -> Array[Field]:
	var fields: Array[Field] = []
	if is_content(res):
		fields.assign(res.call(&"_content_text_fields"))
	return fields


static func field_of(res: Resource, property: StringName) -> Field:
	for field: Field in fields_of(res):
		if field.property == property:
			return field
	return null


## Upper snake case, safe inside a dotted key: "fates_tithe" -> FATES_TITHE.
static func _key_segment(raw: String) -> String:
	var segment: String = ""
	for character: String in raw.to_upper():
		var code: int = character.unicode_at(0)
		var alnum: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90)
		segment += character if alnum else "_"
	return segment


static func _message(locale: String, key: String) -> String:
	if not _translations.has(locale):
		var path: String = CSV_PATH.get_basename() + ".%s.translation" % locale
		_translations[locale] = load(path) as Translation if ResourceLoader.exists(path) else null
	var translation: Translation = _translations[locale]
	if translation == null:
		return ""
	return String(translation.get_message(StringName(key)))


static func _stretch(english: String) -> String:
	if _pseudo == null:
		_pseudo = _PseudoTranslation.new()
	return _pseudo.call(&"stretch", english)


## Forgets the loaded translations, so the next lookup reads the files again.
## For tools and tests that rewrite content.csv while running.
static func clear_cache() -> void:
	_translations.clear()
