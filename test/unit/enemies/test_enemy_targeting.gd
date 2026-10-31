extends "res://test/helpers/die_fighter_test.gd"
## Who enemy actions can act on: the faction table, the situation a roll reads,
## the conditions and weights that read it, and the binder that picks each
## slot's ship up front so its intent can name it.

const Ships := preload("res://test/helpers/ships.gd")
const Cat := EffectEnums.Category
const Faction := ScenarioManager.Faction
const Binding := EnemyActionResource.Binding
const REPAIR_BEAM := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/repair_ally.tres"
const AEGIS_LINK := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/aegis_ally.tres"


func before_each() -> void:
	super()
	RNGManager.seed_scenario(99)


func _ship(faction: Faction, hull: int = 10, max_hull: int = 10,
		attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE) -> Enemy:
	var made: Enemy = Ships.ship(faction, hull, max_hull, attitude)
	autofree(made.health)
	return autofree(made)


func _action(subtype: EffectEnums.TargetingSubtype) -> EnemyActionResource:
	var action := EnemyActionResource.new()
	var effects: Array[EffectData] = [Effects.data(Cat.TARGETING, subtype), Effects.damage()]
	action.effect_chain = Effects.chain(effects)
	return action


func _ally_action() -> EnemyActionResource:
	return _action(EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY)


func _raid_action() -> EnemyActionResource:
	return _action(EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP)


func _option(action: EnemyActionResource, weight: float = 1.0) -> EnemyActionOptionResource:
	var option := EnemyActionOptionResource.new()
	option.base_action = action
	option.weight = weight
	return option


func _condition(type: EnemyActionCondition.Type, invert: bool = false) -> EnemyActionCondition:
	var condition := EnemyActionCondition.new()
	condition.type = type
	condition.invert = invert
	return condition


func _roster(ships: Array) -> Array[Enemy]:
	var out: Array[Enemy] = []
	out.assign(ships)
	return out


# ── Factions ───────────────────────────────────────────────────────────────────

func test_pirates_and_their_boss_are_one_side() -> void:
	assert_true(FactionRelations.are_allied(Faction.PIRATE, Faction.PIRATE))
	assert_true(FactionRelations.are_allied(Faction.PIRATE, Faction.BOSS))
	assert_true(FactionRelations.are_allied(Faction.BOSS, Faction.PIRATE))


func test_civilians_stand_together() -> void:
	assert_true(FactionRelations.are_allied(Faction.CIVILIAN, Faction.CIVILIAN))
	assert_false(FactionRelations.are_hostile(Faction.CIVILIAN, Faction.CIVILIAN))


func test_pirates_prey_on_civilians_and_not_the_other_way_round_in_alliance() -> void:
	assert_true(FactionRelations.are_hostile(Faction.PIRATE, Faction.CIVILIAN))
	assert_true(FactionRelations.are_hostile(Faction.CIVILIAN, Faction.BOSS))
	assert_false(FactionRelations.are_allied(Faction.PIRATE, Faction.CIVILIAN))
	assert_false(FactionRelations.are_hostile(Faction.PIRATE, Faction.BOSS))


# ── The situation ──────────────────────────────────────────────────────────────

func test_allies_are_living_ships_on_the_same_side_other_than_itself() -> void:
	var pirate := _ship(Faction.PIRATE)
	var wingman := _ship(Faction.PIRATE)
	var boss := _ship(Faction.BOSS)
	var wreck := _ship(Faction.PIRATE, 0)
	var civilian := _ship(Faction.CIVILIAN)
	var allies := EnemyActionSituation.allies_of(pirate, _roster([pirate, wingman, boss, wreck, civilian]))
	assert_eq_deep(allies, _roster([wingman, boss]))


func test_hostile_ships_are_the_ones_its_faction_preys_on() -> void:
	var pirate := _ship(Faction.PIRATE)
	var wingman := _ship(Faction.PIRATE)
	var civilian := _ship(Faction.CIVILIAN)
	assert_eq_deep(EnemyActionSituation.hostile_ships_of(pirate, _roster([pirate, wingman, civilian])), _roster([civilian]))
	assert_eq_deep(EnemyActionSituation.hostile_ships_of(civilian, _roster([pirate, wingman, civilian])), _roster([pirate, wingman]))


