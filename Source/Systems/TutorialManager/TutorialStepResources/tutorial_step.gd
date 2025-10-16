class_name TutorialStep
extends Resource

@export_multiline var tutorial_text: String
@export var text_position: Vector2 = Vector2(160, 40)
@export var forced_dice: Array[int]
@export var forced_enemy_actions: Array[EnemyActionResource]
@export var forced_rewards: Array[TileResource]

# Trigger signal - what event should finish this step
enum TutorialSignals {
	NONE,
	CLOSED_MANUALLY,
	CLOSED_AFTER_TIME,
	TILE_CLICKED_FOR_INFO,
	CLICKED_OUT_OF_INFO,
	TILE_ACTIVATED,
	PLAYER_TURN_OVER,
	ENEMY_DEFEATED,
	REWARD_SPAWNED,
	REWARD_CLAIMED,
	MAP_OPENED,
	ON_JUMP,
}
@export var open_on_signal: TutorialSignals
@export var close_on_signal: TutorialSignals 


# Tutorial functions - what function in the TutorialManager should this step call
enum TutorialFunctions {
	NONE,
	REVEAL_HEALTH_BAR,
	REVEAL_SYSTEMS,
	REVEAL_TARGETING_COMPUTER,
	TRIGGER_ENEMY_SPAWN,
	SPAWN_DICE,
	ALLOW_DICE_DRAGGING,
	RUN_ENEMY_TURN,
	ALLOW_NORMAL_COMBAT,
	REVEAL_MAP,
}
@export var tutorial_function: TutorialFunctions 

@export var time_to_auto_close: float = 0

# Optional: Highlight specific UI elements
@export var highlight_texture: Texture2D
