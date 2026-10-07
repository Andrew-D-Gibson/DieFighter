extends "res://test/helpers/die_fighter_test.gd"
## EffectCatalog / EffectEnums / EffectRegistry agreement.
##
## These are the guard rails for "an effect exists in code but can't be
## authored" and "an authored .tres silently became a different effect".

## Enum names in ordinal order, as they were when this test was written.
##
## Authored .tres files store category and subtype as raw ints, so these
## positions are load-bearing. New values may be APPENDED (the test only
## checks this list is a prefix). If this test fails because a value was
## inserted, reordered or renamed, every authored effect after it may now
## point at a different effect: fix the enum, don't update this list.
const _PINNED_ORDINALS: Dictionary = {
	"Category": [
		"TARGETING", "ATTRIBUTE_CHANGE", "AMOUNT_MODIFIER", "DICE_CONTROL",
		"AUDIO_VISUAL", "TILE_CONTROL", "SCENARIO_CONTROL", "CONDITIONAL",
		"REPETITION", "UTILITY",
	],
	"TARGETING": [
		"TARGET_ENEMIES", "TARGET_PLAYER", "TARGET_RANDOM_ENEMY", "TARGET_ALL_SHIPS",
		"TARGET_ALL_OTHER_SHIPS", "TARGET_RANDOM_SHIP", "TARGET_RANDOM_TILE",
		"TARGET_SURROUNDING_TILES", "TARGET_WITH_TARGETING_COMPUTER",
		"TARGET_TILE_WITH_OFFSET", "TARGET_EFFECT_SOURCE", "TARGET_SELF",
		"TARGET_RANDOM_OTHER_ENEMY", "TARGET_RANDOM_ADJACENT_TILE",
		"TARGET_BOUND_ALLY", "TARGET_BOUND_HOSTILE_SHIP",
	],
	"ATTRIBUTE_CHANGE": [
		"DAMAGE", "HEAL", "SHIELD", "CHANGE_ENGINE_CHARGE", "SPEND_ENGINE_CHARGE",
		"ADD_OVERCHARGE",
	],
	"AMOUNT_MODIFIER": [
		"SET", "ADD", "MULTIPLY", "ADD_ADJACENT_TILES", "ADD_TILE_DATA",
		"SET_TO_ENGINE_CHARGE", "SET_TO_DIE_VALUE", "SET_TO_ENEMY_INTENT",
		"ADD_EMPTY_ADJACENT_CELLS", "SET_TO_MISSING_CHARGE", "SET_TO_OVERCHARGE",
		"SET_TO_FEED_DEPTH", "SET_TO_ACTIVATIONS_THIS_TURN", "SET_TO_TARGET_STATUS",
		"SET_TO_DICE_OWNED", "SET_TO_DICE_IN_HAND", "SET_TO_TARGET_DICE_HELD",
	],
	"DICE_CONTROL": [
		"CHANGE_ACTIVATOR_VALUE", "REROLL_ACTIVATOR", "REROLL_ALL",
		"FLIP_ONES_AND_SIXES", "GIVE_DIE_TO_PLAYER", "GIVE_DIE_TO_TARGET",
		"GIVE_DIE_AWAY", "KEEP_DIE_WITH_TILE", "SPAWN_HOLOGRAPHIC_DIE",
		"RECEIVE_DIE_FROM_TARGET", "KEEP_DIE_WITH_ACTOR",
		"MERGE_HELD_DIE",
	],
	"AUDIO_VISUAL": [
		"SPAWN_HIT_PARTICLES", "SPAWN_EXPLOSION_PARTICLES", "ANIMATE_DIE_TO_TILE",
		"ATTACK_TWEEN", "SHAKE_DICE", "PLAY_SOUND", "WAIT", "HITSTOP", "SLOW_MO",
		"ZOOM_PUNCH", "FLASH_TARGET", "SCREEN_SHAKE", "VIGNETTE_PULSE",
		"GLITCH_BURST", "SHOCKWAVE", "SPARK_BURST", "CALLOUT", "BUMP", "ZAP",
		"GRID_RIPPLE", "SCREEN_RIPPLE", "STREAM", "DIE_FLARE",
	],
	"TILE_CONTROL": [
		"ACTIVATE_SELF", "ACTIVATE_TARGETED_TILES", "MOVE_TILE_WITH_OFFSET",
		"PUSH_TILE_IN_DIRECTION", "PULL_ROW_TILES_TO_COLUMN", "ADD_AMPLIFIER_MODIFIER",
		"LOCKOUT_TILE", "ADD_USES_REMAINING", "INCREMENT_TILE_DATA", "SET_TILE_DATA",
		"PUSH_TARGETED_TILES", "PASS_DIE_TO_TILE", "ADD_DEATH_SAVE_MODIFIER",
		"FEED_HOLOGRAM",
	],
	"SCENARIO_CONTROL": ["OPEN_SHOP", "CLOSE_SHOP", "JUMP", "FLEE", "MOVE_SHIP"],
	"CONDITIONAL": [
		"IF_ACTIVATOR_ODD", "IF_ENEMY_TARGETED", "IF_ENGINE_CHARGED",
		"IF_DIE_VALUE_IN_RANGE", "IF_TARGET_HOLDS_MATCHING_DIE", "IF_OVERCHARGED",
		"IF_FED", "IF_SOURCE_HOLDS_DIE", "IF_TARGET_HAS_STATUS",
		"IF_DICE_OWNED_IN_RANGE",
	],
	"REPETITION": ["ADD_REPETITIONS"],
	"UTILITY": ["DESTROY_SOURCE", "PRINT_DEBUG"],
}


