extends EffectEvent
## An event whose resolve() suspends until [signal released] fires, so a test
## can observe the engine mid-drain (e.g. shutting down under an await).

signal released()

var resolved: bool = false


func resolve(_engine: ScenarioEngine) -> void:
	await released
	resolved = true
