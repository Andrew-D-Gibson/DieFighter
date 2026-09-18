class_name ScenarioResource
extends Resource

@export var map_icon: Texture2D
@export var background_resource: RandomBackgroundResource
@export var sector_gate_scenario: bool = false
@export var starting_enemies: Array[EnemyStateRewardResource]

@export var rewards: Dictionary[ScenarioManager.Faction, RewardResource]

## Optional recurring environmental event for this encounter (solar flare, ion
## storm, ...). Null means a plain, quiet fight.
@export var hazard: ScenarioHazardResource

var scenario_seed: int = 0
