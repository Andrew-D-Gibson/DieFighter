class_name ScenarioResource
extends Resource

@export var map_icon: Texture2D
@export var background_resource: RandomBackgroundResource
@export var sector_gate_scenario: bool = false
@export var starting_enemies: Array[EnemyStateRewardResource]

@export var rewards: Dictionary[ScenarioManager.Faction, RewardResource]

## A reward already floating in space when the player arrives, offered before
## a shot is fired rather than paid out for winning. Null for encounters that
## have nothing lying around.
##
## What makes this interesting is that the ships present can *watch* the
## player take it — see Events.reward_tile_taken and the PLAYER_TOOK_* events.
@export var starting_reward: RewardResource
## Where that reward floats, in global screen space. Defaults to the band of
## open space between the enemy formation (which sits around y=43) and the top
## of the cockpit panel (whose tile grid starts around y=90) — anything lower
## draws over the player's own systems panel and reads as already-installed.
@export var starting_reward_position: Vector2 = Vector2(160, 72)

## Optional recurring environmental event for this encounter (solar flare, ion
## storm, ...). Null means a plain, quiet fight.
@export var hazard: ScenarioHazardResource

var scenario_seed: int = 0
