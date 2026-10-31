extends "res://test/helpers/die_fighter_test.gd"
## The "..." a ship pops when it wastes a die (Do Nothing, a jam, a blocked
## action) prints big: it's the whole of what happened that turn.

const _DO_NOTHING_PATH: String = "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres"


func _callout_of(action: EnemyActionResource) -> EffectData:
	for data: EffectData in action.effect_chain.effects:
		if data.category == EffectEnums.Category.AUDIO_VISUAL \
				and data.subtype == EffectEnums.AudioVisualSubtype.CALLOUT:
			return data
	return null


func test_do_nothing_pops_a_big_ellipsis() -> void:
	# load(), not preload(): do_nothing.tres sits in a preload cycle.
	var callout: EffectData = _callout_of(load(_DO_NOTHING_PATH) as EnemyActionResource)
	assert_not_null(callout)
	assert_eq(callout.string_param, "...")
	assert_true(callout.juice_flags & JuiceEvent.Flag.BIG != 0)


func test_a_big_callout_prints_at_double_size() -> void:
	var anchor: Node2D = add_child_autofree(Node2D.new())
	for big: bool in [false, true]:
		var event: JuiceEvent = JuiceEvent.new()
		event.kind = EffectEnums.AudioVisualSubtype.CALLOUT
		var targets: Array[Node] = [anchor]
		event.targets = targets
		event.text = "..."
		event.flags = JuiceEvent.Flag.BIG if big else 0
		await event.resolve(null)

	var scales: Array[Vector2] = []
	for child: Node in anchor.get_children():
		if child is DamageNumber:
			scales.append((child as DamageNumber)._rest_scale)
	assert_eq(scales, [Vector2.ONE, Vector2.ONE * 2.0] as Array[Vector2])
