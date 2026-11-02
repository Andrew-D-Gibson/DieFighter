class_name Keywords
extends RefCounted
## Game terms written into descriptions as tokens, e.g. "(feed_right)".
##
## Utils.format_text() swaps each token for its styled label wherever text is
## shown. In the info panel the label is also hoverable: it carries its term's
## id as [url] meta, and the panel looks the id up with title() and
## definition() to pop the rule up, so descriptions never have to repeat the
## rules. Lookups go by id, never by the English, so every label, title and
## rule can be translated (they flow through ContentText like other content).
##
## HOW TO ADD A KEYWORD:
##   1. Add a KeywordResource to Source/Content/Keywords/KeywordResources/;
##      its file name is its id. Write its title and rule.
##   2. Give it one KeywordToken per spelling ("(feed_right)", "(feed_left)"),
##      added at the end of its tokens list (a label's content.csv key is
##      its position there). Variants share the keyword, so
##      its rule is written once. A token may take another palette colour
##      where the word belongs to another colour's rule (holograms are blue);
##      otherwise keywords are orange.
##   3. Run tools/loc.sh sync.
##   A status is a StatusResource here (see StatusModifier). One that works
##   differently on the player writes that rule in player_rule; its badge on
##   the player's ship reads it through the id plus PLAYER_SUFFIX, and a
##   token ticked player_side points there too.
##   A number the rule repeats from code is a {placeholder} the keyword's
##   _rule_values() fills ("Spends {spent} Jammed.").

## Appended to a status's id for its rule on the player (see
## StatusModifier.rule_term()).
const PLAYER_SUFFIX: String = "_you"

const KEYWORD_DIR: String = "res://Source/Content/Keywords/KeywordResources/"

## Keyword by id, loaded on first use.
static var _keywords: Dictionary[String, KeywordResource] = {}
## Every token, in a fixed order, each with its keyword.
static var _tokens: Array[KeywordToken] = []
static var _token_keywords: Array[KeywordResource] = []


## Replaces every keyword token with its styled label. Emits palette color
## names (=orange), so run it before format_text's palette substitution.
## With hoverable, each label also carries its term's id as a [url] tag, so a
## RichTextLabel can raise meta_hover_started for it.
static func render(text: String, hoverable: bool = false) -> String:
	_ensure_loaded()
	for i: int in _tokens.size():
		var token: KeywordToken = _tokens[i]
		if not text.contains(token.token):
			continue
		var meta_term: String = ""
		if hoverable:
			meta_term = _token_keywords[i].id()
			if token.player_side:
				meta_term += PLAYER_SUFFIX
		text = text.replace(token.token, _styled(token.display_label(), meta_term, token.color))
	return text


## The rule for a term id ("feed", or "jammed_you" for a status's rule on the
## player), or an empty string for an unknown one.
static func definition(term: String) -> String:
	var keyword: KeywordResource = _keyword_for(term)
	if keyword == null:
		return ""
	return keyword.display_player_rule() if _is_player_term(term) else keyword.display_rule()


## The title for a term id, as the rule's pop-up heads it: "Feed",
## "Jammed (you)". Empty for an unknown id.
static func title(term: String) -> String:
	var keyword: KeywordResource = _keyword_for(term)
	if keyword == null:
		return ""
	if _is_player_term(term):
		return "%s (%s)" % [keyword.display_title(), TranslationServer.translate(&"KEYWORD_PLAYER_TITLE")]
	return keyword.display_title()


## The keyword with id [param id] (a status's is a StatusResource), or null.
## For text, use title() and definition(), which also read player terms.
static func keyword(id: String) -> KeywordResource:
	_ensure_loaded()
	return _keywords.get(id)


## Every keyword id, sorted.
static func ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	result.assign(_keywords.keys())
	result.sort()
	return result


## The keyword for [param term] with any PLAYER_SUFFIX taken off.
static func _keyword_for(term: String) -> KeywordResource:
	_ensure_loaded()
	if _keywords.has(term):
		return _keywords[term]
	if _is_player_term(term):
		return _keywords.get(term.trim_suffix(PLAYER_SUFFIX))
	return null


## A player term is one only when its base is a keyword, so a keyword whose
## own id ends in the suffix still reads as itself.
static func _is_player_term(term: String) -> bool:
	return not _keywords.has(term) and term.ends_with(PLAYER_SUFFIX) \
		and _keywords.has(term.trim_suffix(PLAYER_SUFFIX))


static func _ensure_loaded() -> void:
	if not _keywords.is_empty():
		return
	for path: String in Utils.list_resource_paths(KEYWORD_DIR):
		var keyword: KeywordResource = load(path) as KeywordResource
		if keyword == null:
			continue
		_keywords[keyword.id()] = keyword
		for token: KeywordToken in keyword.tokens:
			_tokens.append(token)
			_token_keywords.append(keyword)


static func _styled(label: String, meta_term: String, color: String) -> String:
	var styled: String = "[color=" + color + "]" + label + "[/color]"
	if meta_term.is_empty():
		return styled
	return "[url=" + meta_term + "]" + styled + "[/url]"
