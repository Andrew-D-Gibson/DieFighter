class_name ScenarioResource
extends Resource

@export var map_icon: Texture2D
@export var background_resource: RandomBackgroundResource
## Pins the planets and stars this scenario shows, in place of the layouts its
## background picks from (see SetPieceComposition). For a scripted fight whose
## sky has to keep clear of particular ships' health bars, such as the
## tutorial's two-ship fight. Leave it unmirrorable with no jitter to pin it
## exactly. Null for the background's own layouts.
@export var set_piece_layout: SetPieceComposition
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

## What the fight's last ship says as it dies, in a story box (LastWords),
## for a boss with something to tell. Null for a fight that ends without a
## word. The run's last gate ignores it: the Bastion's confession plays there
## (FateRevelation).
@export var last_words: StoryBeatResource

## A hull the scenario's mounted ships are parts of. Null for an ordinary
## encounter. See ShipHullResource.
@export var hull: ShipHullResource

## Whether arriving here plays the region's rule card (RegionAlert). Off for
## stops whose own panel opens at once (the shop, the repair station): that
## panel is what the player came for, and a card over it only gets in the way.
## The environment monitor still comes up, its lamp blinking unread.
@export var announce_region: bool = true

## The layers of the fleet this encounter belongs to (LORE.md §3): the Tail is
## sector 1, the Belly sector 2, the Spine sector 3. Each sector is dealt only
## its own layer's encounters, so the Rearguard's checkpoints stay in the Spine
## and the Undertow's scavengers in the Tail. None ticked fits every sector.
## A sector past the last layer is dealt the last layer's encounters.
@export_flags("Tail", "Belly", "Spine") var sectors: int = 0

## How many layers `sectors` names.
const LAYER_COUNT: int = 3

## Dealt only while every one of these holds of the run's standing
## (FactionLedger), checked as each sector is generated: an encounter that
## exists because of what the player did, like the Compact sending someone to
## collect for a shop they robbed. Ask about a named faction: an encounter has
## no ship of its own for an unset one to mean. None: dealt whatever the
## fleet thinks. See also GameStateManager.consequence_scenarios, for one that
## must be met rather than may be.
@export var standing_requirements: Array[FactionCondition] = []

@export_category('Difficulty')
## Multiplies the hull and shields of every ship this encounter spawns, on top
## of the sector's scaling. Lets an elite field the same ships as an ordinary
## fight and still hit harder, without a second copy of each EnemyResource.
@export_range(0.25, 4.0, 0.05) var enemy_hull_multiplier: float = 1.0
## Multiplies every rolled intent amount (damage, shields, repairs) of the
## ships this encounter spawns, on top of the sector's scaling.
@export_range(0.25, 4.0, 0.05) var enemy_damage_multiplier: float = 1.0

@export_category('Boss')
## The name stamped across the boss intro card when this fight starts. Leave
## empty for an encounter that isn't a boss fight: no card plays.
@export var boss_title: String
## A short line under the name: what the boss is, or what it guards.
@export var boss_subtitle: String

var scenario_seed: int = 0


## The earliest sector (0 is the first) this encounter may be dealt into: the
## latest any of its starting ships allows (EnemyResource.earliest_sector).
func earliest_sector() -> int:
	var earliest: int = 0
	for ship: EnemyStateRewardResource in starting_enemies:
		if ship and ship.enemy_resource:
			earliest = maxi(earliest, ship.enemy_resource.earliest_sector())
	return earliest


## Whether this encounter belongs to sector [param sector_index]'s layer of the
## fleet. See `sectors`.
func deals_into(sector_index: int) -> bool:
	if sectors == 0:
		return true
	var layer: int = clampi(sector_index, 0, LAYER_COUNT - 1)
	return sectors & (1 << layer) != 0


## Whether [param ledger] meets this encounter's standing_requirements.
func standing_allows(ledger: FactionLedger) -> bool:
	return FactionCondition.all_hold(standing_requirements, ledger)


## Only the encounters in [param scenarios] that may be dealt into sector
## [param sector_index]: those of its layer (deals_into()) whose ships it is
## ready for (earliest_sector()), and whose standing requirements the run
## meets ([param ledger], the live run's when null).
static func allowed_in_sector(scenarios: Array[ScenarioResource], sector_index: int, ledger: FactionLedger = null) -> Array[ScenarioResource]:
	if ledger == null:
		ledger = FactionStanding.ledger_now()
	var allowed: Array[ScenarioResource] = []
	for scenario: ScenarioResource in scenarios:
		if scenario and scenario.earliest_sector() <= sector_index and scenario.deals_into(sector_index) \
		and scenario.standing_allows(ledger):
			allowed.append(scenario)
	return allowed


## The boss card's title, in the current language. Empty for no boss card.
func display_boss_title() -> String:
	return ContentText.text(self, &"boss_title")


## The line under the boss card's title, in the current language.
func display_boss_subtitle() -> String:
	return ContentText.text(self, &"boss_subtitle")


func _content_text_prefix() -> String:
	return "SCENARIO"


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"boss_title", "BOSS_TITLE",
			"A boss's name, stamped in large capitals across the intro card when its fight starts."),
		ContentText.Field.new(&"boss_subtitle", "BOSS_SUBTITLE",
			"One line under a boss's name on its intro card: what the boss is or what it guards."),
	]
