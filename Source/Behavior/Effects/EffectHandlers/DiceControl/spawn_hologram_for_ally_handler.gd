class_name SpawnHologramForAllyHandler
extends EffectHandler
## Conjures a hologram for the ally the enemy's slot was bound to. Its face is
## the action's intent amount, clamped to a die face. Once per activation, on
## the final repetition, so the slot's intent stays a single, readable promise.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0:
		return

	var event := SpawnHologramForAllyEvent.new()
	_stamp(event, context)
	event.amount = clampi(context.enemy_intent_amount, 1, 6)
	event.ally = context.bound_target as Enemy
	event.relay_visited = FeedAllyHandler._visited_including_actor(context)
	event.feed_depth = context.feed_depth
	engine.inject_event(event)
