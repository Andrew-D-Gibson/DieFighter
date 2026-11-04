extends "res://test/helpers/die_fighter_test.gd"
## Background rules and hazards are described by their resources alone: the
## numbers in their text come from the same data the rule runs on, and the
## English the player reads is pinned here, so moving a number out of the
## prose into a {placeholder} never changes what is shown.

const RULE_DIR: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/"
const HAZARD_DIR: String = "res://Source/Resources/BackgroundResources/BackgroundHazards/"

## Rule file -> [description, callout] as the player reads them in English.
const RULE_TEXT: Dictionary[String, Array] = {
	"bloodhaze": ["No ship can [color=green]repair[/color] hull", "NO REPAIR"],
	"dead_systems": ["Each tile activates [color=green]once per turn[/color]. Engines are immune", "x1"],
	"doldrums": ["For [color=yellow]3 turns[/color], no effect can exceed [color=orange]3[/color]", "MAX 3"],
	"fates_corruption": ["No escape: you can't flee this fight", "NO ESCAPE"],
	"flash_freeze": ["Dice values [color=blue]cannot change[/color]: no rerolls, bumps or flips", "FROZEN"],
	"pulsar_wash": ["No ship can raise [color=blue]shields[/color]", "NO SHIELDS"],
	"shrapnel_wake": ["All [color=red]damage[/color] is doubled", "x2"],
}

const SOLAR_FLARE_TEXT: Dictionary[String, String] = {
	"description": "[color=yellow]Your turn starts[/color] ->\nRemove [color=blue]all shields[/color].\nDeal [color=red]3 damage[/color] to [color=purple]all ships[/color]",
	"headline": "[color=blue]shields[/color] drop, [color=red]3 dmg[/color] to all",
	"banner": "SHIELDS DOWN! 3 DAMAGE TO ALL",
}

## Matches a {placeholder} left unfilled.
var _placeholder: RegEx = RegEx.create_from_string(r"\{[^}]*\}")


func test_every_rule_reads_as_it_always_has_in_english() -> void:
	for file: String in RULE_TEXT:
		var rule: BackgroundModifierResource = load(RULE_DIR + file + ".tres")
		assert_eq(rule.display_description(), RULE_TEXT[file][0], file)
		assert_eq(rule.display_callout(), RULE_TEXT[file][1], file)


func test_every_authored_rule_is_pinned_above() -> void:
	for file: String in DirAccess.get_files_at(RULE_DIR):
		if file.ends_with(".tres"):
			assert_true(RULE_TEXT.has(file.get_basename()), "%s needs its English pinned here" % file)


func test_every_rule_builds_its_script_and_names_it() -> void:
	for file: String in RULE_TEXT:
		var rule: BackgroundModifierResource = load(RULE_DIR + file + ".tres")
		var mod: Modifier = rule.create_modifier()
		assert_not_null(mod, file)
		if mod:
			assert_eq(mod.get_script(), rule.modifier_script, file)
			assert_eq(mod.modifier_name, rule.modifier_name, file)


func test_the_doldrums_cap_and_its_text_share_one_number() -> void:
	var rule: BackgroundModifierResource = load(RULE_DIR + "doldrums.tres")
	var copy: BackgroundModifierResource = rule.duplicate()
	copy.parameters = {&"cap": 5} as Dictionary[StringName, Variant]
	var mod: AmountCapModifier = copy.create_modifier() as AmountCapModifier
	assert_eq(mod.cap, 5)
	assert_eq(copy.display_callout(), "MAX 5")
	assert_string_contains(copy.display_description(), "[color=orange]5[/color]")


func test_a_parameter_still_goes_through_the_modifiers_own_rules() -> void:
	var rule: BackgroundModifierResource = BackgroundModifierResource.new()
	rule.modifier_script = AmountCapModifier
	rule.parameters = {&"cap": 0} as Dictionary[StringName, Variant]
	assert_eq((rule.create_modifier() as AmountCapModifier).cap, 1, "a cap is never below 1")


func test_a_rule_that_names_itself_is_handed_its_resource() -> void:
	var rule: BackgroundModifierResource = load(RULE_DIR + "dead_systems.tres")
	assert_eq((rule.create_modifier() as OncePerTurnModifier).rule, rule)


func test_the_solar_flare_reads_its_damage_from_its_chain() -> void:
	var hazard: BackgroundHazardResource = load(HAZARD_DIR + "solar_flare.tres")
	assert_eq(hazard.display_description(), SOLAR_FLARE_TEXT["description"])
	assert_eq(hazard.display_headline(), SOLAR_FLARE_TEXT["headline"])
	assert_eq(hazard.display_banner(), SOLAR_FLARE_TEXT["banner"])

	var hotter: BackgroundHazardResource = hazard.duplicate(true)
	for step: EffectData in hotter.effect_chain.effects:
		if step.category == EffectEnums.Category.AMOUNT_MODIFIER and step.amount == 3:
			step.amount = 5
	assert_eq(hotter.display_banner(), "SHIELDS DOWN! 5 DAMAGE TO ALL")


func test_no_hazard_or_rule_text_is_left_with_a_placeholder() -> void:
	for file: String in DirAccess.get_files_at(HAZARD_DIR):
		if not file.ends_with(".tres"):
			continue
		var hazard: BackgroundHazardResource = load(HAZARD_DIR + file)
		for text: String in [hazard.display_name(), hazard.display_description(),
				hazard.display_headline(), hazard.display_banner()]:
			assert_null(_placeholder.search(text), "%s: %s" % [file, text])
	for file: String in RULE_TEXT:
		var rule: BackgroundModifierResource = load(RULE_DIR + file + ".tres")
		for text: String in [rule.display_name(), rule.display_description(), rule.display_callout()]:
			assert_null(_placeholder.search(text), "%s: %s" % [file, text])