func test_a_situation_reads_hull_and_attitude() -> void:
	var medic := _ship(Faction.PIRATE, 3, 10, Enemy.Attitude.NEUTRAL)
	var situation := EnemyActionSituation.for_ship(medic, _roster([medic]))
	assert_almost_eq(situation.health_fraction, 0.3, 0.001)
	assert_eq(situation.attitude, Enemy.Attitude.NEUTRAL)
	assert_true(situation.allies.is_empty())


# ── Gates derived from the chain ───────────────────────────────────────────────

func test_actions_report_what_they_bind() -> void:
	assert_eq(_ally_action().get_binding(), Binding.ALLY)
	assert_eq(_raid_action().get_binding(), Binding.HOSTILE_SHIP)
	assert_eq(_action(EffectEnums.TargetingSubtype.TARGET_PLAYER).get_binding(), Binding.NONE)


func test_the_shipped_support_actions_bind_an_ally() -> void:
	assert_eq((load(REPAIR_BEAM) as EnemyActionResource).get_binding(), Binding.ALLY)
	assert_eq((load(AEGIS_LINK) as EnemyActionResource).get_binding(), Binding.ALLY)


func test_an_ally_action_needs_an_ally() -> void:
	var medic := _ship(Faction.PIRATE)
	var option := _option(_ally_action())
	var alone := EnemyActionSituation.for_ship(medic, _roster([medic, _ship(Faction.CIVILIAN)]))
	var escorted := EnemyActionSituation.for_ship(medic, _roster([medic, _ship(Faction.PIRATE)]))
	assert_false(EnemyActionSelector.is_available(option, alone))
	assert_true(EnemyActionSelector.is_available(option, escorted))


func test_a_raid_needs_someone_to_raid() -> void:
	var pirate := _ship(Faction.PIRATE)
	var option := _option(_raid_action())
	assert_false(EnemyActionSelector.is_available(option, EnemyActionSituation.for_ship(pirate, _roster([pirate, _ship(Faction.PIRATE)]))))
	assert_true(EnemyActionSelector.is_available(option, EnemyActionSituation.for_ship(pirate, _roster([pirate, _ship(Faction.CIVILIAN)]))))


func test_a_lone_ship_never_rolls_an_ally_action() -> void:
	var medic := _ship(Faction.PIRATE)
	var pool := EnemyTurnActionList.new()
	var options: Array[EnemyActionOptionResource] = [_option(_ally_action(), 5.0)]
	pool.actions_possible = options
	for action: EnemyActionResource in EnemyActionSelector.roll(pool, EnemyActionSituation.for_ship(medic, _roster([medic]))):
		assert_eq(action.get_binding(), Binding.NONE)


# ── Authored conditions and weights ────────────────────────────────────────────

func test_ally_hurt_looks_at_the_allies_hull() -> void:
	var medic := _ship(Faction.PIRATE)
	var hurt := _ship(Faction.PIRATE, 4, 10)
	var condition := _condition(EnemyActionCondition.Type.ALLY_HURT)
	condition.hull_fraction = 0.5
	assert_true(condition.is_met(EnemyActionSituation.for_ship(medic, _roster([medic, hurt]))))
	assert_false(condition.is_met(EnemyActionSituation.for_ship(medic, _roster([medic, _ship(Faction.PIRATE, 9, 10)]))))


func test_self_hurt_and_attitude_and_invert() -> void:
	var ship := _ship(Faction.CIVILIAN, 2, 10, Enemy.Attitude.FRIENDLY)
	var situation := EnemyActionSituation.for_ship(ship, _roster([ship]))
	assert_true(_condition(EnemyActionCondition.Type.SELF_HURT).is_met(situation))

	var friendly := _condition(EnemyActionCondition.Type.ATTITUDE_IS)
	friendly.attitude = Enemy.Attitude.FRIENDLY
	assert_true(friendly.is_met(situation))
	friendly.invert = true
	assert_false(friendly.is_met(situation))


