class_name GainShieldsHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	if data.multiply_shields:
		# Snapshot each target separately: a shared event would amplify every
		# ship from the first ship's shields.
		for target: Node in context.targets:
			if not is_instance_valid(target):
				continue
			var health: Health = target.get("health") as Health
			if health == null:
				continue
			var event: ShieldEvent = _make_event(context, [target])
			event.amount += roundi(health.shields * (data.multiplier - 1.0))
			event.amplification_unit = roundi(health.shields * data.multiplier)
			engine.inject_event(event)
	else:
		engine.inject_event(_make_event(context, context.targets.duplicate()))


func _make_event(context: EffectContext, targets: Array[Node]) -> ShieldEvent:
	var event: ShieldEvent = ShieldEvent.new()
	event.amount = context.running_amount
	_stamp(event, context)
	event.targets = targets
	return event
