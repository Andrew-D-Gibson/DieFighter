class_name EnemyStateRewardResource
extends Resource

@export var enemy_resource: EnemyResource
## A ship state, or a standing branch (ScenarioShipStateStandingBranch) for a
## ship whose opening depends on what the player has done. Never a weighted
## roll: the opening is asked for before the ships spawn (EngineCharger), and
## a roll there would be rolled twice.
@export var starting_state: ScenarioShipStateBase
@export var reward_resource: RewardResource

## Fraction of max hull this ship arrives with. 1.0 is a fresh ship; lower
## values spawn it already hurt, which is how an encounter can start in the
## middle of a fight rather than at the beginning of one. Max health is
## unchanged, so the damage is visible on the ship's health bar.
@export_range(0.05, 1.0, 0.05) var starting_health_fraction: float = 1.0

## Spawns on exactly the hull and shields its EnemyResource authors (and
## starting_health_fraction cuts), whatever sector difficulty or a balance
## pass scales everyone else by. For scripted fights whose turns are counted
## out: the tutorial's opening ambush has to take two turns to win.
@export var unscaled_hull: bool = false


## Nails this ship to one spot along the enemy path, 0.0 (far left) to 1.0
## (far right). Negative means "wherever the formation puts you", which is the
## right answer almost always: [EnemyFormation] spreads the encounter's ships
## across whatever screen space is actually free, so a lone enemy centres
## itself, a wing spreads out, and everyone closes ranks as ships die.
##
## Only set this when an encounter is *about* where a ship is standing, and
## accept that it will not move out of the way of the shop or the tutorial.
@export_range(-1.0, 1.0, 0.01) var path_location_override: float = -1.0


## The state this ship opens the encounter in, as the run's standing has it
## now. Draws from no RNG stream, so it can be asked as often as needed.
func opening_state() -> ScenarioShipState:
	if starting_state == null:
		return null
	if starting_state is ScenarioShipStateProbabilityTransition:
		push_error("EnemyStateRewardResource: a ship can't open an encounter on a weighted roll.")
		return null
	return starting_state.resolve(enemy_resource.faction if enemy_resource else null)


func has_fixed_position() -> bool:
	return path_location_override >= 0.0


## This ship is a part of the scenario's hull (ScenarioResource.hull) rather
## than a ship of its own: it rides the hull at mount_offset instead of taking
## a place in the formation.
@export var mounted: bool = false
## Where on the hull this part sits, from the hull's centre.
@export var mount_offset: Vector2 = Vector2.ZERO
