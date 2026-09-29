extends "res://test/helpers/die_fighter_test.gd"
## EnemyActionResource.get_threat(): what a die landing on an action means for
## the player. Drives the tractor beam's color and landing sound, so a wrong
## answer tells the player a harmless slot is dangerous (or the reverse).

const Cat := EffectEnums.Category
const Threat := EnemyActionResource.Threat


func _action(effects: Array[EffectData]) -> EnemyActionResource:
	var action := EnemyActionResource.new()
	action.effect_chain = Effects.chain(effects)
	return action


func _target_player() -> EffectData:
	return Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_PLAYER)


func _play_sound() -> EffectData:
	return Effects.data(Cat.AUDIO_VISUAL, EffectEnums.AudioVisualSubtype.PLAY_SOUND)


func _give_die(subtype: EffectEnums.DiceControlSubtype) -> EffectData:
	return Effects.data(Cat.DICE_CONTROL, subtype)


func test_an_action_with_no_chain_is_dead() -> void:
	assert_eq(EnemyActionResource.new().get_threat(), Threat.DEAD)


func test_an_empty_chain_is_dead() -> void:
	assert_eq(_action([]).get_threat(), Threat.DEAD)


func test_an_attack_is_dangerous() -> void:
	var attack := _action([_target_player(), Effects.die_value(), Effects.damage(),
		_give_die(EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER)])
	assert_eq(attack.get_threat(), Threat.DANGEROUS)


func test_passing_the_die_along_and_putting_on_a_show_is_dead() -> void:
	# The shape of do_nothing.tres: a shake, a sound, and the die handed back.
	var nothing := _action([
		Effects.data(Cat.AUDIO_VISUAL, EffectEnums.AudioVisualSubtype.SHAKE_DICE),
		_play_sound(),
		_give_die(EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER),
	])
	assert_eq(nothing.get_threat(), Threat.DEAD)


func test_every_die_handoff_counts_as_no_consequence() -> void:
	for subtype: EffectEnums.DiceControlSubtype in [
		EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER,
		EffectEnums.DiceControlSubtype.GIVE_DIE_TO_TARGET,
		EffectEnums.DiceControlSubtype.GIVE_DIE_AWAY,
		EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR,
	]:
		assert_eq(_action([_give_die(subtype)]).get_threat(), Threat.DEAD,
			EffectEnums.DiceControlSubtype.find_key(subtype))


func test_amount_math_and_utilities_have_no_consequence() -> void:
	var busywork := _action([
		Effects.set_amount(4), Effects.multiply(2.0),
		Effects.data(Cat.UTILITY, EffectEnums.UtilitySubtype.PRINT_DEBUG),
	])
	assert_eq(busywork.get_threat(), Threat.DEAD)


func test_non_damaging_effects_are_neutral() -> void:
	assert_eq(_action([Effects.shield()]).get_threat(), Threat.NEUTRAL, "shielding itself")
	assert_eq(_action([
		Effects.data(Cat.TILE_CONTROL, EffectEnums.TileControlSubtype.LOCKOUT_TILE)
	]).get_threat(), Threat.NEUTRAL, "locking a tile")
	assert_eq(_action([
		Effects.data(Cat.DICE_CONTROL, EffectEnums.DiceControlSubtype.REROLL_ALL)
	]).get_threat(), Threat.NEUTRAL, "dice control that isn't a handoff")


func test_damage_outranks_anything_before_it() -> void:
	var shield_then_hit := _action([Effects.shield(), Effects.damage()])
	assert_eq(shield_then_hit.get_threat(), Threat.DANGEROUS)


func test_damage_inside_either_conditional_branch_is_dangerous() -> void:
	var on_true := Effects.conditional(
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, [Effects.damage()], [])
	var on_false := Effects.conditional(
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, [], [Effects.damage()])
	assert_eq(_action([on_true]).get_threat(), Threat.DANGEROUS, "if_true branch")
	assert_eq(_action([on_false]).get_threat(), Threat.DANGEROUS, "if_false branch")


func test_a_nested_conditional_is_searched_all_the_way_down() -> void:
	var inner := Effects.conditional(
		EffectEnums.ConditionalSubtype.IF_OVERCHARGED, [Effects.damage()], [])
	var outer := Effects.conditional(
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, [], [inner])
	assert_eq(_action([outer]).get_threat(), Threat.DANGEROUS)


func test_a_conditional_with_only_a_show_in_it_stays_dead() -> void:
	var cosmetic := Effects.conditional(
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, [_play_sound()], [])
	assert_eq(_action([cosmetic]).get_threat(), Threat.DEAD)


func test_the_authored_attack_and_do_nothing_actions_classify_correctly() -> void:
	# Pin the real content too: if attack_player.tres stopped reading as
	# dangerous, every attack in the game would land with the harmless click.
	var attack: EnemyActionResource = load(
		"res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres")
	var nothing: EnemyActionResource = load(
		"res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")
	assert_eq(attack.get_threat(), Threat.DANGEROUS, "attack_player.tres")
	assert_eq(nothing.get_threat(), Threat.DEAD, "do_nothing.tres")
