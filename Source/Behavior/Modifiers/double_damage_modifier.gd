class_name DoubleDamageModifier
extends Modifier


func _init() -> void:
	priority = 50
	modifier_name = "Double Damage"
	

func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	# Only apply to damage events
	if not event is DamageEvent:
		return

	event.amount *= 2
