extends "res://test/helpers/die_fighter_test.gd"
## Flash Freeze (DiceFreezeModifier): no die's face changes while it holds.
## Every event that changes a face says so (EffectEvent.changes_die_values),
## and the freeze cancels them all; Scrambled, which flips a die outside any
## event, asks the freeze itself.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const FLASH_FREEZE: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/flash_freeze.tres"

const DC := EffectEnums.DiceControlSubtype


## A FakeDie that lands its new face straight away instead of tweening, and
## rolls a 6 when asked for a random face.
class RollingDie extends "res://test/helpers/fake_die.gd":
	func reroll_with_tween(new_value: int = 0, _tween_time: float = 0.2) -> void:
		value = new_value if new_value != 0 else 6


var engine: ScenarioEngine
var freeze: DiceFreezeModifier
var tile: Tile


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	freeze = (load(FLASH_FREEZE) as BackgroundModifierResource).create_modifier()
	tile = autofree(TILE_SCENE.instantiate())


func _play(face: int, effects: Array[EffectData]) -> RollingDie:
	var die: RollingDie = autofree(RollingDie.new(face))
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await Effects.chain(effects).play(context, engine)
	return die


func _bump() -> Array[EffectData]:
	return [Effects.set_amount(1), Effects.data(EffectEnums.Category.DICE_CONTROL, DC.ADD_TO_ACTIVATOR_VALUE)]


func _reroll() -> Array[EffectData]:
	return [Effects.data(EffectEnums.Category.DICE_CONTROL, DC.REROLL_ACTIVATOR)]


## A tile that sets the die's face and then hands it to the target.
func _set_and_hand_off() -> Array[EffectData]:
	return [
		Effects.set_amount(6),
		Effects.data(EffectEnums.Category.DICE_CONTROL, DC.CHANGE_ACTIVATOR_VALUE),
		Effects.data(EffectEnums.Category.DICE_CONTROL, DC.GIVE_DIE_TO_TARGET),
	]


# ── The rule and its resource ────────────────────────────────────────────────

func test_flash_freeze_builds_the_freeze() -> void:
	assert_true(freeze is DiceFreezeModifier)
	assert_eq(freeze.modifier_name, "Flash Freeze")


func test_every_face_changing_event_says_so() -> void:
	for event: EffectEvent in [
		RerollActivatorEvent.new(), RerollAllDiceEvent.new(), ChangeHeldDiceEvent.new(),
		AddToActivatorValueEvent.new(), ChangeActivatorValueEvent.new(),
		FlipOnesAndSixesEvent.new(), MergeHeldDieEvent.new(),
	]:
		assert_true(event.changes_die_values(), event.get_script().get_global_name())


func test_events_that_only_move_a_die_dont() -> void:
	for event: EffectEvent in [GiveDieToPlayerEvent.new(), GiveDieToTargetEvent.new(), DamageEvent.new()]:
		assert_false(event.changes_die_values(), event.get_script().get_global_name())


# ── Without it, faces change; with it, they don't ────────────────────────────

func test_bump_raises_a_face_normally() -> void:
	var die: RollingDie = await _play(2, _bump())
	assert_eq(die.value, 3)


func test_bump_does_nothing_under_the_freeze() -> void:
	engine.add_modifier(freeze)
	watch_signals(Events)
	var die: RollingDie = await _play(2, _bump())
	assert_eq(die.value, 2)
	assert_signal_emitted_with_parameters(Events, "modifier_triggered", [freeze])


func test_a_reroll_does_nothing_under_the_freeze() -> void:
	var unfrozen: RollingDie = await _play(2, _reroll())
	assert_eq(unfrozen.value, 6, "control: the reroll lands")
	engine.add_modifier(freeze)
	var die: RollingDie = await _play(2, _reroll())
	assert_eq(die.value, 2)


func test_a_hand_off_that_sets_the_face_keeps_it_under_the_freeze() -> void:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	var die: RollingDie = autofree(RollingDie.new(2))
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await Effects.chain(_set_and_hand_off()).play(context, recorder)
	var set_face: Array[EffectEvent] = recorder.injected_of(ChangeActivatorValueEvent)
	assert_eq(set_face.size(), 1)
	freeze.on_before_event(set_face[0], recorder)
	assert_true(set_face[0].canceled, "the face change is stopped")
	var hand_off: Array[EffectEvent] = recorder.injected_of(GiveDieToTargetEvent)
	assert_eq(hand_off.size(), 1)
	freeze.on_before_event(hand_off[0], recorder)
	assert_false(hand_off[0].canceled, "the die is still handed over")


func test_scrambled_cant_turn_a_die_over_under_the_freeze() -> void:
	var enemy: Enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = 20
	enemy.health.health = 20
	var apply := ApplyStatusEvent.new()
	apply.status_id = &"scrambled"
	apply.amount = 1
	apply.targets = [enemy]
	await apply.resolve(engine)
	engine.add_modifier(freeze)
	var scrambled: ScrambledStatus = engine.find_status(enemy, &"scrambled")

	var die: Node = autofree(FakeDie.new(6))
	scrambled.on_die_arriving(die)
	assert_eq(die.value, 6, "handed over as rolled")
	assert_eq(scrambled.stacks, 1, "and the stack isn't spent on a flip that never happened")


# ── Merge: the weld is frozen, the held die still goes home ─────────────────

func test_a_merge_sends_the_held_die_home_as_its_own_event() -> void:
	var held: Dice = autofree(DICE_SCENE.instantiate())
	held.value = 3
	tile.dice_queue.queue.append(held)
	var activator: Dice = autofree(DICE_SCENE.instantiate())
	activator.value = 2

	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	var context := EffectContext.new()
	context.effect_source = tile
	context.activator_die = activator
	await Effects.chain([Effects.data(EffectEnums.Category.DICE_CONTROL, DC.MERGE_HELD_DIE)]).play(context, recorder)

	assert_eq(recorder.injected.size(), 2)
	assert_true(recorder.injected[0] is MergeHeldDieEvent)
	assert_eq((recorder.injected[0] as MergeHeldDieEvent).held_die, held)
	assert_true(recorder.injected[1] is GiveDieToPlayerEvent)
	assert_eq(recorder.injected[1].activator_die, held)

	freeze.on_before_event(recorder.injected[0], recorder)
	freeze.on_before_event(recorder.injected[1], recorder)
	assert_true(recorder.injected[0].canceled, "no weld")
	assert_false(recorder.injected[1].canceled, "but the held die goes home")
