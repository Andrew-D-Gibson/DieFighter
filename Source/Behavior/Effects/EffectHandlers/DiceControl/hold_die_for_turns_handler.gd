class_name HoldDieForTurnsHandler
extends EffectHandler
## Ends a chain by keeping the activator die on the source tile past the end
## of the turn, to come back to the hand `amount` turns from now (1 when
## unset). See HeldDieDelay.
##
## Only on the final repetition, like every die hand-off.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0:
		return
	if not is_instance_valid(context.activator_die) or context.effect_source is not Tile:
		return

	var event := HoldDieForTurnsEvent.new()
	_stamp(event, context)
	event.amount = maxi(1, data.amount)
	engine.inject_event(event)
