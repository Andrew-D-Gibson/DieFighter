class_name ScenarioResource
extends ScenarioResourceBase

@export var map_icon: Texture2D
@export var component_scenarios: Array[ScenarioResourceBase]


func play() -> void:
	Events.start_scenario.emit()
	for scenario in component_scenarios:
		await scenario.play()
