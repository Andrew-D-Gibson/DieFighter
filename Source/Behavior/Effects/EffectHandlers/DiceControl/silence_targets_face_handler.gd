class_name SilenceTargetsFaceHandler
extends EffectHandler
## Silences each target's intent for the activator die's face, or for
## `amount` when it is set (see SilenceFaceEvent).


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	var face: int = data.amount
	if face <= 0:
		if not is_instance_valid(context.activator_die):
			return
		face = int(context.activator_die.get("value"))
	var event := SilenceFaceEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	event.face = face
	engine.inject_event(event)
