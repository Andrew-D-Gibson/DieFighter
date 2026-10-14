class_name FeedAllyHandler
extends EffectHandler
## Hands the activator die to the ally the enemy's slot was bound to, on the
## chain's final repetition, like every other hand-off.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0:
		return
	if not is_instance_valid(context.activator_die):
		return

	var event := FeedAllyEvent.new()
	_stamp(event, context)
	event.ally = context.bound_target as Enemy
	event.relay_visited = context.relay_visited_with_actor()
	event.feed_depth = context.feed_depth
	engine.inject_event(event)
