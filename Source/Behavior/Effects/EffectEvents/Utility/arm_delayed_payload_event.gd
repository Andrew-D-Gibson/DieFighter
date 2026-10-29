class_name ArmDelayedPayloadEvent
extends EffectEvent
## Puts a DelayedPayload in play on the first target: a DelayedEffectData's
## steps, to play on a later turn with this event's amount.

var payload: DelayedEffectData


func resolve(engine: ScenarioEngine) -> void:
	if payload == null or targets.is_empty() or not is_instance_valid(targets[0]):
		return
	var host: Node2D = targets[0] as Node2D
	if host == null:
		return
	var armed := DelayedPayload.new(host, effect_source as Node2D, payload, amount)
	engine.add_modifier(armed)
	armed.play_armed_feedback()
	provoke(host)


## The amount is what the payload will carry, not an output now. Whatever
## modifiers are in play when it goes off act on that hit instead, so an
## Amplifier isn't counted twice.
func is_amplifiable() -> bool:
	return false
