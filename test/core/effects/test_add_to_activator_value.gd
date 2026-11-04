extends "res://test/helpers/die_fighter_test.gd"
## ADD_TO_ACTIVATOR_VALUE (Bump): the step is the event's amount, so an
## Amplifier on the tile grows it, and the face never passes 6.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")


## A FakeDie that lands its new face straight away instead of tweening.
class RollingDie extends "res://test/helpers/fake_die.gd":
	func reroll_with_tween(new_value: int = 0) -> void:
		value = new_value


var engine: ScenarioEngine
var tile: Tile


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	tile = autofree(TILE_SCENE.instantiate())


func _bump(face: int, step: int = 1) -> RollingDie:
	var die: RollingDie = autofree(RollingDie.new(face))
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	var add := Effects.data(EffectEnums.Category.DICE_CONTROL,
			EffectEnums.DiceControlSubtype.ADD_TO_ACTIVATOR_VALUE)
	await Effects.chain([Effects.set_amount(step), add]).play(context, engine)
	return die


func test_raises_the_face_by_the_step() -> void:
	var die: RollingDie = await _bump(2)
	assert_eq(die.value, 3)


func test_an_amplifier_on_the_tile_grows_the_step() -> void:
	engine.add_modifier(AmplifierModifier.new(tile, 2))
	var die: RollingDie = await _bump(2)
	assert_eq(die.value, 5, "+1 amplified by +2 is +3")


func test_the_face_stops_at_six() -> void:
	engine.add_modifier(AmplifierModifier.new(tile, 2))
	var die: RollingDie = await _bump(5)
	assert_eq(die.value, 6)


func test_an_amplifier_on_another_tile_does_nothing() -> void:
	engine.add_modifier(AmplifierModifier.new(autofree(TILE_SCENE.instantiate()), 2))
	var die: RollingDie = await _bump(2)
	assert_eq(die.value, 3)
