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
	assert_eq(callout.callout, "...")
	assert_not_null(callout.callout_texture)
	assert_eq(callout.callout_texture.resource_path, "res://Assets/Textures/UI/do_nothing.png")
	assert_true(callout.juice_flags & JuiceEvent.Flag.BIG != 0)


func test_a_big_callout_prints_at_double_size() -> void:
	var anchor: Node2D = add_child_autofree(Node2D.new())
	for big: bool in [false, true]:
		var event: JuiceEvent = JuiceEvent.new()
		event.kind = EffectEnums.AudioVisualSubtype.CALLOUT
		var targets: Array[Node] = [anchor]
		event.targets = targets
		event.text = "..."
		event.callout_texture = load("res://Assets/Textures/UI/do_nothing.png") as Texture2D
		event.flags = JuiceEvent.Flag.BIG if big else 0
		await event.resolve(null)

	var scales: Array[Vector2] = []
	for child: Node in anchor.get_children():
		if child is DamageNumber:
			scales.append((child as DamageNumber)._rest_scale)
	assert_eq(scales, [Vector2.ONE, Vector2.ONE * 2.0] as Array[Vector2])


func test_authored_sprite_keeps_its_colours_and_popup_animation() -> void:
	var callout: EffectData = _callout_of(load(_DO_NOTHING_PATH) as EnemyActionResource)
	var anchor: Node2D = add_child_autofree(Node2D.new())
	DamageNumber.spawn_text_at(anchor, Vector2(100, 100), callout.callout, callout.color,
		true, "", Color.WHITE, callout.callout_texture)
	var popup: DamageNumber = anchor.get_child(0) as DamageNumber
	assert_eq(popup._content_size, callout.callout_texture.get_size())
	assert_eq(popup._rest_scale, Vector2(2, 2))
	assert_true(popup.get_child(0) is Sprite2D)
	var sprite: Sprite2D = popup.get_child(0) as Sprite2D
	assert_eq(sprite.texture, callout.callout_texture)
	assert_eq(sprite.modulate, Color.WHITE, "Art colours must not inherit the text tint")
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_null(popup._label, "The sprite replaces the text")
	var start: Vector2 = popup.global_position
	await get_tree().create_timer(0.3).timeout
	assert_lt(popup.global_position.y, start.y, "The icon rises like the text did")
	await get_tree().create_timer(popup._lifetime + 0.5).timeout
	assert_false(is_instance_valid(popup), "The popup removes itself after fading")
