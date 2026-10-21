extends "res://test/helpers/die_fighter_test.gd"
## EnemyActionResource.get_outcome(): would spending a die on this action
## change anything right now? Jammed only spends a stack on a die that would,
## and a die whose action can no longer happen pops a "?" and does nothing.
## Also: a slot bound to a ship that leaves is never pointed at another.

const Ships := preload("res://test/helpers/ships.gd")
const Cat := EffectEnums.Category
const Outcome := EnemyActionResource.Outcome
const ENEMY_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyManager/enemy_manager.tscn")
const ACTIONS := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/"


func _ship(hull: int = 10, max_hull: int = 10) -> Enemy:
	var made: Enemy = Ships.ship(ScenarioManager.Faction.PIRATE, hull, max_hull)
	autofree(made.health)
	return autofree(made)


func _bound(subtype: EffectEnums.TargetingSubtype, effect: EffectData) -> EnemyActionResource:
	var effects: Array[EffectData] = [
		Effects.data(Cat.TARGETING, subtype),
		Effects.die_value(),
		effect,
		Effects.data(Cat.DICE_CONTROL, EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER),
	]
	return Ships.action("Bound", effects)


func _repair() -> EnemyActionResource:
	return _bound(EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY,
		Effects.data(Cat.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.HEAL))


func _aegis() -> EnemyActionResource:
	return _bound(EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY, Effects.shield())


func _raid() -> EnemyActionResource:
	return _bound(EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP, Effects.damage())


func _launch() -> EnemyActionResource:
	var effects: Array[EffectData] = [
		Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_SELF),
		Effects.data(Cat.SCENARIO_CONTROL, EffectEnums.ScenarioControlSubtype.LAUNCH_SHIP),
		Effects.data(Cat.DICE_CONTROL, EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER),
	]
	return Ships.action("Launch", effects)


# ── Idle: never going to do anything ──────────────────────────────────────────

func test_an_empty_slot_and_a_chainless_action_are_idle() -> void:
	assert_eq(EnemyActionResource.outcome_of(null), Outcome.IDLE)
	assert_eq(EnemyActionResource.new().get_outcome(), Outcome.IDLE)


func test_do_nothing_is_idle_and_an_attack_acts() -> void:
	assert_eq((load(ACTIONS + "do_nothing.tres") as EnemyActionResource).get_outcome(), Outcome.IDLE)
	assert_eq((load(ACTIONS + "attack_player.tres") as EnemyActionResource).get_outcome(), Outcome.ACTS)
	assert_eq(Ships.attack().get_outcome(), Outcome.ACTS)


func test_a_show_with_no_consequence_is_idle() -> void:
	var effects: Array[EffectData] = [
		Effects.data(Cat.AUDIO_VISUAL, EffectEnums.AudioVisualSubtype.SHAKE_DICE),
		Effects.data(Cat.DICE_CONTROL, EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER),
	]
	assert_eq(Ships.action("Show", effects).get_outcome(), Outcome.IDLE)


# ── Blocked: meant to act on a ship that's gone ───────────────────────────────

func test_support_acts_on_a_living_ally_and_is_blocked_once_it_dies() -> void:
	var ally := _ship(4, 10)
	for action: EnemyActionResource in [_repair(), _aegis()]:
		action.bound_target = ally
		assert_eq(action.get_outcome(), Outcome.ACTS, action.name)
	ally.health.health = 0
	for action: EnemyActionResource in [_repair(), _aegis()]:
		action.bound_target = ally
		assert_eq(action.get_outcome(), Outcome.BLOCKED)


func test_a_support_never_bound_is_blocked() -> void:
	assert_eq(_aegis().get_outcome(), Outcome.BLOCKED)
	assert_eq((load(ACTIONS + "repair_ally.tres") as EnemyActionResource).get_outcome(), Outcome.BLOCKED,
		"the authored Repair Beam, unbound")


func test_repairing_an_undamaged_ally_is_blocked() -> void:
	var repair := _repair()
	repair.bound_target = _ship(10, 10)
	assert_eq(repair.get_outcome(), Outcome.BLOCKED)


