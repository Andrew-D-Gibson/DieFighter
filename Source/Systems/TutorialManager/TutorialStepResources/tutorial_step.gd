class_name TutorialStep
extends Resource

@export_multiline var tutorial_text: String
@export var text_position: Vector2 = Vector2(160, 40)
@export var time_delay: float = 0
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
	ON_ENEMY_FLY_IN,
	## The player has picked a different ship than the one targeted when the
	## step opened. With no second ship to pick, the card gets a Close button
	## instead, rather than asking for something that can't be done.
	ON_TARGET_SWITCH,
	## A ship was handed a die. Unlike TILE_ACTIVATED, a Bump (which hands its
	## die back) doesn't count, so a step that explains the hand-off can't
	## open over a tile that didn't make one.
	ENEMY_RECEIVED_DIE,
	## The player's next turn has begun: the enemy turn is over and the new
	## hand is dealt. Lets a step stay up for a whole enemy turn, however long.
	PLAYER_TURN_STARTED,
	## Every ship in a fight's fly-in has landed. Unlike ON_ENEMY_FLY_IN (the
	## first ship), the whole roster is on screen.
	ENEMIES_ARRIVED,
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
	ENABLE_RIGHT_CONTROL,
	ENABLE_ALL_CONTROLS,
	LOCK_DICE,
	UNLOCK_DICE,
	## Hands the run back to the player: unlocks everything the tutorial held
	## and leaves them mid-run rather than returning to a menu.
	FINISH_TUTORIAL,
	## Re-rolls live enemies' intent tables so this step's forced_enemy_actions
	## apply to the turn already telegraphed, not the one after.
	REROLL_ENEMY_INTENTS,
	## Lights the Map tab in the tutorial's purple and sets it bobbing until
	## the map is opened, whatever the mouse did to it before.
	CALL_OUT_MAP_TAB,
}
## Runs once the card's text has all come in.
@export var tutorial_function: TutorialFunctions 

## Runs as the step opens, before its card appears: for what the card's first
## words count on, like the tab it names already lit, or the hand held still
## while it asks for something else.
@export var opening_function: TutorialFunctions

@export var time_to_auto_close: float = 0

## Seconds to wait for close_on_signal before the tutorial gives up on this step
## and advances anyway, so a missed gameplay event can't soft-lock the game.
## 0 falls back to TutorialManager.default_step_timeout, or to no deadline for a
## step waiting on the player (see TutorialManager._PLAYER_DRIVEN).
@export var max_wait_time: float = 0

# Optional: Highlight specific UI elements
@export var highlight_texture: Texture2D

## For the step that introduces switching targets. The tutorial holds the
## targeting computer's target arrows back until this step: it puts up the
## highlight on its own, lets the arrows swing out under it, and only then
## shows the card, so the card explains something the player just watched.
@export var reveal_target_arrows: bool = false

## With reveal_target_arrows: once the arrows are out, the highlight opens up
## around every ship in the fight as well, so the card can talk about them.
## The ships move between fights, so these cutouts are made on the spot.
@export var cut_out_targets: bool = false

## The tutorial holds the ambusher's opening shot (OpeningStrike) until this
## step's text has all come in, so the player reads who's attacking before
## the shot lands.
@export var releases_opening_strike: bool = false
