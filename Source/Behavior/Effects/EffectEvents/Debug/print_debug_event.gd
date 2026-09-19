class_name PrintDebugEvent
extends EffectEvent

func resolve(_engine: ScenarioEngine) -> void:
	print(metadata["message"])
