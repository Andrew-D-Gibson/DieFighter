extends Node

# Game System Singletons
var player: Player
var tile_grid: TileGrid
var map: Map
var targeting_computer: TargetingComputer
var reward_manager: RewardManager
var money_indicator: MoneyIndicator

var enemy_manager: EnemyManager
var scenario_manager: ScenarioManager
var state_manager: GameStateManager
var background_manager: BackgroundManager
var jump_manager: JumpManager
var jump_gate: JumpGate
var background_modifier_manager: BackgroundModifierManager
var run_stats: RunStats
var shop: Shop
var repair_station: RepairStation

## While true, the tutorial decides when enemy turns run, so EnemyManager should
## not fire one off the back of player_turn_over.
var tutorial_controls_enemy_turns: bool = false

# Set by MainMenu's Continue button before switching to the main game scene,
# and consumed by GameStateManager._ready() in place of its scene-baked default.
var pending_load_save: GameSaveResource = null

## The ship this run flies. Set by the main menu (picked for a new game, read
## from the save on Continue) before the game scene loads, since the TileGrid
## shapes itself from it in _ready. Read it through current_ship().
var selected_ship: ShipResource = null


## The ship this run flies, falling back to the default when nothing picked
## one (a direct boot of the game scene, a test).
func current_ship() -> ShipResource:
	if not selected_ship:
		selected_ship = ShipCatalog.find(ShipCatalog.DEFAULT_ID)
	return selected_ship

## The game's screen in world pixels: the 1920x1080 window through a 6x camera.
const SCREEN_SIZE: Vector2 = Vector2(320, 180)

# Colors
var red: Color = Color.html('#d03656')
var blue: Color = Color.html('#43a6fc')
var green: Color = Color.html('#7abd33')
var yellow: Color = Color.html('#eed35d')
var purple: Color = Color.html('#c552f1')
var orange: Color = Color.html('#f29c5d')
var dark_gray: Color = Color.html('#343330')
var white: Color = Color.html('#cef0f1')

var medium_purple: Color = Color.html('#a846ce')



# Game Settings
## How hard camera motion plays (shakes, zoom punches, the kill cam, screen
## ripples), 0 to 1. Zero turns it off.
var screenshake_intensity: float = 1.0
## Whether there's any camera motion at all. Kept for code that only needs
## on or off; set screenshake_intensity instead.
var screenshake_enabled: bool:
	get:
		return screenshake_intensity > 0.0
## Accessibility: full-screen flashes drop to a faint tint, rapid flicker
## stops, and sprite flashes are toned down (see Juice.soften_flash()).
var reduce_flashing: bool = false
var animation_speed: float = 4
var times_run: int = 0
## Whether the player has played the tutorial through once. Until they have,
## Play on the main menu starts the tutorial run instead of opening ship
## select. Player progress, not an option: saved by OptionsSettings beside
## the launch counter, and never reset by Defaults.
var tutorial_completed: bool = false
## Set by the main menu for one new game: the run about to start is the
## tutorial's. TutorialManager clears it as it starts, so only a run launched
## as the tutorial (never a Continue, a lab run or a direct boot of the game
## scene) is narrated.
var tutorial_requested: bool = false
## Whether arriving somewhere with a background rule or hazard pops up a card
## spelling it out (RegionAlert). Players who know the backgrounds can turn it
## off in the Options menu.
var show_region_alerts: bool = true
