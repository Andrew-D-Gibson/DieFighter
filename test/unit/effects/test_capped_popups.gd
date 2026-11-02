extends "res://test/helpers/die_fighter_test.gd"
## A capped amount (the Doldrums) pops as "12→3": the event remembers what the
## cap cut it down from, and the popup leads with that number, small and in
## the rule's colour. Uncapped popups stay a single number.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const _DOLDRUMS_PATH: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/doldrums.tres"

var engine: RecordingEngine


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())


func _doldrums() -> BackgroundModifierResource:
	return load(_DOLDRUMS_PATH) as BackgroundModifierResource


func _capped(event: EffectEvent, amount: int, cap: Modifier) -> EffectEvent:
	event.amount = amount
	cap.on_before_event(event, engine)
	return event


# ── The event ─────────────────────────────────────────────────────────────────

func test_a_capped_event_carries_its_uncapped_amount() -> void:
	var cap: Modifier = _doldrums().create_modifier()
	for event: EffectEvent in [DamageEvent.new(), HealEvent.new(), ShieldEvent.new()]:
		_capped(event, 12, cap)
		assert_eq(event.amount, 3)
		assert_eq(event.capped_from, 12)
		assert_eq(event.capped_by, cap)
		assert_eq(event.uncapped_for_popup(event.amount), 12)


func test_an_event_under_the_cap_carries_nothing() -> void:
	var event: EffectEvent = _capped(DamageEvent.new(), 2, _doldrums().create_modifier())
	assert_eq(event.amount, 2)
	assert_null(event.capped_by)
	assert_eq(event.uncapped_for_popup(event.amount), 0)
	assert_eq(event.uncapped_gain_text(), "")


func test_the_first_cap_keeps_the_uncapped_amount() -> void:
	var event: EffectEvent = _capped(DamageEvent.new(), 12, AmountCapModifier.new(5))
	AmountCapModifier.new(3).on_before_event(event, engine)
	assert_eq(event.amount, 3)
	assert_eq(event.capped_from, 12, "the popup shows what the hit would have been, not a halfway step")


func test_a_cut_cost_shows_no_popup_lead() -> void:
	var drain: EffectEvent = _capped(ChangeEngineChargeEvent.new(), -10, AmountCapModifier.new(3))
	assert_eq(drain.capped_from, -10, "costs are recorded too")
	assert_eq(drain.uncapped_for_popup(drain.amount), 0, "but a negative amount never leads a popup")


func test_no_lead_once_a_later_change_undoes_the_cut() -> void:
	var event: EffectEvent = _capped(DamageEvent.new(), 4, AmountCapModifier.new(3))
	event.amount = 6
	assert_eq(event.uncapped_for_popup(event.amount), 0)


func test_a_gain_leads_with_its_uncapped_gain() -> void:
	var heal: EffectEvent = _capped(HealEvent.new(), 12, AmountCapModifier.new(3))
	assert_eq(heal.uncapped_gain_text(), "+12")


func test_the_lead_takes_the_doldrums_colour() -> void:
	var rule: BackgroundModifierResource = _doldrums()
	var cap: Modifier = rule.create_modifier()
	assert_eq(cap.get_trigger_color(), rule.color)
	var event: EffectEvent = _capped(DamageEvent.new(), 12, cap)
	assert_eq(event.cap_color(), rule.color)


# ── The popup ─────────────────────────────────────────────────────────────────

## The labels of the popups floated under [param holder], left to right.
func _popup_texts(holder: Node) -> Array[Array]:
	var popups: Array[Array] = []
	for child: Node in holder.get_children():
		if child is not DamageNumber:
			continue
		var labels: Array[Label] = []
		for part: Node in child.get_children():
			if part is Label:
				labels.append(part as Label)
		labels.sort_custom(func(a: Label, b: Label) -> bool: return a.position.x < b.position.x)
		var texts: Array[String] = []
		for label: Label in labels:
			texts.append(label.text)
		popups.append(texts)
	return popups


func _target() -> Node2D:
	var holder: Node2D = add_child_autofree(Node2D.new())
	var target: Node2D = Node2D.new()
	holder.add_child(target)
	return target


func test_a_capped_hit_pops_twelve_then_three() -> void:
	var target: Node2D = _target()
	DamageNumber.spawn(target, 3, Globals.red, 12, Color.BLUE)
	assert_eq(_popup_texts(target.get_parent()), [["12", "3"]] as Array[Array])


func test_an_uncapped_hit_pops_one_number() -> void:
	var target: Node2D = _target()
	DamageNumber.spawn(target, 3, Globals.red)
	assert_eq(_popup_texts(target.get_parent()), [["3"]] as Array[Array])


func test_a_capped_gain_pops_its_uncapped_gain_first() -> void:
	var target: Node2D = _target()
	Juice.callout(target, "+3", Globals.green, false, "+12", Color.BLUE)
	assert_eq(_popup_texts(target.get_parent()), [["+12", "+3"]] as Array[Array])
