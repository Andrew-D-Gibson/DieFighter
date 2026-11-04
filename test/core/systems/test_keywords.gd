extends "res://test/helpers/die_fighter_test.gd"
## Keywords: the terms descriptions write as tokens, loaded from their
## KeywordResources and looked up by id, so their text can be translated.

const _PALETTE_NAMES: Array[String] = ["red", "blue", "green", "yellow", "purple", "orange"]


## Expected text is built from each token's own data, so relabelling or
## recolouring a keyword never fails these; only the rendering is checked.
func test_a_token_renders_its_label_in_its_colour() -> void:
	for id: String in Keywords.ids():
		for token: KeywordToken in Keywords.keyword(id).tokens:
			assert_eq(Keywords.render(token.token),
				"[color=%s]%s[/color]" % [token.color, token.display_label()], token.token)


func test_a_hoverable_label_carries_its_keyword_id() -> void:
	for id: String in Keywords.ids():
		for token: KeywordToken in Keywords.keyword(id).tokens:
			var term: String = id + (Keywords.PLAYER_SUFFIX if token.player_side else "")
			assert_eq(Keywords.render(token.token, true),
				"[url=%s][color=%s]%s[/color][/url]" % [term, token.color, token.display_label()],
				"%s points at %s" % [token.token, term])


func test_titles_and_rules_are_looked_up_by_id() -> void:
	for id: String in Keywords.ids():
		var keyword: KeywordResource = Keywords.keyword(id)
		assert_eq(Keywords.title(id), keyword.display_title(), id)
		assert_eq(Keywords.definition(id), keyword.display_rule(), id)
		var player_term: String = id + Keywords.PLAYER_SUFFIX
		assert_eq(Keywords.definition(player_term), keyword.display_player_rule(), player_term)
		assert_true(Keywords.title(player_term).begins_with(keyword.display_title()), player_term)
		assert_ne(Keywords.title(player_term), Keywords.title(id), "the player's side is titled apart")
	var feed_title: String = Keywords.keyword("feed").display_title()
	assert_eq(Keywords.definition(feed_title), "", "a display name is not a key")
	assert_eq(Keywords.title("nope"), "")
	assert_eq(Keywords.definition("nope"), "")


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

## A number a rule may write as itself: one that isn't a tuning value.
const _LITERAL_NUMBERS_ALLOWED: Dictionary[String, String] = {
	"countdown": "0 is where a countdown goes off, not a setting",
}


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
	assert_false(StatusCatalog.ids().is_empty())
	for status_id: StringName in StatusCatalog.ids():
		var definition: StatusResource = StatusCatalog.find(status_id)
		assert_not_null(definition.icon, "%s has no badge icon" % status_id)
		assert_not_null(definition.info_icon, "%s has no info icon" % status_id)
		assert_has(_PALETTE_NAMES, definition.color, "%s's colour is a palette name" % status_id)
		var status: StatusModifier = StatusCatalog.create(status_id, null, 1)
		assert_eq(status.definition, definition)
		assert_eq(status.color, Globals.get(definition.color) as Color)
		assert_eq(status.icon, definition.icon)
		assert_eq(status.info_icon, definition.info_icon)
		assert_eq(status.icon.resource_path, "res://Assets/Textures/Statuses/%s.png" % status_id)


func test_a_keyword_that_isnt_a_status_isnt_in_the_catalog() -> void:
	assert_false(StatusCatalog.has(&"feed"))
	assert_null(StatusCatalog.find(&"feed"))
