class_name EnemyStateRewardResource
extends Resource

@export var enemy_resource: EnemyResource
@export_range(0.0, 1.0) var spawning_path_location: float = 0.5
@export var starting_state: ScenarioShipState
@export var reward_resource: RewardResource

## Fraction of max hull this ship arrives with. 1.0 is a fresh ship; lower
## values spawn it already hurt, which is how an encounter can start in the
## middle of a fight rather than at the beginning of one. Max health is
## unchanged, so the damage is visible on the ship's health bar.
@export_range(0.05, 1.0, 0.05) var starting_health_fraction: float = 1.0
