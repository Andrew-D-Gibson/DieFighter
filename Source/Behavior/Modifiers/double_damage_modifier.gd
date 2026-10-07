class_name DoubleDamageModifier
extends Modifier


func _init() -> void:
	priority = 50
	modifier_name = "Double Damage"
	

func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	# Only apply to damage events
	if not event is DamageEvent:
		return

	if event.amount <= 0:
		return
	event.amount *= 2
	announce_triggered()


func get_trigger_text() -> String:
	return "x2"


func get_trigger_color() -> Color:
	return Globals.red
