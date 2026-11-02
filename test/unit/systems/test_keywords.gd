extends "res://test/helpers/die_fighter_test.gd"
## Keywords: the terms descriptions write as tokens, loaded from their
## KeywordResources and looked up by id, so their text can be translated.

const _PALETTE_NAMES: Array[String] = ["red", "blue", "green", "yellow", "purple", "orange"]


func test_a_token_renders_its_label_in_its_colour() -> void:
	assert_eq(Keywords.render("(feed_right)"), "[color=orange]Feed right[/color]")
	assert_eq(Keywords.render("(holograms)"), "[color=blue]holograms[/color]")


func test_a_hoverable_label_carries_its_keyword_id() -> void:
	assert_eq(Keywords.render("(feed_left)", true), "[url=feed][color=orange]Feed left[/color][/url]")
	assert_eq(Keywords.render("(jammed_you)", true), "[url=jammed_you][color=orange]Jammed[/color][/url]",
		"a player-side token points at the player's rule")


func test_titles_and_rules_are_looked_up_by_id() -> void:
	assert_eq(Keywords.title("feed_across"), "Feed across")
	assert_string_contains(Keywords.definition("feed"), "next tile that way")
	assert_eq(Keywords.title("jammed_you"), "Jammed (you)")
	assert_string_contains(Keywords.definition("jammed_you"), "you place")
	assert_eq(Keywords.definition("Feed"), "", "the English name is no longer a key")
	assert_eq(Keywords.definition("burn_you"), "", "Burn has no player-side rule")
	assert_eq(Keywords.title("nope"), "")


func test_every_keyword_has_a_title_a_rule_and_a_token() -> void:
	for id: String in Keywords.ids():
		assert_false(Keywords.title(id).is_empty(), "%s has no title" % id)
		assert_false(Keywords.definition(id).is_empty(), "%s has no rule" % id)
		var keyword: KeywordResource = load(Keywords.KEYWORD_DIR + id + ".tres")
		assert_false(keyword.tokens.is_empty(), "%s can't be written in text" % id)


## format_text turns "=red" into a hex colour wherever it appears, so an id
## starting with a palette name would break its own [url=...] meta.
func test_no_id_starts_with_a_palette_colour() -> void:
	for id: String in Keywords.ids():
		for colour: String in _PALETTE_NAMES:
			assert_false(id.begins_with(colour), "%s would be mangled by format_text" % id)


func test_every_token_is_unique_and_bracketed() -> void:
	var seen: Dictionary[String, String] = {}
	for id: String in Keywords.ids():
		var keyword: KeywordResource = load(Keywords.KEYWORD_DIR + id + ".tres")
		for token: KeywordToken in keyword.tokens:
			assert_true(token.token.begins_with("(") and token.token.ends_with(")"), token.token)
			assert_false(seen.has(token.token), "%s is in %s and %s" % [token.token, seen.get(token.token, ""), id])
			seen[token.token] = id
			if token.player_side:
				assert_false(keyword.player_rule.is_empty(), "%s points at a player rule %s lacks" % [token.token, id])


func test_a_status_is_named_by_its_keyword() -> void:
	for status_id: StringName in StatusCatalog.ids():
		var status: StatusModifier = StatusCatalog.create(status_id, null, 1)
		assert_eq(status.display_name(), Keywords.title(String(status_id)))
		assert_false(status.display_name().is_empty(), "%s has no keyword title" % status_id)


func test_a_tile_shows_its_own_english() -> void:
	for id: String in ContentRegistry.get_tile_ids():
		var tile: TileResource = load(ContentRegistry.get_tile_path(id))
		assert_eq(tile.display_name(), tile.tile_name)
		# English is the field itself, its {numbers} filled from the tile's data.
		assert_eq(tile.display_description(), TextTokens.fill(tile.description, tile))


# ── Statuses: one StatusResource each, rule numbers from code ─────────────────

## What every status's rules read before their numbers became placeholders.
## Changing a status's tuning constant should change these, on purpose.
const _STATUS_RULES_IN_ENGLISH: Dictionary[String, String] = {
	"burn": "At the start of their turn, burned ships take [color=red]damage[/color] equal to Burn, then lose 1 Burn.",
	"exposed": "Each hit on this ship deals extra [color=red]damage[/color] equal to Exposed. Spends 1 Exposed.",
	"jammed": "The next die this ship uses does nothing. Spends 1 Jammed.",
	"jammed_you": "The next die you place on a tile does nothing and goes to [color=purple]target[/color]. Spends 1 Jammed.",
	"phased": "The next hit from the player's tiles passes through this ship and deals no [color=red]damage[/color], to shields or hull. Spends 1 Phased. Wears off when its turn starts.",
	"phased_you": "The next enemy hit passes through you and deals no [color=red]damage[/color], to shields or hull. Spends 1 Phased. Wears off when your next turn starts.",
	"scrambled": "Each die given to this ship flips to its opposite face ([color=yellow]1-6, 2-5, 3-4[/color]). Spends 1 Scrambled.",
	"scrambled_you": "Each die you place on a tile flips to its opposite face ([color=yellow]1-6, 2-5, 3-4[/color]) first. Spends 1 Scrambled.",
	"weakened": "This ship's hits deal 25% less [color=red]damage[/color], rounded down but never below 1. Loses 1 Weakened when its turn ends.",
	"weakened_you": "Your tiles' hits deal 25% less [color=red]damage[/color], rounded down but never below 1. Loses 1 Weakened when you end your turn.",
}