func _assert_is_prefix(pinned: Array, current: Array, where: String) -> void:
	assert_true(current.size() >= pinned.size(),
		"%s lost values: had %d, now %d" % [where, pinned.size(), current.size()])
	for i: int in mini(pinned.size(), current.size()):
		assert_eq(current[i], pinned[i],
			"%s ordinal %d changed. Append new values; never insert." % [where, i])


func test_category_ordinals_are_append_only() -> void:
	_assert_is_prefix(_PINNED_ORDINALS["Category"], EffectEnums.Category.keys(), "Category")


func test_subtype_ordinals_are_append_only() -> void:
	for category: int in EffectEnums.Category.values():
		var category_name: String = EffectEnums.Category.find_key(category)
		var subtypes: Dictionary = EffectEnums.subtype_enum(category)
		_assert_is_prefix(_PINNED_ORDINALS[category_name], subtypes.keys(), category_name)


func test_catalog_agrees_with_the_enums() -> void:
	var problems: PackedStringArray = EffectCatalog.validate()
	assert_eq(problems.size(), 0, "\n".join(problems))


func test_every_implemented_row_builds_an_effect_handler() -> void:
	for entry: Dictionary in EffectCatalog.all():
		if entry.get("reserved", false):
			continue
		var handler: Variant = (entry["handler"] as Script).new()
		assert_true(handler is EffectHandler, "%s's handler is not an EffectHandler" % entry["label"])


func test_reserved_ordinals_are_not_offered_to_authors() -> void:
	for category: int in EffectEnums.Category.values():
		for entry: Dictionary in EffectCatalog.selectable_entries(category):
			assert_false(entry.get("reserved", false), "%s is reserved but offered" % entry["label"])


func test_uses_field_reflects_what_the_handler_reads() -> void:
	var amount_mod: int = EffectEnums.Category.AMOUNT_MODIFIER
	assert_true(EffectCatalog.uses_field(amount_mod, EffectEnums.AmountModifierSubtype.MULTIPLY, "multiplier"))
	assert_false(EffectCatalog.uses_field(amount_mod, EffectEnums.AmountModifierSubtype.MULTIPLY, "amount"))
	assert_true(EffectCatalog.uses_field(amount_mod, EffectEnums.AmountModifierSubtype.SET, "amount"))


func test_unknown_effects_have_no_entry_and_use_no_fields() -> void:
	assert_eq(EffectCatalog.get_entry(999, 0), {})
	assert_false(EffectCatalog.uses_field(999, 0, "amount"))


func test_registry_serves_one_shared_handler_per_effect() -> void:
	var cat: int = EffectEnums.Category.ATTRIBUTE_CHANGE
	var sub: int = EffectEnums.AttributeChangeSubtype.DAMAGE
	var handler: EffectHandler = EffectRegistry.get_handler(cat, sub)
	assert_true(handler is DealDamageHandler)
	assert_same(EffectRegistry.get_handler(cat, sub), handler, "handlers are stateless singletons")


func test_the_once_reserved_receive_die_ordinal_is_now_served() -> void:
	# Held back for years as the catalog's only reserved row; Repo Beam built
	# it. It must keep its ordinal so KEEP_DIE_WITH_ACTOR stays at 10.
	var handler: EffectHandler = EffectRegistry.get_handler(
		EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.RECEIVE_DIE_FROM_TARGET)
	assert_true(handler is ReceiveDieFromTargetHandler)
	assert_eq(EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR, 10)


func test_registry_refuses_stale_ordinals_loudly() -> void:
	assert_null(EffectRegistry.get_handler(EffectEnums.Category.UTILITY, 999))
	assert_push_error("No catalog row")