func test_a_raid_whose_prey_is_gone_is_blocked() -> void:
	var raid := _raid()
	var prey := _ship()
	raid.bound_target = prey
	assert_eq(raid.get_outcome(), Outcome.ACTS)
	prey.health.health = 0
	assert_eq(raid.get_outcome(), Outcome.BLOCKED)


func test_a_hologram_for_a_dead_ally_is_blocked() -> void:
	var loader := Ships.loader()
	var ally := _ship()
	loader.bound_target = ally
	assert_eq(loader.get_outcome(), Outcome.ACTS)
	ally.health.health = 0
	assert_eq(loader.get_outcome(), Outcome.BLOCKED)


func test_a_relay_with_no_ally_left_still_shields_itself() -> void:
	var relay := Ships.relay()
	var ally := _ship()
	relay.bound_target = ally
	ally.health.health = 0
	assert_eq(relay.get_outcome(), Outcome.ACTS, "the feed fails, the shield doesn't")


func test_a_freed_bound_ship_reads_as_gone() -> void:
	var repair := _repair()
	var ally: Enemy = Ships.ship(ScenarioManager.Faction.PIRATE, 4, 10)
	repair.bound_target = ally
	ally.health.free()
	ally.free()
	assert_eq(repair.get_outcome(), Outcome.BLOCKED)


func test_a_launch_is_blocked_while_the_hangar_is_full() -> void:
	var manager: EnemyManager = autofree(EnemyManager.new())
	Globals.enemy_manager = manager
	manager.max_ships_in_combat = 2
	manager.enemies = Ships.roster([_ship()])
	assert_eq(_launch().get_outcome(), Outcome.ACTS)
	manager.enemies = Ships.roster([_ship(), _ship()])
	assert_eq(_launch().get_outcome(), Outcome.BLOCKED)


# ── The die-use pop-up ─────────────────────────────────────────────────────────

func test_a_blocked_action_is_played_as_do_nothing_with_a_question_mark() -> void:
	var event := EnemyActionEvent.new()
	event.action = _aegis()
	var icon: Texture2D = event.settle_action()
	assert_eq(icon, EnemyActionEvent.BLOCKED_ICON)
	assert_eq(event.action.get_outcome(), Outcome.IDLE, "plays the '...' and hands the die back")
	assert_ne(event.action, load(ACTIONS + "do_nothing.tres"), "a copy, never the shared resource")


func test_an_acting_or_idle_action_keeps_its_own_icon() -> void:
	var attack: EnemyActionResource = load(ACTIONS + "attack_player.tres")
	var event := EnemyActionEvent.new()
	event.action = attack
	assert_eq(event.settle_action(), attack.info_texture)
	assert_eq(event.action, attack)

	var nothing: EnemyActionResource = load(ACTIONS + "do_nothing.tres")
	event.action = nothing
	assert_null(event.settle_action(), "Do Nothing has no icon of its own; its '...' says it")
	assert_eq(event.action, nothing)


func test_the_question_mark_is_sized_like_the_other_action_icons() -> void:
	var attack: EnemyActionResource = load(ACTIONS + "attack_player.tres")
	assert_eq(EnemyActionEvent.BLOCKED_ICON.get_size(), attack.info_texture.get_size())


func test_the_carriers_launch_icon_is_sized_like_the_other_action_icons() -> void:
	var launch: EnemyActionResource = load(ACTIONS + "launch_interceptor.tres")
	var attack: EnemyActionResource = load(ACTIONS + "attack_player.tres")
	assert_eq(launch.info_texture.get_size(), attack.info_texture.get_size())


# ── No transfer when a bound ship leaves ──────────────────────────────────────

func test_a_departed_target_is_never_replaced_by_another_ship() -> void:
	add_child_autofree(ENEMY_MANAGER_SCENE.instantiate())
	var medic := _ship()
	var first := _ship(4, 10)
	var second := _ship(4, 10)
	var tables: Array[EnemyActionResource] = [_repair()]
	medic.turn_actions = tables
	medic.turn_actions[0].bound_target = first

	first.health.health = 0
	Events.enemy_left.emit(first, ScenarioManager.Faction.PIRATE)

	assert_eq(medic.turn_actions[0].bound_target, first, "still aimed where the player saw it")
	assert_eq(medic.turn_actions[0].get_outcome(), Outcome.BLOCKED)
	assert_ne(medic.turn_actions[0].bound_target, second)
