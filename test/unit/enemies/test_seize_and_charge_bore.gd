extends "res://test/helpers/die_fighter_test.gd"
## Seize (the one dice-thief action, which replaced Impound and Pilfer) and
## Charge Bore, as shipped: what their chains do, who uses them, and Charge
## Bore's promise that the shot it shows is the shot that lands.

const Ships := preload("res://test/helpers/ships.gd")
const ACTIONS := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/"
const ENEMIES := "res://Source/Content/Enemies/EnemyResources/"
const _DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")


## An authored action's name, read from its file so a rename needs no test edit.
static func _authored_name(file: String) -> String:
	return (load("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/" + file + ".tres") as EnemyActionResource).name


func _shipped(file: String) -> EnemyActionResource:
	return load(ACTIONS + file) as EnemyActionResource


func _steps(action: EnemyActionResource, category: EffectEnums.Category, subtype: int) -> int:
	var count: int = 0
	for effect: EffectData in action.effect_chain.effects:
		if effect and effect.category == category and effect.subtype == subtype:
			count += 1
	return count


func _die(face: int) -> Dice:
	var die: Dice = autofree(_DICE_SCENE.instantiate())
	die.value = face
	return die


func _holder() -> Enemy:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE))
	autofree(ship.health)
	ship.dice_manager = add_child_autofree(EnemyDiceManager.new())
	return ship


# ── Seize ──────────────────────────────────────────────────────────────────────

func test_impound_and_pilfer_are_gone() -> void:
	assert_false(ResourceLoader.exists(ACTIONS + "impound.tres"))
	assert_false(ResourceLoader.exists(ACTIONS + "pilfer.tres"))


func test_seize_takes_the_die_and_deals_no_damage() -> void:
	var seize := _shipped("seize.tres")
	assert_eq(_steps(seize, EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.DAMAGE), 0)
	assert_eq(_steps(seize, EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR), 1)
	assert_eq(_steps(seize, EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER), 0)
	assert_eq(seize.get_threat(), EnemyActionResource.Threat.DANGEROUS)
	assert_false("(amount)" in seize.description, "nothing to number")
	assert_not_null(seize.indicator_texture)
	assert_not_null(seize.info_texture)


## The die is the player's and stays with the thief, so nothing hurls it at
## them; the "STOLEN" callout floats off the ship holding it, as Charge
## Bore's "LOADED" does.
func test_seize_holds_the_die_rather_than_firing_it() -> void:
	var seize := _shipped("seize.tres")
	assert_eq(_steps(seize, EffectEnums.Category.AUDIO_VISUAL, EffectEnums.AudioVisualSubtype.ATTACK_TWEEN), 0)
	var aimed_at_self: bool = false
	var callout_on_self: bool = false
	for effect: EffectData in seize.effect_chain.effects:
		if effect.category == EffectEnums.Category.TARGETING:
			aimed_at_self = effect.subtype == EffectEnums.TargetingSubtype.TARGET_SELF
		elif effect.category == EffectEnums.Category.AUDIO_VISUAL \
				and effect.subtype == EffectEnums.AudioVisualSubtype.CALLOUT:
			callout_on_self = aimed_at_self
	assert_true(callout_on_self, "STOLEN pops over the thief")


func test_every_dice_thief_seizes_and_rolls_no_amount() -> void:
	var seize := _shipped("seize.tres")
	for file: String in ["dice_thief", "gaff", "gaff_raider", "conscriptor", "bastion_core",
			"sector_boss", "arc_dynamo", "tithe_collector"]:
		var enemy: EnemyResource = load(ENEMIES + file + ".tres")
		var found: bool = false
		for pool: EnemyTurnActionList in enemy.action_options:
			for option: EnemyActionOptionResource in pool.actions_possible:
				if option.base_action == seize:
					found = true
					assert_eq(option.max_amount, 0, file)
		assert_true(found, file)


