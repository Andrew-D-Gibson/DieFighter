class_name PrintDebugEvent
extends EffectEvent

var message: String = ""

func resolve(_engine: ScenarioEngine) -> void:
	print(message)
