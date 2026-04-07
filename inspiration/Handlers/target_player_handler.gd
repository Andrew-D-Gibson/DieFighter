## TargetPlayerHandler
## Sets context.targets to the player.
## Enemies use this to target the player with their attacks.

class_name TargetPlayerHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.targets = [Globals.player]