## What each status looked like when its colour and icons lived in its script.
const _STATUS_LOOKS: Dictionary[String, String] = {
	"burn": "orange", "exposed": "red", "jammed": "yellow",
	"phased": "blue", "scrambled": "green", "weakened": "purple",
}

## A number a rule may write as itself: one that isn't a tuning value.
const _LITERAL_NUMBERS_ALLOWED: Dictionary[String, String] = {
	"countdown": "0 is where a countdown goes off, not a setting",
}


func test_status_rules_read_as_they_always_have() -> void:
	for term: String in _STATUS_RULES_IN_ENGLISH:
		assert_eq(Keywords.definition(term), _STATUS_RULES_IN_ENGLISH[term], term)


func test_rule_numbers_come_from_the_code_that_applies_them() -> void:
	assert_eq(BurnStatus.rule_values(), {"lost": BurnStatus.LOST_PER_TICK})
	assert_eq(WeakenedStatus.rule_values()["percent"], 25)
	assert_eq(WeakenedStatus.rule_values()["min_hit"], WeakenedStatus.MIN_HIT)
	assert_eq(WeakenedStatus.weakened(2), WeakenedStatus.MIN_HIT, "the floor the rule quotes is the one applied")


## Every number a rule repeats from code is a {placeholder}. Die faces in
## yellow are faces, not settings, so they may be written out.
func test_no_rule_types_a_number_the_code_owns() -> void:
	var faces: RegEx = RegEx.create_from_string(r"\[color=yellow\][^\[]*\[/color\]")
	var digit: RegEx = RegEx.create_from_string(r"[0-9]")
	for id: String in Keywords.ids():
		if _LITERAL_NUMBERS_ALLOWED.has(id):
			continue
		var keyword: KeywordResource = Keywords.keyword(id)
		for english: String in [keyword.rule, keyword.player_rule]:
			var bare: String = faces.sub(english, "", true)
			assert_null(digit.search(bare), "%s types a number; make it a {placeholder}: %s" % [id, english])


func test_every_placeholder_in_a_rule_is_filled() -> void:
	for id: String in Keywords.ids():
		for term: String in [id, id + Keywords.PLAYER_SUFFIX]:
			assert_false(Keywords.definition(term).contains("{"), "%s leaves a placeholder unfilled" % term)


## Locked lists its unlocking faces rather than quoting one number, so this
## keeps the list in step with the lock.
func test_the_locked_rule_lists_the_faces_that_unlock() -> void:
	var faces: Array[int] = []
	var tagged: RegEx = RegEx.create_from_string(r"\[color=yellow\]([0-9])\[/color\]")
	for found: RegExMatch in tagged.search_all(Keywords.keyword("locked").rule):
		faces.append(int(found.get_string(1)))
	var expected: Array[int] = []
	for face: int in range(1, LockoutModifier.UNLOCK_BELOW):
		expected.append(face)
	assert_eq(faces, expected)


func test_each_status_is_one_status_resource() -> void:
	assert_eq(StatusCatalog.ids().size(), _STATUS_LOOKS.size())
	for status_id: StringName in StatusCatalog.ids():
		var definition: StatusResource = StatusCatalog.find(status_id)
		assert_not_null(definition.icon, "%s has no badge icon" % status_id)
		assert_not_null(definition.info_icon, "%s has no info icon" % status_id)
		assert_eq(definition.color, _STATUS_LOOKS.get(String(status_id), ""), "%s's colour" % status_id)
		var status: StatusModifier = StatusCatalog.create(status_id, null, 1)
		assert_eq(status.definition, definition)
		assert_eq(status.color, Globals.get(definition.color) as Color)
		assert_eq(status.icon, definition.icon)
		assert_eq(status.info_icon, definition.info_icon)
		assert_eq(status.icon.resource_path, "res://Assets/Textures/Statuses/%s.png" % status_id)


func test_a_keyword_that_isnt_a_status_isnt_in_the_catalog() -> void:
	assert_false(StatusCatalog.has(&"feed"))
	assert_null(StatusCatalog.find(&"feed"))
