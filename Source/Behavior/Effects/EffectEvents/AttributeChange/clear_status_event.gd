class_name ClearStatusEvent
extends EffectEvent
## Removes a status from each target outright, whatever its stacks.

var status_id: StringName


## No amount: it removes the whole status.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		var status: StatusModifier = engine.find_status(target, status_id)
		if status:
			engine.remove_modifier(status)
