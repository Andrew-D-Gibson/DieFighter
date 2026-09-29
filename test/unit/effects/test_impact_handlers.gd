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
