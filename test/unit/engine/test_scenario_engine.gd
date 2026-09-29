extends "res://test/helpers/die_fighter_test.gd"
## ScenarioEngine's contract: queue order, injection order, the modifier hook
## pipeline, cancellation, the runaway-chain cap, and shutdown.
##
## Events and hooks in these tests don't await, so a drain runs to completion
## inside queue_event() and assertions can follow it directly.

const RecordingEvent := preload("res://test/helpers/recording_event.gd")
const GatedEvent := preload("res://test/helpers/gated_event.gd")
const SpyModifier := preload("res://test/helpers/spy_modifier.gd")

var engine: ScenarioEngine
var record: Array


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())
	record = []


func _event(label: String) -> RecordingEvent:
	return RecordingEvent.new(label, record)


func _spy(spy_name: String, priority: int) -> SpyModifier:
	return SpyModifier.new(spy_name, priority, record)


# ── Queue ordering ────────────────────────────────────────────────────────────

func test_events_queued_before_a_drain_resolve_in_fifo_order() -> void:
	# A gate holds the drain open so B and C queue up behind it.
	var gate := GatedEvent.new()
	engine.queue_event(gate)
	engine.queue_event(_event("B"))
	engine.queue_event(_event("C"))
	gate.released.emit()
	assert_eq(record, ["B", "C"])


func test_injected_events_resolve_right_after_the_current_event() -> void:
	var a := _event("A")
	a.on_resolve = func(e: ScenarioEngine) -> void:
		e.inject_event(_event("A1"))
		e.inject_event(_event("A2"))
	var gate := GatedEvent.new()
	engine.queue_event(gate)
	engine.queue_event(a)
	engine.queue_event(_event("B"))
	gate.released.emit()
	assert_eq(record, ["A", "A1", "A2", "B"],
		"injections keep their own order and jump ahead of B")


func test_queued_events_during_a_drain_go_to_the_back() -> void:
	var a := _event("A")
	a.on_resolve = func(e: ScenarioEngine) -> void:
		e.queue_event(_event("Z"))
	var gate := GatedEvent.new()
	engine.queue_event(gate)
	engine.queue_event(a)
	engine.queue_event(_event("B"))
	gate.released.emit()
	assert_eq(record, ["A", "B", "Z"])


func test_inject_outside_a_drain_just_queues() -> void:
	engine.inject_event(_event("A"))
	assert_eq(record, ["A"])
	assert_false(engine.currently_processing_queue)


func test_drain_signals_fire_once_per_drain() -> void:
	watch_signals(engine)
	var a := _event("A")
	a.on_resolve = func(e: ScenarioEngine) -> void:
		e.inject_event(_event("A1"))
	engine.queue_event(a)
	assert_signal_emit_count(engine, "began_processing_queue", 1)
	assert_signal_emit_count(engine, "finished_processing_queue", 1)
	assert_signal_emit_count(engine, "event_resolved", 2)


# ── Modifier pipeline ─────────────────────────────────────────────────────────

func test_add_modifier_keeps_the_list_sorted_by_priority() -> void:
	engine.add_modifier(_spy("late", 90))
	engine.add_modifier(_spy("early", 5))
	engine.add_modifier(_spy("mid", 50))
	var priorities: Array = engine.modifiers.map(func(m: Modifier) -> int: return m.priority)
	assert_eq(priorities, [5, 50, 90])


func test_hooks_wrap_resolution_in_priority_order() -> void:
	engine.add_modifier(_spy("second", 60))
	engine.add_modifier(_spy("first", 10))
	engine.queue_event(_event("event"))
	assert_eq(record, [
		"first:before", "second:before",
		"event",
		"first:after", "second:after",
	])


