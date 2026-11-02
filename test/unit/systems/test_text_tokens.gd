extends "res://test/helpers/die_fighter_test.gd"
## TextTokens: {placeholders} in content text fill from the steps that mark
## them, in every language, and the lint finds what doesn't add up.

const _TOOL: GDScript = preload("res://Source/Systems/Localization/Tools/tile_text_tokens_tool.gd")


func after_each() -> void:
	ContentText.clear_cache()
	super()


func test_a_marked_step_fills_its_placeholder() -> void:
	var tile: TileResource = _tile("Deal [color=red]{damage} damage[/color]", [_step(&"damage", 5)])
	assert_eq(tile.display_description(), "Deal [color=red]5 damage[/color]")


func test_a_value_expression_picks_or_reshapes_the_number() -> void:
	var cost: EffectData = _step(&"cost", -3, "-amount")
	var cap: EffectData = _step(&"cap", 0, "range_max")
	cap.range_max = 6
	var times: EffectData = _step(&"times", 0, "multiplier")
	times.multiplier = 2.0
	var tile: TileResource = _tile("Spend {cost}, up to +{cap}, {times}x die", [cost, cap, times])
	assert_eq(tile.display_description(), "Spend 3, up to +6, 2x die")


func test_an_expression_can_build_on_another_token() -> void:
	# "or 9 if ...": a base 4 and an ADD 5 the text shows as their total,
	# whichever order the steps come in.
	var total: EffectData = _step(&"bonus_total", 5, "amount + damage")
	var tile: TileResource = _tile("{damage}, or {bonus_total}", [total, _step(&"damage", 4)])
	assert_eq(tile.display_description(), "4, or 9")
	assert_eq(TextTokens.problems(tile.description, tile), PackedStringArray())


func test_chain_and_check_bind_their_own_numbers() -> void:
	var tile: TileResource = _tile("the first {times} tiles until you own {dice} dice", [])
	tile.effect_chain.base_repetitions = 2
	tile.effect_chain.text_token = &"times"
	var check: ActivationResource = ActivationResource.new()
	check.threshold = 4
	check.text_token = &"dice"
	check.text_token_value = "threshold + 1"
	tile.activation_checks.append(check)
	assert_eq(tile.display_description(), "the first 2 tiles until you own 5 dice")


func test_the_countdown_binds_by_name() -> void:
	var tile: TileResource = _tile("(countdown) {countdown}", [])
	tile.countdown = 12
	assert_eq(tile.display_description(), "(countdown) 12")


func test_a_translation_fills_the_same_numbers() -> void:
	var tile: TileResource = load("res://Source/Content/Tiles/TileResources/amplifier.tres")
	var german: Translation = Translation.new()
	german.locale = "de"
	german.add_message(&"TILE.AMPLIFIER.DESC", &"Felder darüber und darunter: +{boost}")
	ContentText._translations["de"] = german
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var shown: String = tile.display_description()
	TranslationServer.set_locale(previous)
	assert_eq(shown, "Felder darüber und darunter: +2")


func test_problems_catch_unbound_and_disagreeing_tokens() -> void:
	var tile: TileResource = _tile("+{boost} and {missing}", [_step(&"boost", 2), _step(&"boost", 3)])
	var problems: PackedStringArray = TextTokens.problems(tile.description, tile)
	assert_eq(problems.size(), 2, str(problems))
	assert_string_contains(" ".join(problems), "{boost} is 2 on one step and 3 on another")
	assert_string_contains(" ".join(problems), "{missing} has no binding")


func test_a_broken_expression_is_a_problem_not_a_crash() -> void:
	var tile: TileResource = _tile("{oops}", [_step(&"oops", 1, "amount +")])
	assert_eq(tile.display_description(), "{oops}", "left unfilled")
	assert_eq(TextTokens.problems(tile.description, tile).size(), 2)


func test_literal_numbers_skip_tags_tokens_counters_and_placeholders() -> void:
	var text: String = "(die_5) -> Deal [color=red]3 damage[/color] ([data]hits * 2[/data]) {cap}, die +2, Hull hit -> -1, 4-6"
	assert_eq(TextTokens.literal_numbers(text), PackedStringArray(["3", "+2", "-1", "4", "6"]))


func test_the_converter_round_trips_tres_strings() -> void:
	var content: String = "[resource]\ntile_name = \"X\"\ndescription = \"say \\\"2\\\" \\\\ ok\"\nrarity = 1\n"
	assert_eq(_TOOL.read_property(content, &"description"), "say \"2\" \\ ok")
	var replaced: String = _TOOL.replace_property(content, &"description", "say \"2\" \\ ok", "say \"{n}\" \\ ok")
	assert_eq(_TOOL.read_property(replaced, &"description"), "say \"{n}\" \\ ok")
	assert_string_contains(replaced, "tile_name = \"X\"")
	assert_eq(_TOOL.replace_property(content, &"description", "not what's there", "x"), "", "refuses a stale value")


func _tile(description: String, steps: Array[EffectData]) -> TileResource:
	var tile: TileResource = TileResource.new()
	tile.description = description
	tile.effect_chain = EffectChain.new()
	tile.effect_chain.effects = steps
	return tile


func _step(token: StringName, amount: int, value: String = "") -> EffectData:
	var step: EffectData = EffectData.new()
	step.category = EffectEnums.Category.AMOUNT_MODIFIER
	step.amount = amount
	step.text_token = token
	step.text_token_value = value
	return step
