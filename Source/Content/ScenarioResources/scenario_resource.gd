class_name ScenarioResource
extends Resource

@export var map_icon: Texture2D
@export var background_resource: BackgroundResource
@export var starting_enemies: Array[EnemyStateRewardResource]

@export var rewards: Dictionary[ScenarioManager.Faction, RewardResource]

var seed: int = 0
