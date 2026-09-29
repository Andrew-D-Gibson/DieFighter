class_name VignettePulseEvent
extends EffectEvent

var color: Color = Color.WHITE


func resolve(_engine: ScenarioEngine) -> void:
	Events.vignette_pulse.emit(color)
