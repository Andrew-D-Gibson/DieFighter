extends Node

var game_save: GameSaveResource = preload(
	"res://Source/Systems/SaveResources/game_start.tres"
)

# Singletons
var player: Player
var enemy_manager: EnemyManager
var state_manager: GameStateManager

# Colors
var red: Color = Color.html('#d03656')
var blue: Color = Color.html('#43a6fc')
var green: Color = Color.html('#7abd33')
var yellow: Color = Color.html('#eed35d')
var purple: Color = Color.html('#c552f1')
var orange: Color = Color.html('#f29c5d')
