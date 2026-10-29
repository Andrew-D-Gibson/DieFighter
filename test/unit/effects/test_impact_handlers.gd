extends "res://test/helpers/die_fighter_test.gd"
## The AUDIO_VISUAL impact verbs: HITSTOP, SLOW_MO, ZOOM_PUNCH, FLASH_TARGET,
## SCREEN_SHAKE, VIGNETTE_PULSE, GLITCH_BURST.
##
## Handlers only: each builds the right event from its EffectData, and builds
## nothing when the data asks for nothing. What the events then do to the
## camera and screen is feel, checked live rather than here.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Sub := EffectEnums.AudioVisualSubtype

var engine: RecordingEngine
var context: EffectContext


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	context = EffectContext.new()


func _data(subtype: Sub, amount: int = 0, multiplier: float = 1.0,
		color: Color = Color.WHITE) -> EffectData:
	var data := Effects.data(EffectEnums.Category.AUDIO_VISUAL, subtype, amount)
	data.multiplier = multiplier
	data.color = color
	return data


## Runs the registered handler, and returns the one event it produced (or
## null, failing the test, if it produced a different number).
func _apply_one(data: EffectData) -> EffectEvent:
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	assert_eq(engine.injected.size(), 1, "expected exactly one event")
	return engine.injected[0] if engine.injected.size() == 1 else null


func _apply_none(data: EffectData, why: String) -> void:
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	assert_eq(engine.injected.size(), 0, why)


func _target() -> Node2D:
	var node: Node2D = autofree(Node2D.new())
	context.targets = [node]
	return node


# ── What each handler builds ──────────────────────────────────────────────────

func test_hitstop_carries_its_duration() -> void:
	var event: EffectEvent = await _apply_one(_data(Sub.HITSTOP, 60))
	assert_is(event, HitstopEvent)
	assert_eq(event.amount, 60)


func test_slow_mo_carries_its_duration_and_time_scale() -> void:
	var event: EffectEvent = await _apply_one(_data(Sub.SLOW_MO, 250, 0.3))
	assert_is(event, SlowMoEvent)
	assert_eq(event.amount, 250)
	assert_almost_eq((event as SlowMoEvent).time_scale, 0.3, 0.0001)


func test_zoom_punch_carries_its_peak_and_the_targets() -> void:
	var target := _target()
	var event: EffectEvent = await _apply_one(_data(Sub.ZOOM_PUNCH, 0, 1.05))
	assert_is(event, ZoomPunchEvent)
	assert_almost_eq((event as ZoomPunchEvent).peak_zoom, 1.05, 0.0001)
	assert_eq(event.targets, [target] as Array[Node])


func test_flash_target_carries_its_color_and_the_targets() -> void:
	var target := _target()
	var event: EffectEvent = await _apply_one(_data(Sub.FLASH_TARGET, 0, 1.0, Color.RED))
	assert_is(event, FlashTargetEvent)
	assert_eq((event as FlashTargetEvent).color, Color.RED)
	assert_eq(event.targets, [target] as Array[Node])


func test_screen_shake_carries_its_strength() -> void:
	var event: EffectEvent = await _apply_one(_data(Sub.SCREEN_SHAKE, 2))
	assert_is(event, ScreenShakeEvent)
	assert_eq(event.amount, 2)


func test_vignette_pulse_carries_its_color() -> void:
	var event: EffectEvent = await _apply_one(_data(Sub.VIGNETTE_PULSE, 0, 1.0, Color.CYAN))
	assert_is(event, VignettePulseEvent)
	assert_eq((event as VignettePulseEvent).color, Color.CYAN)


func test_glitch_burst_carries_its_duration() -> void:
	var event: EffectEvent = await _apply_one(_data(Sub.GLITCH_BURST, 400))
	assert_is(event, GlitchBurstEvent)
	assert_eq(event.amount, 400)


func test_targets_are_copied_not_shared() -> void:
	# A later targeting step rewrites context.targets; an event queued earlier
	# must keep aiming where it was aimed.
	var target := _target()
	var event: EffectEvent = await _apply_one(_data(Sub.FLASH_TARGET))
	context.targets.clear()
	assert_eq(event.targets, [target] as Array[Node])


func test_events_are_stamped_with_the_chain_context() -> void:
	var actor: Node = autofree(Node.new())
	context.actor = actor
	context.effect_source = actor
	var event: EffectEvent = await _apply_one(_data(Sub.HITSTOP, 60))
	assert_eq(event.actor, actor)
	assert_eq(event.effect_source, actor)


# ── Data that asks for nothing builds nothing ─────────────────────────────────

func test_zero_duration_effects_build_nothing() -> void:
	await _apply_none(_data(Sub.HITSTOP, 0), "hitstop of 0 ms")
	await _apply_none(_data(Sub.SLOW_MO, 0, 0.3), "slow-mo of 0 ms")
	await _apply_none(_data(Sub.GLITCH_BURST, 0), "glitch of 0 ms")
	await _apply_none(_data(Sub.SCREEN_SHAKE, 0), "shake of strength 0")


func test_a_slow_mo_at_full_speed_or_faster_builds_nothing() -> void:
	await _apply_none(_data(Sub.SLOW_MO, 250, 1.0), "time scale 1.0 is not slow")
	await _apply_none(_data(Sub.SLOW_MO, 250, 1.5), "time scale above 1.0 is not slow")


func test_a_zoom_punch_that_does_not_zoom_in_builds_nothing() -> void:
	# multiplier defaults to 1.0, so an unconfigured punch must be a no-op.
	await _apply_none(_data(Sub.ZOOM_PUNCH, 0, 1.0), "peak zoom of 1.0")
	await _apply_none(_data(Sub.ZOOM_PUNCH, 0, 0.9), "peak zoom below 1.0")