func test_an_unmet_condition_keeps_an_option_out() -> void:
	var ship := _ship(Faction.PIRATE)
	var option := _option(_action(EffectEnums.TargetingSubtype.TARGET_PLAYER))
	var needs_ally: Array[EnemyActionCondition] = [_condition(EnemyActionCondition.Type.ALLY_EXISTS)]
	option.conditions = needs_ally
	assert_false(EnemyActionSelector.is_available(option, EnemyActionSituation.for_ship(ship, _roster([ship]))))


func test_a_weight_rule_scales_only_while_its_condition_holds() -> void:
	var medic := _ship(Faction.PIRATE)
	var rule := EnemyActionWeightRule.new()
	rule.condition = _condition(EnemyActionCondition.Type.ALLY_HURT)
	rule.multiplier = 3.0
	var option := _option(_ally_action(), 2.0)
	var rules: Array[EnemyActionWeightRule] = [rule]
	option.situational_weights = rules
	assert_eq(option.weight_in(EnemyActionSituation.for_ship(medic, _roster([medic, _ship(Faction.PIRATE)]))), 2.0)
	assert_eq(option.weight_in(EnemyActionSituation.for_ship(medic, _roster([medic, _ship(Faction.PIRATE, 1)]))), 6.0)


func test_a_zero_multiplier_drops_an_option_from_the_fill() -> void:
	var ship := _ship(Faction.PIRATE)
	var never := _action(EffectEnums.TargetingSubtype.TARGET_PLAYER)
	never.name = "Never"
	var always := _action(EffectEnums.TargetingSubtype.TARGET_SELF)
	always.name = "Always"
	var rule := EnemyActionWeightRule.new()
	rule.condition = _condition(EnemyActionCondition.Type.ATTITUDE_IS)
	rule.multiplier = 0.0
	var dropped := _option(never, 5.0)
	var rules: Array[EnemyActionWeightRule] = [rule]
	dropped.situational_weights = rules
	var pool := EnemyTurnActionList.new()
	var options: Array[EnemyActionOptionResource] = [dropped, _option(always, 1.0)]
	pool.actions_possible = options
	for action: EnemyActionResource in EnemyActionSelector.roll(pool, EnemyActionSituation.for_ship(ship, _roster([ship]))):
		assert_eq(action.name, "Always")


# ── Binding ────────────────────────────────────────────────────────────────────

func test_an_ally_slot_binds_an_ally_never_itself_or_a_civilian() -> void:
	var medic := _ship(Faction.PIRATE)
	var wingman := _ship(Faction.PIRATE)
	var civilian := _ship(Faction.CIVILIAN)
	var roster := _roster([medic, wingman, civilian])
	for i: int in range(20):
		var tables: Array[EnemyActionResource] = [_ally_action()]
		medic.turn_actions = tables
		EnemyTargetBinder.bind(_roster([medic]), roster)
		assert_eq(medic.turn_actions[0].bound_target, wingman)


func test_a_raid_slot_binds_a_civilian() -> void:
	var pirate := _ship(Faction.PIRATE)
	var civilian := _ship(Faction.CIVILIAN)
	var tables: Array[EnemyActionResource] = [_raid_action()]
	pirate.turn_actions = tables
	EnemyTargetBinder.bind(_roster([pirate]), _roster([pirate, _ship(Faction.PIRATE), civilian]))
	assert_eq(pirate.turn_actions[0].bound_target, civilian)


func test_a_slot_that_binds_nothing_stays_unbound() -> void:
	var ship := _ship(Faction.PIRATE)
	var tables: Array[EnemyActionResource] = [_action(EffectEnums.TargetingSubtype.TARGET_PLAYER)]
	ship.turn_actions = tables
	EnemyTargetBinder.bind(_roster([ship]), _roster([ship, _ship(Faction.PIRATE)]))
	assert_null(ship.turn_actions[0].bound_target)


