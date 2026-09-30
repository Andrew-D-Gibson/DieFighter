class_name Keywords
extends RefCounted
## Game terms written into descriptions as tokens, e.g. "(feed_right)".
##
## Utils.format_text() swaps each token for its styled label wherever text is
## shown. glossary_for() lists the definitions a piece of text relies on, so a
## tile's info panel can explain every keyword it uses without each
## description having to repeat the rules.
##
## HOW TO ADD A KEYWORD:
##   1. Add its definition to _DEFINITIONS, keyed by the term.
##   2. Add one row per token spelling to _TOKENS, pointing at that term.
##      Directional variants share a term, so the glossary explains it once.


## Term -> plain-language rule. Written for a first-time player: say what
## happens to the die, and what happens when it goes wrong.
const _DEFINITIONS: Dictionary[String, String] = {
	"Feed": "The tile that way uses the die next. If it can't, your [color=purple]target[/color] gets it.",
}

## Token -> {label shown in the text, term it belongs to}.
const _TOKENS: Dictionary[String, Dictionary] = {
	"(feed_right)": {"label": "Feed right", "term": "Feed"},
	"(feed_left)":  {"label": "Feed left",  "term": "Feed"},
	"(feed_up)":    {"label": "Feed up",    "term": "Feed"},
	"(feed_down)":  {"label": "Feed down",  "term": "Feed"},
}

const _KEYWORD_COLOR: String = "orange"


## Replaces every keyword token with its styled label. Emits palette color
## names (=orange), so run it before format_text's palette substitution.
static func render(text: String) -> String:
	for token: String in _TOKENS:
		text = text.replace(token, _styled(_TOKENS[token]["label"]))
	return text


## A definition line for each distinct keyword that appears in the text, in
## the order they first appear. Empty when the text uses none.
static func glossary_for(text: String) -> String:
	# Term -> earliest position any of its tokens appears at.
	var first_seen: Dictionary[String, int] = {}
	for token: String in _TOKENS:
		var index: int = text.find(token)
		if index == -1:
			continue
		var term: String = _TOKENS[token]["term"]
		first_seen[term] = mini(index, first_seen.get(term, index))

	var terms: Array[String] = []
	terms.assign(first_seen.keys())
	terms.sort_custom(func(a: String, b: String) -> bool:
		return first_seen[a] < first_seen[b]
	)

	var lines: PackedStringArray = []
	for term: String in terms:
		lines.append(_styled(term) + ": " + _DEFINITIONS[term])
	return "\n".join(lines)


static func _styled(label: String) -> String:
	return "[color=" + _KEYWORD_COLOR + "]" + label + "[/color]"