func test_the_cutpurse_still_re_steals_and_bolts_with_the_haul() -> void:
	var thief: EnemyResource = load(ENEMIES + "dice_thief.tres")
	var kept_names: Array[String] = []
	for pool: EnemyTurnActionList in thief.action_options:
		for option: EnemyActionOptionResource in pool.actions_possible:
			if option.fills_kept_faces:
				kept_names.append(option.base_action.name)
	assert_true(_authored_name("seize") in kept_names, "a stolen die lands on Seize again")
	assert_true(_authored_name("getaway") in kept_names, "and the last pool flies off with it")


# ── Charge Bore ────────────────────────────────────────────────────────────────

func test_charge_bore_loads_its_die_and_gives_no_shields() -> void:
	var bore := _shipped("charge_weapon.tres")
	assert_eq(_steps(bore, EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.SHIELD), 0)
	assert_eq(_steps(bore, EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR), 1)
	assert_false(bore.only_grants_shields())
	assert_eq(bore.get_threat(), EnemyActionResource.Threat.DANGEROUS, "it promises a big hit")
	assert_true("damage" in bore.description)


func test_charge_bore_shows_the_range_its_siege_shot_fires_at() -> void:
	for file: String in ["siege_mortar", "fate_maw"]:
		var enemy: EnemyResource = load(ENEMIES + file + ".tres")
		var bore: EnemyActionOptionResource = null
		var shot: EnemyActionOptionResource = null
		for pool: EnemyTurnActionList in enemy.action_options:
			for option: EnemyActionOptionResource in pool.actions_possible:
				if option.base_action.name == "Charge Bore":
					bore = option
				elif option.base_action.name == _authored_name("siege_shot") and option.fills_kept_faces:
					shot = option
		assert_not_null(bore, file)
		assert_not_null(shot, file)
		assert_eq([bore.min_amount, bore.max_amount], [shot.min_amount, shot.max_amount], file)


func test_keeping_a_die_records_what_it_was_loaded_with() -> void:
	var ship := _holder()
	var event := KeepDieWithActorEvent.new()
	event.actor = ship
	event.activator_die = _die(3)
	event.amount = 11
	event.resolve(null)
	assert_eq(ship.loaded_amounts.get(event.activator_die, 0), 11)

	var plain := KeepDieWithActorEvent.new()
	plain.actor = ship
	plain.activator_die = _die(5)
	plain.resolve(null)
	assert_false(ship.loaded_amounts.has(plain.activator_die), "a Seize loads nothing")


func test_the_siege_shot_fires_for_the_amount_charge_bore_showed() -> void:
	var mortar: EnemyResource = load(ENEMIES + "siege_mortar.tres")
	var situation := EnemyActionSituation.new()
	situation.kept_faces = [4] as Array[int]
	situation.kept_amounts = {4: 37} as Dictionary[int, int]
	var loaded := EnemyActionSelector.roll(mortar.action_options[1], situation, [], mortar.face_bias)
	assert_eq(loaded[3].name, _authored_name("siege_shot"))
	assert_eq(loaded[3].intent_amount, 37, "not a fresh roll")


func test_a_kept_face_with_no_loaded_amount_rolls_its_own() -> void:
	var mortar: EnemyResource = load(ENEMIES + "siege_mortar.tres")
	var situation := EnemyActionSituation.new()
	situation.kept_faces = [2] as Array[int]
	var loaded := EnemyActionSelector.roll(mortar.action_options[1], situation, [], mortar.face_bias)
	assert_eq(loaded[1].name, _authored_name("siege_shot"))
	assert_between(loaded[1].intent_amount, 8, 40)


func test_the_situation_reads_loaded_amounts_off_kept_dice() -> void:
	var ship := _holder()
	var die := _die(6)
	ship.dice_manager.queue.append(die)
	ship.kept_dice.append(die)
	ship.loaded_amounts[die] = 9
	var situation := EnemyActionSituation.for_ship(ship, [ship])
	assert_eq(situation.kept_faces, [6] as Array[int])
	assert_eq(situation.kept_amounts.get(6, 0), 9)


func test_a_new_turn_forgets_what_was_loaded() -> void:
	var ship := _holder()
	ship.loaded_amounts[_die(2)] = 5
	ship.run_turn()
	assert_true(ship.loaded_amounts.is_empty())
