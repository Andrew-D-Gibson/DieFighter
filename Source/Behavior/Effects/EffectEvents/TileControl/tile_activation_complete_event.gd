class_name TileActivationCompleteEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	Events.tile_activation_complete.emit()
