class_name LocLint
extends RefCounted
## Checks a translation against its English: the parts the game parses
## (placeholders, tokens, BBCode) must survive translation exactly, and the
## text must fit any length limit.
##
## Used by `loc.sh import` (as warnings) and the content lint test (as
## failures).

## {name} placeholders filled in by code with format().
static var _placeholder: RegEx = RegEx.create_from_string(r"\{[^}]*\}")
## %d / %+d / %s style placeholders.
static var _printf: RegEx = RegEx.create_from_string(r"%[-+0-9.]*[a-zA-Z]")
## Icon and keyword tokens Utils.format_text expands: (die_3), (locked),
## (delay=0.3).
static var _token: RegEx = RegEx.create_from_string(r"\([a-z_0-9=.]+\)")
## Any BBCode tag, opening or closing.
static var _tag: RegEx = RegEx.create_from_string(r"\[(/?)([a-zA-Z_]+)[^\]]*\]")


## What [param translated] lost or gained against [param english]. Empty when
## they match.
static func parity_problems(english: String, translated: String) -> Array[String]:
	var problems: Array[String] = []
	for kind: Array in [["placeholder", _placeholder], ["printf placeholder", _printf], ["token", _token]]:
		var regex: RegEx = kind[1]
		var expected: Array[String] = _matches(regex, english)
		var found: Array[String] = _matches(regex, translated)
		if expected != found:
			problems.append("%s mismatch: English has %s, translation has %s" % [kind[0], expected, found])
	var expected_tags: Array[String] = _opening_tags(english)
	var found_tags: Array[String] = _opening_tags(translated)
	if expected_tags != found_tags:
		problems.append("BBCode mismatch: English has %s, translation has %s" % [expected_tags, found_tags])
	# Only a translation can break nesting the English got right; text that
	# isn't BBCode at all ("[x2]") is unbalanced in both and left alone.
	var balance: String = bbcode_balance_problem(translated)
	if not balance.is_empty() and bbcode_balance_problem(english).is_empty():
		problems.append(balance)
	return problems


## Why [param text]'s BBCode doesn't nest properly, or "" if it does.
static func bbcode_balance_problem(text: String) -> String:
	var open: Array[String] = []
	for tag_match: RegExMatch in _tag.search_all(text):
		var tag_name: String = tag_match.get_string(2).to_lower()
		if tag_match.get_string(1).is_empty():
			open.append(tag_name)
		elif open.is_empty() or open.back() != tag_name:
			return "BBCode: [/%s] closes %s" % [tag_name, ("[%s]" % open.back()) if not open.is_empty() else "nothing"]
		else:
			open.pop_back()
	if not open.is_empty():
		return "BBCode: [%s] is never closed" % open.back()
	return ""


## Why [param text] is too long for [param max_chars], or "" if it fits.
## Counts what the player sees: BBCode tags don't count, a token is one icon,
## and a placeholder counts as two characters (it is nearly always a number).
static func length_problem(text: String, max_chars: int) -> String:
	if max_chars <= 0:
		return ""
	var visible: String = _tag.sub(text, "", true)
	visible = _token.sub(visible, "#", true)
	visible = _placeholder.sub(visible, "##", true)
	visible = _printf.sub(visible, "##", true)
	if visible.length() > max_chars:
		return "%d characters, limit %d" % [visible.length(), max_chars]
	return ""


## Sorted, so a translation may reorder placeholders and tokens freely.
static func _matches(regex: RegEx, text: String) -> Array[String]:
	var found: Array[String] = []
	for each: RegExMatch in regex.search_all(text):
		found.append(each.get_string())
	found.sort()
	return found


static func _opening_tags(text: String) -> Array[String]:
	var found: Array[String] = []
	for each: RegExMatch in _tag.search_all(text):
		if each.get_string(1).is_empty():
			found.append(each.get_string())
	found.sort()
	return found
