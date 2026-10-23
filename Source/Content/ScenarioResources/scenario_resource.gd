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
## of the cockpit panel (whose tabs start around y=76) — anything lower draws
## over the player's own systems panel and reads as already-installed. The
## offer reserves its stretch of the formation, so a lone ship beside a centred
## offer is squeezed toward the screen edge, with no room left for its speech;
## move the offer aside for those.
@export var starting_reward_position: Vector2 = Vector2(160, 60)

## A hull the scenario's mounted ships are parts of. Null for an ordinary
## encounter. See ShipHullResource.
@export var hull: ShipHullResource

@export_category('Boss')
## The name stamped across the boss intro card when this fight starts. Leave
## empty for an encounter that isn't a boss fight: no card plays.
@export var boss_title: String
## A short line under the name: what the boss is, or what it guards.
@export var boss_subtitle: String

var scenario_seed: int = 0
