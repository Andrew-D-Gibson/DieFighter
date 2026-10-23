extends "res://test/helpers/die_fighter_test.gd"
## ION_DAMAGE (the Ion Shot): double damage to shields, none to the hull.
##
## The rule decided for what the shields can't absorb: it is lost. Ion never
## reaches the hull, so a ship with no shields shrugs it off entirely, and one
## with a few left loses just those.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Ships := preload("res://test/helpers/ships.gd")
const ION_SHOT: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/ion_shot.tres")

var engine: RecordingEngine
var health: Health


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	health = Health.new()
	health.max_health = 10
	health.starting_health = 10
	health.starting_shields = 10
	add_child_autofree(health)
	watch_signals(health)


func test_shields_take_double() -> void:
	assert_eq(health.take_ion_damage(3), 6)
	assert_eq(health.shields, 4)
	assert_eq(health.health, 10)
	assert_signal_emitted(health, "shields_damaged")
	assert_signal_not_emitted(health, "health_damaged")


func test_partly_depleted_shields_lose_the_rest_and_the_hull_is_untouched() -> void:
	health.shields = 4
	assert_eq(health.take_ion_damage(3), 4, "only what the shields held comes off")
	assert_eq(health.shields, 0)
	assert_eq(health.health, 10, "the leftover 2 is lost, never reaching the hull")
	assert_signal_emit_count(health, "shields_broken", 1)
	assert_signal_not_emitted(health, "health_damaged")


func test_no_shields_means_no_effect() -> void:
	health.shields = 0
	assert_eq(health.take_ion_damage(5), 0)
	assert_eq(health.health, 10)
	assert_signal_not_emitted(health, "shields_damaged")
	assert_signal_not_emitted(health, "health_damaged")


func test_invulnerable_ships_ignore_it() -> void:
	health.invulnerable = true
	assert_eq(health.take_ion_damage(3), 0)
	assert_eq(health.shields, 10)


func test_the_event_strips_a_targets_shields_only() -> void:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE, 7, 10))
	autofree(ship.health)
	ship.health.shields = 5
	var event := IonDamageEvent.new()
	event.amount = 2
	event.targets = [ship]
	event.resolve(engine)
	assert_eq(ship.health.shields, 1)
	assert_eq(ship.health.health, 7)


func test_handler_injects_one_ion_event_with_the_running_amount() -> void:
	var data := Effects.data(EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.ION_DAMAGE)
	var context := EffectContext.new()
	context.running_amount = 4
	var targets: Array[Node] = [health]
	context.targets = targets
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	assert_eq(engine.injected.size(), 1)
	assert_true(engine.injected[0] is IonDamageEvent)
	assert_eq(engine.injected[0].amount, 4)


func test_a_death_save_never_spends_the_drive_on_ion() -> void:
	var player := make_player(5)
	player.engine_charge = player.max_engine_charge
	var player_health: Health = autofree(Health.new())
	player_health.max_health = 1
	player_health.health = 1
	player.health = player_health
	Globals.player = player
	var hit := IonDamageEvent.new()
	hit.amount = 9
	hit.targets = [player]
	EngineDeathSaveModifier.new().on_before_event(hit, engine)
	assert_false(hit.canceled, "ion can't kill, so there is nothing to save")
	assert_eq(player.engine_charge, player.max_engine_charge)


func test_the_ion_shot_is_a_threat_that_returns_its_die() -> void:
	assert_eq(ION_SHOT.get_threat(), EnemyActionResource.Threat.DANGEROUS)
	var last: EffectData = ION_SHOT.effect_chain.effects[-1]
	assert_eq(last.category, EffectEnums.Category.DICE_CONTROL)
	assert_eq(last.subtype, EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER,
			"it fires a bolt, not the die, so the die goes home")