func test_every_ally_slot_of_a_ship_binds_the_same_ally() -> void:
	# One partner a turn: the targeting computer draws one arc per bound ship,
	# so a ship spread over three escorts would draw three.
	var medic := _ship(Faction.PIRATE)
	var roster := _roster([medic, _ship(Faction.PIRATE), _ship(Faction.PIRATE), _ship(Faction.PIRATE)])
	for run: int in range(20):
		RNGManager.seed_scenario(run)
		var tables: Array[EnemyActionResource] = []
		for i: int in range(6):
			tables.append(_ally_action())
		medic.turn_actions = tables
		EnemyTargetBinder.bind(_roster([medic]), roster)
		for action: EnemyActionResource in medic.turn_actions:
			assert_eq(action.bound_target, medic.turn_actions[0].bound_target)


func test_a_ship_keeps_one_ally_and_one_prey() -> void:
	var pirate := _ship(Faction.PIRATE)
	var roster := _roster([pirate, _ship(Faction.PIRATE), _ship(Faction.PIRATE),
		_ship(Faction.CIVILIAN), _ship(Faction.CIVILIAN)])
	for run: int in range(20):
		RNGManager.seed_scenario(run)
		var tables: Array[EnemyActionResource] = [
			_ally_action(), _raid_action(), _ally_action(), _raid_action(), _ally_action(), _raid_action(),
		]
		pirate.turn_actions = tables
		EnemyTargetBinder.bind(_roster([pirate]), roster)
		var ally: Enemy = pirate.turn_actions[0].bound_target
		var prey: Enemy = pirate.turn_actions[1].bound_target
		assert_eq(ally.scenario_state.faction, Faction.PIRATE)
		assert_eq(prey.scenario_state.faction, Faction.CIVILIAN)
		for slot: int in range(0, 6, 2):
			assert_eq(pirate.turn_actions[slot].bound_target, ally)
			assert_eq(pirate.turn_actions[slot + 1].bound_target, prey)


func test_each_ship_picks_its_own_partner() -> void:
	# The one-partner rule is per ship: two medics can still look after
	# different escorts.
	var a := _ship(Faction.PIRATE)
	var b := _ship(Faction.PIRATE)
	var roster := _roster([a, b, _ship(Faction.PIRATE), _ship(Faction.PIRATE)])
	var differed: bool = false
	for run: int in range(30):
		RNGManager.seed_scenario(run)
		var table_a: Array[EnemyActionResource] = [_ally_action(), _ally_action()]
		var table_b: Array[EnemyActionResource] = [_ally_action(), _ally_action()]
		a.turn_actions = table_a
		b.turn_actions = table_b
		EnemyTargetBinder.bind(_roster([a, b]), roster)
		assert_eq(a.turn_actions[1].bound_target, a.turn_actions[0].bound_target)
		assert_eq(b.turn_actions[1].bound_target, b.turn_actions[0].bound_target)
		differed = differed or a.turn_actions[0].bound_target != b.turn_actions[0].bound_target
	assert_true(differed, "ships don't all share one partner")


# ── The targeting step and the intent text ─────────────────────────────────────

func test_the_bound_targeting_step_targets_the_bound_ship() -> void:
	var ally := _ship(Faction.PIRATE)
	var context := EffectContext.new()
	context.bound_target = ally
	TargetBoundShipHandler.new().apply(Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY), context, null)
	assert_eq_deep(context.targets, [ally] as Array[Node])


func test_a_dead_or_missing_bound_ship_leaves_no_target() -> void:
	var context := EffectContext.new()
	var handler := TargetBoundShipHandler.new()
	var data := Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY)
	handler.apply(data, context, null)
	assert_true(context.targets.is_empty())

	context.bound_target = _ship(Faction.PIRATE, 0)
	handler.apply(data, context, null)
	assert_true(context.targets.is_empty())


func test_the_intent_names_the_bound_ship() -> void:
	var action := _ally_action()
	action.description = "Repairs (target) for (amount)"
	action.intent_amount = 4
	assert_eq(action.get_description_text(), "Repairs another ship for 4")
	action.bound_target = _ship(Faction.PIRATE)
	action.bound_target.enemy_resource.enemy_name = "Raider"
	assert_eq(action.get_description_text(), "Repairs Raider for 4")
