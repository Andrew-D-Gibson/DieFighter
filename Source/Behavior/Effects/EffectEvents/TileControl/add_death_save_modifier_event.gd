class_name AddDeathSaveModifierEvent
extends EffectEvent
## Arms the engine death save, at most once.
##
## Idempotent because the tile re-arms every turn: the modifier is permanent
## and stateless, so stacking copies would do nothing but slow the pipeline.


func resolve(engine: ScenarioEngine) -> void:
	for mod: Modifier in engine.modifiers:
		if mod is EngineDeathSaveModifier:
			return

	engine.add_modifier(EngineDeathSaveModifier.new())
