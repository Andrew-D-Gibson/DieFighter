extends Translation
## The debug pseudo-locale: English, stretched and fenced so layout problems
## show up before any real translation exists.
##
## Godot has a built-in pseudolocalization, but it rewrites everything,
## including BBCode tags, icon tokens like (die_3) and {placeholders}, which
## breaks the text it's meant to test. This one only touches plain words.
##
## Each translated string gets its vowels doubled, which grows typical English
## by about the third that German, French or Russian add, and is wrapped in
## « », so a clipped end is visible. Text that comes out unfenced never went
## through tr(), so it would stay English in every language.

## English, looked up by key. Strings that aren't keys (literal English some
## Label still holds) get no translation here, so they come out unfenced.
var source: Translation

## Spans to leave exactly as written: BBCode tags, (token)s, {placeholder}s,
## and printf-style %d / %+d / %s.
var _protected: RegEx = RegEx.create_from_string(r"\[[^\]]*\]|\([a-z_0-9=.]+\)|\{[^}]*\}|%[-+0-9.]*[a-zA-Z%]")


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	if not source:
		return &""
	var english: String = source.get_message(src_message)
	if english.is_empty():
		return &""
	return StringName(stretch(english))


func _get_plural_message(src_message: StringName, src_plural_message: StringName, n: int, context: StringName) -> StringName:
	if not source:
		return &""
	var english: String = source.get_plural_message(src_message, src_plural_message, n, context)
	if english.is_empty():
		return &""
	return StringName(stretch(english))


func stretch(text: String) -> String:
	var result: String = ""
	var cursor: int = 0
	for protected_span: RegExMatch in _protected.search_all(text):
		result += _double_vowels(text.substr(cursor, protected_span.get_start() - cursor))
		result += protected_span.get_string()
		cursor = protected_span.get_end()
	result += _double_vowels(text.substr(cursor))
	return "«" + result + "»"


func _double_vowels(text: String) -> String:
	var result: String = ""
	for character: String in text:
		result += character
		if character in "aeiouAEIOU":
			result += character
	return result
