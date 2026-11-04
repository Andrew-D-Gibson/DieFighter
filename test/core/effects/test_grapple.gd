extends "res://test/helpers/die_fighter_test.gd"
## GRAPPLE (Seize): the die sets off for the player's hand, the claw catches
## it, and it ends back in front of the ship that stole it.

const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const SEIZE: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/seize.tres")


func test_the_die_heads_home_then_is_reeled_back_upright() -> void:
	Globals.player = null
	var speed: float = Globals.animation_speed
	Globals.animation_speed = 4.0
	var ship: Node2D = add_child_autofree(Node2D.new())
	ship.global_position = Vector2(100.0, 20.0)
	var die: Dice = add_child_autofree(DICE_SCENE.instantiate())
	var start: Vector2 = Vector2(100.0, 40.0)
	die.global_position = start

	var event: GrappleEvent = GrappleEvent.new()
	event.actor = ship
	event.activator_die = die
	var finished: Array[bool] = [false]
	var run: Callable = func() -> void:
		await event.resolve(null)
		finished[0] = true
	run.call()

	var farthest: float = 0.0
	for _frame: int in range(600):
		if finished[0]:
			break
		farthest = maxf(farthest, die.global_position.distance_to(start))
		await get_tree().process_frame
	Globals.animation_speed = speed

	assert_true(finished[0], "the chain is released")
	assert_gt(farthest, 20.0, "it got well on its way home before the claw had it")
	assert_lt(die.global_position.distance_to(start), 3.0, "back in front of the ship")
	assert_almost_eq(die.rotation, 0.0, 0.01, "upright for the ship's hold")


func test_seize_grapples_before_it_calls_out_and_keeps_the_die() -> void:
	var kinds: Array[int] = []
	for step: EffectData in SEIZE.effect_chain.effects:
		if step.category == EffectEnums.Category.AUDIO_VISUAL or step.category == EffectEnums.Category.DICE_CONTROL:
			kinds.append(step.subtype if step.category == EffectEnums.Category.AUDIO_VISUAL else -1 - step.subtype)
	var grapple: int = kinds.find(EffectEnums.AudioVisualSubtype.GRAPPLE)
	var callout: int = kinds.find(EffectEnums.AudioVisualSubtype.CALLOUT)
	var keep: int = kinds.find(-1 - EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR)
	assert_true(grapple >= 0 and grapple < callout and callout < keep)
	assert_eq(kinds.find(EffectEnums.AudioVisualSubtype.STREAM), -1, "no motes from the health bar")
