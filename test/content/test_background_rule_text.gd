extends "res://test/helpers/die_fighter_test.gd"
## Background rules and hazards are described by their resources alone: the
## numbers in their text come from the same data the rule runs on, so tuning a
## number updates what the player reads. The wording itself is free to change.

const RULE_DIR: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/"
const HAZARD_DIR: String = "res://Source/Resources/BackgroundResources/BackgroundHazards/"

## Matches a {placeholder} left unfilled.
var _placeholder: RegEx = RegEx.create_from_string(r"\{[^}]*\}")


func _rules() -> Array[BackgroundModifierResource]:
	var rules: Array[BackgroundModifierResource] = []
	for file: String in DirAccess.get_files_at(RULE_DIR):
		if file.ends_with(".tres"):
			rules.append(load(RULE_DIR + file))
	return rules


func _hazards() -> Array[BackgroundHazardResource]:
	var hazards: Array[BackgroundHazardResource] = []
	for file: String in DirAccess.get_files_at(HAZARD_DIR):
		if file.ends_with(".tres"):
			hazards.append(load(HAZARD_DIR + file))
	return hazards


func test_every_rule_has_something_to_say() -> void:
	assert_false(_rules().is_empty())
	for rule: BackgroundModifierResource in _rules():
		assert_false(rule.display_description().is_empty(), rule.resource_path)
		assert_false(rule.display_callout().is_empty(), rule.resource_path)


func test_every_rule_builds_its_script_and_names_it() -> void:
	for rule: BackgroundModifierResource in _rules():
		var mod: Modifier = rule.create_modifier()
		assert_not_null(mod, rule.resource_path)
		if mod:
			assert_eq(mod.get_script(), rule.modifier_script, rule.resource_path)
			assert_eq(mod.modifier_name, rule.modifier_name, rule.resource_path)


func test_the_doldrums_cap_and_its_text_share_one_number() -> void:
	var rule: BackgroundModifierResource = load(RULE_DIR + "doldrums.tres")
	var copy: BackgroundModifierResource = rule.duplicate()
	copy.parameters = {&"cap": 5} as Dictionary[StringName, Variant]
	var mod: AmountCapModifier = copy.create_modifier() as AmountCapModifier
	assert_eq(mod.cap, 5)
	assert_ne(copy.display_callout(), rule.display_callout(), "the callout follows the cap")
	assert_string_contains(copy.display_callout(), "5")
	assert_string_contains(copy.display_description(), "5")


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
	var hotter: BackgroundHazardResource = hazard.duplicate(true)
	var changed: bool = false
	for step: EffectData in hotter.effect_chain.effects:
		if step.category == EffectEnums.Category.AMOUNT_MODIFIER:
			step.amount = 57
			changed = true
	assert_true(changed, "the flare's chain still deals its damage through an amount step")
	for text: String in [hotter.display_description(), hotter.display_headline(), hotter.display_banner()]:
		assert_string_contains(text, "57", "every line quotes the chain's damage")


func test_no_hazard_or_rule_text_is_left_with_a_placeholder() -> void:
	for hazard: BackgroundHazardResource in _hazards():
		for text: String in [hazard.display_name(), hazard.display_description(),
				hazard.display_headline(), hazard.display_banner()]:
			assert_null(_placeholder.search(text), "%s: %s" % [hazard.resource_path, text])
	for rule: BackgroundModifierResource in _rules():
		for text: String in [rule.display_name(), rule.display_description(), rule.display_callout()]:
			assert_null(_placeholder.search(text), "%s: %s" % [rule.resource_path, text])
