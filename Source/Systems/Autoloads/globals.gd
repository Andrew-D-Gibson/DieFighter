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
var hazard_manager: HazardManager
var background_modifier_manager: BackgroundModifierManager
var run_stats: RunStats
var shop: Shop
var tutorial_manager: TutorialManager

## True while the onboarding tutorial is narrating the run. Gameplay systems ask
## this rather than reaching into TutorialManager's own fields.
var tutorial_active: bool = false

## While true, the tutorial decides when enemy turns run, so EnemyManager should
## not fire one off the back of player_turn_over.
var tutorial_controls_enemy_turns: bool = false

# Set by MainMenu's Continue button before switching to the main game scene,
# and consumed by GameStateManager._ready() in place of its scene-baked default.
var pending_load_save: GameSaveResource = null

# Audio Singletons
var sfx_player: SFXPlayer

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
var dark_purple: Color = Color.html('#80359d')

var mouse_is_dragging_something: bool = false


# Game Settings
var screenshake_enabled: bool = true
var animation_speed: float = 4
var times_run: int = 0 
