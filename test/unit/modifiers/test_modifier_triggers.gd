extends "res://test/helpers/die_fighter_test.gd"
## Modifiers announce through Events.modifier_triggered only when they actually
## changed something. The source tile flashes on every announcement, so an
## announcement that changed nothing would teach the player the flash is noise.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var engine: RecordingEngine
var _announced: Array[Modifier] = []


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	_announced.clear()
	Events.modifier_triggered.connect(_record)


func after_each() -> void:
	Events.modifier_triggered.disconnect(_record)
	super()


func _record(mod: Modifier) -> void:
	_announced.append(mod)


func _damage(amount: int) -> DamageEvent:
	var event: DamageEvent = DamageEvent.new()
	event.amount = amount
	return event


func _bare_tile() -> Tile:
	return autofree(TILE_SCENE.instantiate())


func test_double_damage_announces_only_when_it_doubles() -> void:
	var mod: DoubleDamageModifier = DoubleDamageModifier.new()
	mod.on_before_event(HealEvent.new(), engine)
	mod.on_before_event(_damage(0), engine)
	assert_eq(_announced.size(), 0, "a heal and a zero hit change nothing")

	mod.on_before_event(_damage(3), engine)
	assert_eq(_announced, [mod] as Array[Modifier])


func test_amount_cap_announces_only_when_it_clamps() -> void:
	var mod: AmountCapModifier = AmountCapModifier.new(3)
	mod.on_before_event(_damage(2), engine)
	assert_eq(_announced.size(), 0, "under the cap is untouched")

	mod.on_before_event(_damage(9), engine)
	assert_eq(_announced.size(), 1)


func test_no_repetition_announces_only_when_it_removes_a_repeat() -> void:
	var mod: NoRepetitionModifier = NoRepetitionModifier.new()
	var single: TileActivationEvent = TileActivationEvent.new()
	mod.on_before_event(single, engine)
	assert_eq(_announced.size(), 0)

	var doubled: TileActivationEvent = TileActivationEvent.new()
	doubled.activation_repetitions = 2
	mod.on_before_event(doubled, engine)
	assert_eq(_announced.size(), 1)


func test_amplifier_announces_on_its_own_tiles_events_and_carries_its_source() -> void:
	var amped: Tile = _bare_tile()
	var amplifier_tile: Tile = _bare_tile()
	var mod: AmplifierModifier = AmplifierModifier.new(amped, 2)
	mod.source = amplifier_tile

	var other: DamageEvent = _damage(3)
	other.effect_source = _bare_tile()
	mod.on_before_event(other, engine)
	assert_eq(_announced.size(), 0, "another tile's hit isn't boosted")

	var own: DamageEvent = _damage(3)
	own.effect_source = amped
	mod.on_before_event(own, engine)
	assert_eq(_announced.size(), 1)
	assert_eq(_announced[0].source, amplifier_tile)
	assert_eq(mod.get_trigger_text(), "+2")


func test_blackout_announces_when_it_cancels() -> void:
	var mod: ShieldBlackoutModifier = ShieldBlackoutModifier.new()
	var loss: ShieldEvent = ShieldEvent.new()
	loss.amount = -2
	mod.on_before_event(loss, engine)
	assert_eq(_announced.size(), 0, "losing shields isn't blocked")

	var gain: ShieldEvent = ShieldEvent.new()
	gain.amount = 2
	mod.on_before_event(gain, engine)
	assert_eq(_announced.size(), 1)
