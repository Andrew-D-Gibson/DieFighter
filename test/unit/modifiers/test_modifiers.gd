extends "res://test/helpers/die_fighter_test.gd"
## Each Modifier's before-hook in isolation: which events it touches, and how.
## How they combine by priority is covered in integration/test_modifier_pipeline.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const RecordingEvent := preload("res://test/helpers/recording_event.gd")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var engine: RecordingEngine


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())


func _with_amount(event: EffectEvent, amount: int) -> EffectEvent:
	event.amount = amount
	return event


## A tile with no resource and outside the tree: enough to be an identity for
## modifiers to match on, without _ready() reaching for game systems.
func _bare_tile() -> Tile:
	return autofree(TILE_SCENE.instantiate())


# ── Amount changes ────────────────────────────────────────────────────────────

func test_double_damage_only_doubles_damage() -> void:
	var mod := DoubleDamageModifier.new()
	var hit := _with_amount(DamageEvent.new(), 3)
	var heal := _with_amount(HealEvent.new(), 3)
	mod.on_before_event(hit, engine)
	mod.on_before_event(heal, engine)
	assert_eq(hit.amount, 6)
	assert_eq(heal.amount, 3)


func test_amplifier_only_boosts_its_own_tiles_amplifiable_events() -> void:
	var tile := _bare_tile()
	var mod := AmplifierModifier.new(tile, 2)

	var own := _with_amount(DamageEvent.new(), 3)
	own.effect_source = tile
	var other := _with_amount(DamageEvent.new(), 3)
	other.effect_source = _bare_tile()
	var price := _with_amount(SpendEngineChargeEvent.new(), 3)
	price.effect_source = tile

	for event: EffectEvent in [own, other, price]:
		mod.on_before_event(event, engine)

	assert_eq(own.amount, 5)
	assert_eq(other.amount, 3, "another tile's event is untouched")
	assert_eq(price.amount, 3, "a price is not an output, so it isn't amplified")


func test_amount_cap_clamps_magnitude_both_ways() -> void:
	var mod := AmountCapModifier.new(3)
	var big_hit := _with_amount(DamageEvent.new(), 10)
	var big_drain := _with_amount(ChangeEngineChargeEvent.new(), -10)
	var small := _with_amount(ShieldEvent.new(), 2)
	for event: EffectEvent in [big_hit, big_drain, small]:
		mod.on_before_event(event, engine)
	assert_eq(big_hit.amount, 3)
	assert_eq(big_drain.amount, -3)
	assert_eq(small.amount, 2)


func test_amount_cap_ignores_events_whose_amount_is_not_a_quantity() -> void:
	var mod := AmountCapModifier.new(3)
	var other := _with_amount(RecordingEvent.new(), 10)
	mod.on_before_event(other, engine)
	assert_eq(other.amount, 10)


func test_amount_cap_is_never_below_one() -> void:
	assert_eq(AmountCapModifier.new(0).cap, 1)


# ── Blackouts (cancellation band) ─────────────────────────────────────────────

func test_engine_blackout_cancels_gains_but_not_spending() -> void:
	var mod := EngineBlackoutModifier.new()
	var gain := _with_amount(ChangeEngineChargeEvent.new(), 4)
	var loss := _with_amount(ChangeEngineChargeEvent.new(), -4)
	mod.on_before_event(gain, engine)
	mod.on_before_event(loss, engine)
	assert_true(gain.canceled)
	assert_false(loss.canceled)


func test_repair_blackout_cancels_healing_only() -> void:
	var mod := RepairBlackoutModifier.new()
	var heal := _with_amount(HealEvent.new(), 3)
	var hit := _with_amount(DamageEvent.new(), 3)
	mod.on_before_event(heal, engine)
	mod.on_before_event(hit, engine)
	assert_true(heal.canceled)
	assert_false(hit.canceled)


func test_shield_blackout_cancels_shield_gains_only() -> void:
	var mod := ShieldBlackoutModifier.new()
	var gain := _with_amount(ShieldEvent.new(), 3)
	var strip := _with_amount(ShieldEvent.new(), -3)
	mod.on_before_event(gain, engine)
	mod.on_before_event(strip, engine)
	assert_true(gain.canceled)
	assert_false(strip.canceled)


func test_reroll_blackout_cancels_both_kinds_of_reroll() -> void:
	var mod := RerollBlackoutModifier.new()
	var one := RerollActivatorEvent.new()
	var all := RerollAllDiceEvent.new()
	mod.on_before_event(one, engine)
	mod.on_before_event(all, engine)
	assert_true(one.canceled)
	assert_true(all.canceled)


# ── Tile activation ───────────────────────────────────────────────────────────

func test_activates_twice_only_on_its_face() -> void:
	var mod := ActivatesTwiceOnValueModifier.new(4)
	var on_four := TileActivationEvent.new()
	on_four.die_value = 4
	var on_five := TileActivationEvent.new()
	on_five.die_value = 5
	mod.on_before_event(on_four, engine)
	mod.on_before_event(on_five, engine)
	assert_eq(on_four.activation_repetitions, 2)
	assert_eq(on_five.activation_repetitions, 1)


func test_no_repetition_clamps_to_one() -> void:
	var event := TileActivationEvent.new()
	event.activation_repetitions = 4
	NoRepetitionModifier.new().on_before_event(event, engine)
	assert_eq(event.activation_repetitions, 1)


func test_lockout_cancels_its_tile_and_injects_the_lockout_beat() -> void:
	var tile := _bare_tile()
	var mod := LockoutModifier.new(tile)
	var locked := TileActivationEvent.new()
	locked.tile = tile
	var free := TileActivationEvent.new()
	free.tile = _bare_tile()

	mod.on_before_event(locked, engine)
	mod.on_before_event(free, engine)

	assert_true(locked.canceled)
	assert_false(free.canceled)
	var injected: Array[EffectEvent] = engine.injected_of(LockoutEffectEvent)
	assert_eq(injected.size(), 1)
	assert_same((injected[0] as LockoutEffectEvent).lockout_modifier, mod)


# ── Engine death save ─────────────────────────────────────────────────────────

func _armed_player(hull: int, shields: int) -> Player:
	var player := make_player(5)
	player.engine_charge = player.max_engine_charge
	var health: Health = autofree(Health.new())
	health.max_health = hull
	health.health = hull
	health.shields = shields
	player.health = health
	Globals.player = player
	return player


func test_death_save_cancels_a_killing_blow_and_spends_the_drive() -> void:
	var player := _armed_player(5, 2)
	var hit := _with_amount(DamageEvent.new(), 7)
	hit.targets = [player]
	EngineDeathSaveModifier.new().on_before_event(hit, engine)
	assert_true(hit.canceled)
	assert_eq(player.engine_charge, 0)


func test_death_save_ignores_a_blow_the_ship_survives() -> void:
	var player := _armed_player(5, 2)
	var hit := _with_amount(DamageEvent.new(), 6)
	hit.targets = [player]
	EngineDeathSaveModifier.new().on_before_event(hit, engine)
	assert_false(hit.canceled, "shields count toward surviving")
	assert_eq(player.engine_charge, player.max_engine_charge)


func test_death_save_needs_a_full_drive() -> void:
	var player := _armed_player(5, 0)
	player.engine_charge = player.max_engine_charge - 1
	var hit := _with_amount(DamageEvent.new(), 99)
	hit.targets = [player]
	EngineDeathSaveModifier.new().on_before_event(hit, engine)
	assert_false(hit.canceled)
