class_name TargetEnemiesHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# A typed Array[Enemy] can't be cast to Array[Node]; it has to be copied.
	var targets: Array[Node] = []
	targets.assign(Globals.enemy_manager.get_alive_enemies())
	context.targets = targets