func test_cancelling_skips_later_hooks_resolution_and_after_hooks() -> void:
	var canceller := _spy("canceller", 5)
	canceller.before = func(ev: EffectEvent, _e: ScenarioEngine) -> void:
		ev.canceled = true
	engine.add_modifier(canceller)
	engine.add_modifier(_spy("later", 50))
	watch_signals(engine)

	var event := _event("event")
	engine.queue_event(event)

	assert_eq(record, ["canceller:before"])
	assert_signal_emitted_with_parameters(engine, "event_canceled", [event])
	assert_signal_not_emitted(engine, "event_resolved")


func test_a_cancelled_event_does_not_stop_the_rest_of_the_queue() -> void:
	var canceller := _spy("canceller", 5)
	canceller.before = func(ev: EffectEvent, _e: ScenarioEngine) -> void:
		if ev is RecordingEvent and (ev as RecordingEvent).label == "doomed":
			ev.canceled = true
	engine.add_modifier(canceller)
	var gate := GatedEvent.new()
	engine.queue_event(gate)
	engine.queue_event(_event("doomed"))
	engine.queue_event(_event("survivor"))
	record.clear()
	gate.released.emit()
	assert_has(record, "survivor")
	assert_does_not_have(record, "doomed")


func test_a_modifier_removed_mid_event_does_not_run_its_hooks() -> void:
	var victim := _spy("victim", 50)
	var remover := _spy("remover", 10)
	remover.before = func(_event: EffectEvent, e: ScenarioEngine) -> void:
		e.remove_modifier(victim)
	engine.add_modifier(victim)
	engine.add_modifier(remover)

	engine.queue_event(_event("event"))

	assert_does_not_have(record, "victim:before")
	assert_does_not_have(record, "victim:after")


func test_clear_temporary_modifiers_keeps_permanent_ones() -> void:
	var temp := _spy("temp", 10)
	temp.is_temporary = true
	var permanent := _spy("permanent", 20)
	engine.add_modifier(temp)
	engine.add_modifier(permanent)
	watch_signals(engine)

	engine.clear_temporary_modifiers()

	assert_eq(engine.modifiers, [permanent] as Array[Modifier])
	assert_signal_emitted_with_parameters(engine, "modifier_removed", [temp])


# ── Safety nets ───────────────────────────────────────────────────────────────

## Resolving one of these injects another, forever: two tiles activating each
## other, in miniature.
func _self_feeding_event() -> RecordingEvent:
	var ev := _event("loop")
	ev.on_resolve = func(e: ScenarioEngine) -> void:
		e.inject_event(_self_feeding_event())
	return ev


func test_a_self_feeding_chain_is_cut_off_instead_of_freezing() -> void:
	engine.queue_event(_self_feeding_event())

	assert_eq(record.size(), ScenarioEngine._MAX_EVENTS_PER_RUN)
	assert_true(engine.event_queue.is_empty(), "the remaining events are dropped")
	assert_false(engine.currently_processing_queue, "the engine is usable again")
	assert_push_error("aborted after")


func test_shutdown_mid_drain_releases_waiters_and_stops_the_queue() -> void:
	var gate := GatedEvent.new()
	engine.queue_event(gate)
	engine.queue_event(_event("never"))
	var temp := _spy("mod", 10)
	engine.add_modifier(temp)
	watch_signals(engine)

	engine.shutdown()

	assert_signal_emitted(engine, "finished_processing_queue",
		"anything awaiting the drain is released")
	assert_true(engine.is_shut_down())
	assert_true(engine.modifiers.is_empty())

	gate.released.emit()
	assert_does_not_have(record, "never",
		"the suspended drain bails on resuming rather than carrying on")


func test_a_shut_down_engine_ignores_new_events() -> void:
	engine.shutdown()
	engine.queue_event(_event("late"))
	assert_true(record.is_empty())


func test_current_is_null_without_a_scenario_manager() -> void:
	Globals.scenario_manager = null
	assert_null(ScenarioEngine.current())


func test_current_is_null_once_the_engine_is_shut_down() -> void:
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	assert_eq(ScenarioEngine.current(), engine)

	engine.shutdown()
	assert_null(ScenarioEngine.current())
