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
		assert_eq(tile.display_description(), tile.description)
