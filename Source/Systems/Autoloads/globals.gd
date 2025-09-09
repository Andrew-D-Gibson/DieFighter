extends Node

# Game System Singletons
var player: Player
var tile_grid: TileGrid
var activation_queue_manager: ActivationQueueManager
var map: Map
var targeting_computer: TargetingComputer
var reward_manager: RewardManager
var money_indicator: MoneyIndicator

var enemy_manager: EnemyManager
var scenario_manager: ScenarioManager
var state_manager: GameStateManager
var background_manager: BackgroundManager
var tutorial_manager: TutorialManager

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
