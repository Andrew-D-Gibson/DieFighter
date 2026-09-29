extends ScenarioEngine
## A ScenarioEngine that captures events instead of resolving them.
##
## Handlers only build events and hand them to the engine; resolving them is
## the engine's job and is tested separately. Capturing lets handler and chain
## tests assert on exactly what was produced, with no scene state required.

var injected: Array[EffectEvent] = []


func inject_event(event: EffectEvent) -> void:
	injected.append(event)


func queue_event(event: EffectEvent) -> void:
	injected.append(event)


func injected_of(script: Script) -> Array[EffectEvent]:
	return injected.filter(func(e: EffectEvent) -> bool:
		return is_instance_of(e, script)
	)
