## TargetEnemiesHandler
## Sets context.targets to all currently alive enemies.
## Replaces TargetAllShipsEffect / TargetEnemies pattern from old system.

class_name TargetEnemiesHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.targets = Globals.enemy_manager.get_alive_enemies()
