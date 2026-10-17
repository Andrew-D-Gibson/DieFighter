extends Node
## Owns the game's language: which locales are offered, picking one on first
## launch, and switching at runtime.
##
## Every player-facing string lives in res://Localization/translations.csv
## (a key column, then one column per locale). Godot imports each column as a
## Translation and loads them all at startup through the project's
## internationalization settings, so switching language is just setting the
## TranslationServer's locale: Labels and Buttons with auto-translate refresh
## themselves, and anything that builds text in code listens for
## Events.locale_changed (or NOTIFICATION_TRANSLATION_CHANGED) and rebuilds.

const DEFAULT_LOCALE: String = "en"

## A debug-only locale that stretches every translated English string, so text
## that won't fit a longer language shows up before any translation exists.
## Strings that never went through tr() stay plain, which flags them too.
const PSEUDO_LOCALE: String = "en_XA"

## Locales the game can be played in, in menu order, each named in its own
## language so a player who can't read the current one can still find theirs.
const LOCALE_NAMES: Dictionary[String, String] = {
	"en": "English",
	"zh_CN": "简体中文",
	"ja": "日本語",
	"ru": "Русский",
	"de": "Deutsch",
	"fr": "Français",
	"es": "Español",
	"pt_BR": "Português (Brasil)",
}

const _PseudoTranslation: GDScript = preload("res://Source/Systems/Localization/pseudo_translation.gd")

var _pseudo_translation: Translation


func _exit_tree() -> void:
	# A script-backed Translation still registered when the engine shuts down
	# crashes the TranslationServer's teardown.
	_remove_pseudo_translation()


## The locales to offer in Options: every known locale whose column has any
## text in it yet, plus the pseudo-locale in debug builds.
func get_available_locales() -> Array[String]:
	var available: Array[String] = []
	for locale: String in LOCALE_NAMES:
		if locale == DEFAULT_LOCALE or _has_messages(locale):
			available.append(locale)
	if OS.is_debug_build():
		available.append(PSEUDO_LOCALE)
	return available


func get_locale_name(locale: String) -> String:
	if locale == PSEUDO_LOCALE:
		return "Pseudo (debug)"
	return LOCALE_NAMES.get(locale, locale)


func get_locale() -> String:
	return TranslationServer.get_locale()


## Switches the game to `locale`. An empty or unsupported locale picks the
## closest match to the OS language instead, which is what a first launch
## (nothing saved yet) gets.
func set_locale(locale: String) -> void:
	if locale not in get_available_locales():
		locale = _detect_locale()

	if locale == PSEUDO_LOCALE:
		_add_pseudo_translation()
	else:
		_remove_pseudo_translation()

	if locale == TranslationServer.get_locale():
		return
	TranslationServer.set_locale(locale)
	Events.locale_changed.emit(locale)


## The offered locale closest to the OS language: an exact match beats a
## shared language (a Portuguese player in Portugal still gets pt_BR), and
## anything unrelated falls back to English.
func _detect_locale() -> String:
	var os_locale: String = OS.get_locale()
	var best_locale: String = DEFAULT_LOCALE
	var best_score: int = 0
	for locale: String in LOCALE_NAMES:
		if locale != DEFAULT_LOCALE and not _has_messages(locale):
			continue
		var score: int = TranslationServer.compare_locales(os_locale, locale)
		if score > best_score:
			best_score = score
			best_locale = locale
	return best_locale


## Columns exist for every planned language long before they're translated;
## an empty one shouldn't be offered.
func _has_messages(locale: String) -> bool:
	var translation: Translation = TranslationServer.get_translation_object(locale)
	return translation != null and translation.locale == locale and translation.get_message_count() > 0


func _add_pseudo_translation() -> void:
	if _pseudo_translation:
		return
	_pseudo_translation = _PseudoTranslation.new()
	_pseudo_translation.source = TranslationServer.get_translation_object(DEFAULT_LOCALE)
	_pseudo_translation.locale = PSEUDO_LOCALE
	TranslationServer.add_translation(_pseudo_translation)


func _remove_pseudo_translation() -> void:
	if not _pseudo_translation:
		return
	TranslationServer.remove_translation(_pseudo_translation)
	_pseudo_translation = null