func test_flash_target_without_targets_builds_nothing() -> void:
	context.targets = []
	await _apply_none(_data(Sub.FLASH_TARGET), "nothing to flash")


# ── Amplifiers ────────────────────────────────────────────────────────────────

func test_durations_and_strength_tiers_are_not_amplifiable() -> void:
	# An Amplifier grows an event's amount. On these that amount is a length or
	# a tier: amplifying it would stretch a freeze or turn a small shake into a
	# glitching one.
	for event: EffectEvent in [HitstopEvent.new(), SlowMoEvent.new(),
			ScreenShakeEvent.new(), GlitchBurstEvent.new()]:
		assert_false(event.is_amplifiable(), event.get_script().get_global_name())


# ── Authored flourishes (SHOCKWAVE .. DIE_FLARE, all JuiceHandler) ────────────

func test_flourishes_copy_authored_parameters_not_the_running_amount() -> void:
	context.running_amount = 99
	var data := _data(Sub.SHOCKWAVE, 24, 1.5, Color.RED)
	var event := await _apply_one(data) as JuiceEvent
	assert_eq(event.kind, Sub.SHOCKWAVE)
	assert_eq(event.amount, 24, "the ring's size, not the chain's number")
	assert_eq(event.multiplier, 1.5)
	assert_eq(event.color, Color.RED)
	assert_eq(context.running_amount, 99, "a flourish never touches the running amount")


func test_callout_substitutes_the_running_amount() -> void:
	context.running_amount = 7
	var data := _data(Sub.CALLOUT)
	data.string_param = "LINK x{amount}"
	var event := await _apply_one(data) as JuiceEvent
	assert_eq(event.text, "LINK x7")


func test_flourishes_are_not_amplifiable() -> void:
	var event := await _apply_one(_data(Sub.SPARK_BURST, 10)) as JuiceEvent
	assert_false(event.is_amplifiable(), "an Amplifier must not resize a spark burst")


func test_stream_carries_its_motion_flags() -> void:
	var data := _data(Sub.STREAM)
	data.juice_flags = JuiceEvent.Flag.OUTWARD | JuiceEvent.Flag.ENGINE
	var event := await _apply_one(data) as JuiceEvent
	assert_eq(event.flags, JuiceEvent.Flag.OUTWARD | JuiceEvent.Flag.ENGINE)


func test_shots_carry_their_color_and_length() -> void:
	for subtype: Sub in [Sub.LASER, Sub.MISSILE]:
		engine.injected.clear()
		var event := await _apply_one(_data(subtype, 300, 1.0, Color.RED)) as JuiceEvent
		assert_eq(event.kind, subtype)
		assert_eq(event.amount, 300, "the beam's hold or the flight, in msec")
		assert_eq(event.color, Color.RED)
		assert_false(event.is_amplifiable(), "an Amplifier must not stretch a shot")


func test_the_inspector_shows_a_shots_length_and_color() -> void:
	var category := EffectEnums.Category.AUDIO_VISUAL
	for subtype: Sub in [Sub.LASER, Sub.MISSILE]:
		assert_true(EffectCatalog.uses_field(category, subtype, "amount"))
		assert_true(EffectCatalog.uses_field(category, subtype, "color"))
		assert_false(EffectCatalog.uses_field(category, subtype, "juice_flags"))


func test_a_missile_lands_after_a_laser_and_its_length_is_its_flight() -> void:
	var laser := JuiceProjectile.new()
	var missile := JuiceProjectile.new()
	missile.style = JuiceProjectile.Style.MISSILE
	assert_lt(laser.impact_seconds(), missile.impact_seconds(),
		"a blaster bolt is quicker than a missile")
	missile.duration = 0.8
	assert_eq(missile.impact_seconds(), 0.8)
	laser.free()
	missile.free()


func test_a_blaster_bolt_travels_so_a_farther_target_is_hit_later() -> void:
	var near := JuiceProjectile.new()
	near.from = Vector2(150, 150)
	near.to = Vector2(150, 110)
	var far := JuiceProjectile.new()
	far.from = Vector2(150, 150)
	far.to = Vector2(150, 50)
	assert_gt(near.impact_seconds(), 0.06, "even point blank, it has to cross the gap")
	assert_lt(near.impact_seconds(), far.impact_seconds(), "farther targets are hit later")
	assert_lt(far.impact_seconds(), 0.4, "a long shot doesn't stall the chain")
	# The impact the chain waits on is fixed at launch, even if the target slides.
	var landing: float = far.impact_seconds()
	far.to = Vector2(150, 140)
	assert_eq(far.impact_seconds(), landing)
	far.duration = 0.5
	assert_almost_eq(far.impact_seconds(), 0.55, 0.001, "an authored flight time wins")
	near.free()
	far.free()


func test_the_inspector_shows_juice_flags_only_where_they_are_read() -> void:
	var category := EffectEnums.Category.AUDIO_VISUAL
	assert_true(EffectCatalog.uses_field(category, Sub.SPARK_BURST, "juice_flags"))
	assert_true(EffectCatalog.uses_field(category, Sub.STREAM, "juice_flags"))
	assert_true(EffectCatalog.uses_field(category, Sub.CALLOUT, "juice_flags"))
	assert_false(EffectCatalog.uses_field(category, Sub.BUMP, "juice_flags"))
	assert_false(EffectCatalog.uses_field(category, Sub.STREAM, "string_param"))
