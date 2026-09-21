class_name EnemyStateRewardResource
extends Resource

@export var enemy_resource: EnemyResource
@export var starting_state: ScenarioShipState
@export var reward_resource: RewardResource

## Fraction of max hull this ship arrives with. 1.0 is a fresh ship; lower
## values spawn it already hurt, which is how an encounter can start in the
## middle of a fight rather than at the beginning of one. Max health is
## unchanged, so the damage is visible on the ship's health bar.
@export_range(0.05, 1.0, 0.05) var starting_health_fraction: float = 1.0


## Nails this ship to one spot along the enemy path, 0.0 (far left) to 1.0
## (far right). Negative means "wherever the formation puts you", which is the
## right answer almost always: [EnemyFormation] spreads the encounter's ships
## across whatever screen space is actually free, so a lone enemy centres
## itself, a wing spreads out, and everyone closes ranks as ships die.
##
## Only set this when an encounter is *about* where a ship is standing, and
## accept that it will not move out of the way of the shop or the tutorial.
@export_range(-1.0, 1.0, 0.01) var path_location_override: float = -1.0


func has_fixed_position() -> bool:
	return path_location_override >= 0.0
