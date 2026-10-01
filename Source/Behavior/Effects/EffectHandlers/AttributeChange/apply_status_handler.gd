class_name ApplyStatusHandler
extends EffectHandler
## Applies the status named by string_param to every target, with
## running_amount stacks — so stacks can come from the die, a tile's data, or
## anything else an AMOUNT_MODIFIER step can read.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	if not StatusCatalog.has(StringName(data.string_param)):
		push_error("ApplyStatusHandler: unknown status '%s'" % data.string_param)
		return

	var event: ApplyStatusEvent = ApplyStatusEvent.new()
	_stamp(event, context)
	event.status_id = StringName(data.string_param)
	event.amount = context.running_amount
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
