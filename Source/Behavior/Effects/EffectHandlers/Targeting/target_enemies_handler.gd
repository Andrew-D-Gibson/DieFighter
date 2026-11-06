class_name TargetEnemiesHandler
extends EffectHandler
## Every living hostile ship. "Enemy" means a ship fighting the player: allies
## and civilians were swept in by this from before they existed, and "every
## enemy" never meant them (TargetRandomHostileEnemyHandler.hostiles_in is the
## one rule for who counts). Effects that mean every ship use TARGET_ALL_SHIPS.

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# A fresh array, not the manager's own list: later steps retarget the context.
	# "You" is never hit by everything at once (FateSelf, inside hostiles_in).
	context.targets = TargetRandomHostileEnemyHandler.hostiles_in(Globals.enemy_manager.get_alive_enemies())
