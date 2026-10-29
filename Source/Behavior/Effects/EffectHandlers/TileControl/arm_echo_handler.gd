class_name ArmEchoHandler
extends EffectHandler
## Arms an echo (ArmEchoEvent). Runs on every repetition: each pass of a
## repeated chain is an activation of its own, and arms its own echo.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := ArmEchoEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
