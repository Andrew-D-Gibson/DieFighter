extends Node
## Owns the game's language: which locales are offered, picking one on first
## launch, and switching at runtime.
##
## Every player-facing string lives in res://Localization/translations.csv
## (a key column, then one column per locale). Godot imports each column as a
## Translation; this registers every language's at startup (project.godot
## names only English's), so a column that gets text needs nothing else to
## show up. Switching language is just setting the TranslationServer's
## locale: Labels and Buttons with auto-translate refresh themselves, and
## anything that builds text in code listens for Events.locale_changed (or
## NOTIFICATION_TRANSLATION_CHANGED) and rebuilds. Each language also has its
## own fonts (a FontProfile, see FontRoles), which switch with it, live.
##
## Every language is offered from the start, translated or not: an
## untranslated one shows English text in that language's fonts (and Options
## says so), and its strings fill in as its column does.

const DEFAULT_LOCALE: String = "en"

## A debug-only locale that stretches every translated English string, so text
## that won't fit a longer language shows up before any translation exists.
## Strings that never went through tr() stay plain, which flags them too.
## Never offered in Options: the dev console's `lang pseudo` and the audit
## ask for it.
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
## Shorter names where the full one is too wide for a dropdown's button (the
## Options language row; its open list keeps the full name). Unambiguous
## while the game has one language of each.
const LOCALE_SHORT_NAMES: Dictionary[String, String] = {
	"pt_BR": "Português",
}

const _PseudoTranslation: GDScript = preload("res://Source/Systems/Localization/pseudo_translation.gd")

## Where Godot imports translations.csv's columns, one file per locale.
const _UI_TRANSLATION_PATH: String = "res://Localization/translations.%s.translation"
## Where it imports content.csv's (read by ContentText, not registered).
const _CONTENT_TRANSLATION_PATH: String = "res://Localization/content.%s.translation"
## How much of English's text a language needs before it counts as
## translated: chosen on first launch, and offered without the "English
## text" mark. Nearly all rather than all, so a few rows left in English on
## purpose don't hold a finished language back.
const _TRANSLATED_SHARE: float = 0.9

var _pseudo_translation: Translation
## The check on text that doesn't fit (see OverflowWatcher): red outlines and
## log lines, for someone checking a translation. Null until the dev console's
## `loc_watch on` asks for it (watch_overflow()), and only for that session.
var overflow_watcher: OverflowWatcher
## The language translations registered here at startup.
var _registered_translations: Array[Translation] = []
## Locale -> whether it counts as translated (is_translated()), worked out
## once: the files don't change while the game runs.
var _translated: Dictionary[String, bool] = {}


func _ready() -> void:
	_register_translations()


func _exit_tree() -> void:
	# A script-backed Translation still registered when the engine shuts down
	# crashes the TranslationServer's teardown.
	_remove_pseudo_translation()
	for translation: Translation in _registered_translations:
		TranslationServer.remove_translation(translation)
	_registered_translations.clear()


## The locales to offer in Options: every language the game knows, in menu
## order, translated or not (see is_translated()). Never the pseudo-locale.
func get_available_locales() -> Array[String]:
	var available: Array[String] = []
	available.assign(LOCALE_NAMES.keys())
	return available


## Whether [param locale]'s columns hold (nearly) all of English's text. One
## that doesn't still plays, in English text with its own fonts.
func is_translated(locale: String) -> bool:
	if locale == DEFAULT_LOCALE:
		return true
	if not _translated.has(locale):
		var english: int = _message_count(_UI_TRANSLATION_PATH, DEFAULT_LOCALE) \
			+ _message_count(_CONTENT_TRANSLATION_PATH, DEFAULT_LOCALE)
		var own: int = _message_count(_UI_TRANSLATION_PATH, locale) \
			+ _message_count(_CONTENT_TRANSLATION_PATH, locale)
		_translated[locale] = english > 0 and own >= english * _TRANSLATED_SHARE
	return _translated[locale]


## Starts or stops the overflow watcher for this session; it's made the first
## time it's turned on. False in release builds, where it doesn't exist.
func watch_overflow(on: bool) -> bool:
	if not OS.is_debug_build():
		return false
	if overflow_watcher == null:
		if not on:
			return true
		overflow_watcher = OverflowWatcher.new()
		overflow_watcher.name = "OverflowWatcher"
		add_child(overflow_watcher)
	overflow_watcher.live = on
	if not on:
		overflow_watcher.clear_outlines()
	return true


func is_watching_overflow() -> bool:
	return overflow_watcher != null and overflow_watcher.live


func get_locale_name(locale: String) -> String:
	if locale == PSEUDO_LOCALE:
		return "Pseudo (debug)"
	return LOCALE_NAMES.get(locale, locale)


## [method get_locale_name], or its short form where it has one.
func get_locale_short_name(locale: String) -> String:
	return LOCALE_SHORT_NAMES.get(locale, get_locale_name(locale))


func get_locale() -> String:
	return TranslationServer.get_locale()


## Switches the game to `locale`. An empty or unsupported locale picks the
## closest match to the OS language instead, which is what a first launch
## (nothing saved yet) gets. With [param allow_pseudo], a debug build also
## accepts the pseudo-locale (the dev console and the audit); a saved one
## (from an older build's Options) is dropped.
func set_locale(locale: String, allow_pseudo: bool = false) -> void:
	if locale == PSEUDO_LOCALE and allow_pseudo and OS.is_debug_build():
		_add_pseudo_translation()
	else:
		_remove_pseudo_translation()
		if locale not in get_available_locales():
			locale = _detect_locale()

	# Fonts before text: a language whose script the current fonts lack must
	# never be drawn in them, even for a frame. Also on a repeat of the current
	# locale, so the first call at boot applies its profile.
	FontRoles.use_locale(locale)
	if locale == TranslationServer.get_locale():
		return
	TranslationServer.set_locale(locale)
	Events.locale_changed.emit(locale)


## The translated locale closest to the OS language: an exact match beats a
## shared language (a Portuguese player in Portugal still gets pt_BR), and
## anything unrelated falls back to English. An untranslated one would greet
## a new player in English text in another language's fonts, so it waits to
## be picked in Options.
func _detect_locale() -> String:
	var os_locale: String = OS.get_locale()
	var best_locale: String = DEFAULT_LOCALE
	var best_score: int = 0
	for locale: String in LOCALE_NAMES:
		if not is_translated(locale):
			continue
		var score: int = TranslationServer.compare_locales(os_locale, locale)
		if score > best_score:
			best_score = score
			best_locale = locale
	return best_locale


## Registers each language's UI translation that project.godot doesn't
## already load. Godot imports one file per column even before the column has
## text; one that's missing (an all-empty column, in some versions) is
## skipped, and that language plays in English until it exists.
func _register_translations() -> void:
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	for locale: String in LOCALE_NAMES:
		var path: String = _UI_TRANSLATION_PATH % locale
		if locale in loaded or not ResourceLoader.exists(path):
			continue
		var translation: Translation = load(path) as Translation
		if translation:
			TranslationServer.add_translation(translation)
			_registered_translations.append(translation)


## How many strings [param locale]'s import of one CSV holds (0 if none).
## Godot leaves a row's empty cell out, so this counts what's translated.
static func _message_count(path_pattern: String, locale: String) -> int:
	var path: String = path_pattern % locale
	if not ResourceLoader.exists(path):
		return 0
	var translation: Translation = load(path) as Translation
	return translation.get_message_count() if translation else 0


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
