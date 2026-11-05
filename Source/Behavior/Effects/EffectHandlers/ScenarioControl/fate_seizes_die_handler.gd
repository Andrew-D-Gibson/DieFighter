class_name FateSeizesDieHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: FateSeizesDieEvent = FateSeizesDieEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
