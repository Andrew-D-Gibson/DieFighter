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
##   A status that works differently on the player has a second term, its
##   name plus PLAYER_SUFFIX, which its badge shows on the player's ship.


## Appended to a status's term for its rule on the player (see
## StatusModifier.rule_term()).
const PLAYER_SUFFIX: String = " (you)"


## Term -> rule, shown in a pop-up on hover. Terse and in the same palette as
## tile text: say what happens to the die, and what happens when it can't.
const _DEFINITIONS: Dictionary[String, String] = {
	"Feed": "The next tile that way uses the die. If it can't, [color=purple]target[/color] gets it.",
	"Feed across": "The tile in the mirrored cell (same row, other side of the grid) uses the die. If it can't, [color=purple]target[/color] gets it.",
	"Fed": "Passed here by another tile's Feed.",
	"Burn": "At the start of their turn, burned ships take [color=red]damage[/color] equal to Burn, then lose 1 Burn.",
	"Scrambled": "Each die given to this ship flips to its opposite face ([color=yellow]1-6, 2-5, 3-4[/color]). Spends 1 Scrambled.",
	"Jammed": "The next die this ship uses does nothing. Spends 1 Jammed.",
	"Exposed": "Each hit on this ship deals extra [color=red]damage[/color] equal to Exposed. Spends 1 Exposed.",
	"Scrambled (you)": "Each die you place on a tile flips to its opposite face ([color=yellow]1-6, 2-5, 3-4[/color]) first. Spends 1 Scrambled.",
	"Jammed (you)": "The next die you place on a tile does nothing and goes to [color=purple]target[/color]. Spends 1 Jammed.",
	"Hologram": "A copy of a die. Destroyed if given to another ship.",
	"Load": "This ship keeps the die and uses it again next turn. Its Siege Shot is placed on that die's face.",
	"Steal": "This ship keeps the die. Next turn it uses it to Steal again. It drops what it holds if destroyed.",
	"Ion": "Deals double [color=blue]damage[/color] to shields and none to the hull. Damage the shields can't absorb is lost.",
	"Countdown": "Dice placed on this tile count it down by their value. At 0 it goes off and starts again, extra counts carried over. Starts full each fight.",
	"Boost": "If you have that much [color=purple]engine charge[/color], it's spent for the extra effect. If not, the tile works without it.",
	"Locked": "Dice given to this tile return to your hand. A [color=yellow]1[/color], [color=yellow]2[/color] or [color=yellow]3[/color] unlocks it instead and goes to a [color=purple]random enemy[/color]. Lasts until unlocked or you jump. The Engine Charger can't be locked.",
}

## Token -> {label shown in the text, term it belongs to}.
const _TOKENS: Dictionary[String, Dictionary] = {
	"(feed_right)": {"label": "Feed right", "term": "Feed"},
	"(feed_left)":  {"label": "Feed left",  "term": "Feed"},
	"(feed_up)":    {"label": "Feed up",    "term": "Feed"},
	"(feed_down)":  {"label": "Feed down",  "term": "Feed"},
	"(feed_random)": {"label": "Feed a random neighbour", "term": "Feed"},
	"(feed_across)": {"label": "Feed across", "term": "Feed across"},
	"(fed)":        {"label": "Fed",        "term": "Fed"},
	"(burn)":       {"label": "Burn",       "term": "Burn"},
	"(scrambled)":  {"label": "Scrambled",  "term": "Scrambled"},
	"(scramble)":   {"label": "Scramble",   "term": "Scrambled"},
	"(jammed)":     {"label": "Jammed",     "term": "Jammed"},
	"(jam)":        {"label": "Jam",        "term": "Jammed"},
	"(jammed_you)": {"label": "Jammed",     "term": "Jammed (you)"},
	"(scrambled_you)": {"label": "Scrambled", "term": "Scrambled (you)"},
	"(exposed)":    {"label": "Exposed",    "term": "Exposed"},
	"(expose)":     {"label": "Expose",     "term": "Exposed"},
	"(load)":       {"label": "Load",       "term": "Load"},
	"(loaded)":     {"label": "Loaded",     "term": "Load"},
	"(steal)":      {"label": "Steal",      "term": "Steal"},
	"(stolen)":     {"label": "stolen",     "term": "Steal"},
	"(hologram)":   {"label": "hologram",   "term": "Hologram", "color": "blue"},
	"(holograms)":  {"label": "holograms",  "term": "Hologram", "color": "blue"},
	"(Hologram)":   {"label": "Hologram",   "term": "Hologram", "color": "blue"},
	"(ion_damage)": {"label": "ion damage", "term": "Ion", "color": "blue"},
	"(locked)":     {"label": "Locked",     "term": "Locked"},
	"(lock)":       {"label": "Lock",       "term": "Locked"},
	"(boost)":      {"label": "Boost",      "term": "Boost"},
	"(countdown)":  {"label": "Countdown",  "term": "Countdown"},
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
