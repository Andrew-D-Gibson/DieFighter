class_name Keywords
extends RefCounted
## Game terms written into descriptions as tokens, e.g. "(feed_right)".
##
## Utils.format_text() swaps each token for its styled label wherever text is
## shown. In the info panel the label is also hoverable: the panel looks the
## term up with definition() and pops its rule up, so descriptions never have
## to repeat the rules.
##
## HOW TO ADD A KEYWORD:
##   1. Add its definition to _DEFINITIONS, keyed by the term.
##   2. Add one row per token spelling to _TOKENS, pointing at that term.
##      Variants share a term, so its rule is written once. A row may set
##      "color" to a palette name where the word belongs to another colour
##      rule (holograms are blue); otherwise keywords are orange.


## Term -> rule, shown in a pop-up on hover. Terse and in the same palette as
## tile text: say what happens to the die, and what happens when it can't.
const _DEFINITIONS: Dictionary[String, String] = {
	"Feed": "The next tile that way uses the die. If it can't, [color=purple]target[/color] gets it.",
	"Fed": "Passed here by another tile's Feed.",
	"Burn": "At end of turn, take [color=red]damage[/color] equal to Burn, then lose 1 Burn.",
	"Scrambled": "Each die given to this ship flips to its opposite face ([color=yellow]1-6, 2-5, 3-4[/color]). Spends 1 Scrambled.",
	"Jammed": "Each die this ship uses does nothing and returns to you. Spends 1 Jammed.",
	"Exposed": "The next hit on this ship deals extra [color=red]damage[/color] equal to Exposed, then clears it.",
	"Hologram": "A copy of a die. Destroyed if given to another ship.",
	"Fleet": "Every die you own: in hand, on tiles, or held by enemies. Holograms count. Dice enemies hold when you jump are lost.",
}

## Token -> {label shown in the text, term it belongs to}.
const _TOKENS: Dictionary[String, Dictionary] = {
	"(feed_right)": {"label": "Feed right", "term": "Feed"},
	"(feed_left)":  {"label": "Feed left",  "term": "Feed"},
	"(feed_up)":    {"label": "Feed up",    "term": "Feed"},
	"(feed_down)":  {"label": "Feed down",  "term": "Feed"},
	"(feed_random)": {"label": "Feed a random neighbour", "term": "Feed"},
	"(fed)":        {"label": "Fed",        "term": "Fed"},
	"(burn)":       {"label": "Burn",       "term": "Burn"},
	"(scrambled)":  {"label": "Scrambled",  "term": "Scrambled"},
	"(scramble)":   {"label": "Scramble",   "term": "Scrambled"},
	"(jammed)":     {"label": "Jammed",     "term": "Jammed"},
	"(jam)":        {"label": "Jam",        "term": "Jammed"},
	"(exposed)":    {"label": "Exposed",    "term": "Exposed"},
	"(expose)":     {"label": "Expose",     "term": "Exposed"},
	"(fleet)":      {"label": "Fleet",      "term": "Fleet"},
	"(hologram)":   {"label": "hologram",   "term": "Hologram", "color": "blue"},
	"(holograms)":  {"label": "holograms",  "term": "Hologram", "color": "blue"},
	"(Hologram)":   {"label": "Hologram",   "term": "Hologram", "color": "blue"},
}

const _KEYWORD_COLOR: String = "orange"


## Replaces every keyword token with its styled label. Emits palette color
## names (=orange), so run it before format_text's palette substitution.
## With hoverable, each label also carries its term as a [url] tag, so a RichTextLabel
## can raise meta_hover_started for it.
static func render(text: String, hoverable: bool = false) -> String:
	for token: String in _TOKENS:
		var entry: Dictionary = _TOKENS[token]
		var meta_term: String = entry["term"] if hoverable else ""
		text = text.replace(token, _styled(entry["label"], meta_term, entry.get("color", _KEYWORD_COLOR)))
	return text


## The rule for a term, or an empty string for an unknown one.
static func definition(term: String) -> String:
	return _DEFINITIONS.get(term, "")


static func _styled(label: String, meta_term: String = "", color: String = _KEYWORD_COLOR) -> String:
	var styled: String = "[color=" + color + "]" + label + "[/color]"
	if meta_term.is_empty():
		return styled
	return "[url=" + meta_term + "]" + styled + "[/url]"
