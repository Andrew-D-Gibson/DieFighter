class_name CombatScenarioResource
extends ScenarioResourceBase

@export var enemies_to_spawn: Array[EnemyResource]

func play() -> void:
	Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
	Globals.enemy_manager.spawn_enemies(enemies_to_spawn)
	Events.start_combat.emit()
	
	await Events.combat_finished
