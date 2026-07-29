class_name ActivatesTwiceOnValueModifier
extends Modifier

## Doubles a tile's activation_repetitions when its activator die matches
## a specific face value (e.g. "tiles activated by a 4 activate twice").

var trigger_value: int = 4


func _init(value: int = 4) -> void:
	trigger_value = value
	priority = 50
	modifier_name = "Activates Twice on " + str(value) + "s"


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not TileActivationEvent:
		return
		
	var activation_event: TileActivationEvent = event as TileActivationEvent
	if activation_event.die_value != trigger_value:
		return

	activation_event.activation_repetitions *= 2
