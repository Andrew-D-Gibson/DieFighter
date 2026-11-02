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
## file adds its sub-resource id: TILE.LASER.RESOURCE_X7K2P.CALLOUT. Renaming
## the file (or re-creating the sub-resource) gives new keys, so its rows
## show up as orphans in the next sync and need their translations moved.
static func key_for(res: Resource, property: StringName) -> String:
	var field: Field = field_of(res, property)
	if field == null:
		return ""
	var owner_part: String = owner_key(res)
	if owner_part.is_empty():
		return ""
	return "%s.%s" % [owner_part, field.suffix]


## Everything before the field suffix: HAZARD.SOLAR_FLARE. "" when [param res]
## has no file path (built in code) or isn't content text.
static func owner_key(res: Resource) -> String:
	if not is_content(res):
		return ""
	var path: String = res.resource_path
	if path.is_empty():
		return ""
	var parts: PackedStringArray = path.split("::")
	var owner_part: String = "%s.%s" % [
		_key_segment(res.call(&"_content_text_prefix")),
		_key_segment(parts[0].get_file().get_basename()),
	]
	if parts.size() > 1:
		owner_part += "." + _key_segment(parts[1])
	return owner_part


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
