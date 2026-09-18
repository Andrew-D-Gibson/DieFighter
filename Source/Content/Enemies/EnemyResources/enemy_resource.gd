class_name EnemyResource
extends Resource

@export_category('Info')
@export var enemy_name: String
@export_multiline var description: String

## How this enemy decides which action pool to draw its six turn slots from
## when it has more than one.
enum PoolSelection {
	## One pool per turn, cycling. Good for rhythms — charge, then fire.
	TURN_CYCLE,
	## By how hurt it is: the first pool at full health, the last near death.
	## Makes a long fight escalate visibly instead of staying flat.
	HEALTH_THRESHOLD,
	## By how many of its own faction have died in this fight: the first pool
	## while the squad is intact, the last once it's alone. Turns a group fight
	## into something that reacts to the order you kill things in.
	SQUAD_LOSSES,
	## By how many combat rounds have elapsed, whether or not this ship got to
	## act. The only mode that can express a real timer — TURN_CYCLE advances
	## on turns the ship was *fed*, so an ignored ship never moves off pool 0.
	COMBAT_ROUNDS,
}

@export_category('Behavior')
@export var max_health: int
@export var starting_shields: int
@export var action_options: Array[EnemyTurnActionList]
@export var pool_selection: PoolSelection = PoolSelection.TURN_CYCLE


@export_category('Graphics')
@export var ship_graphics_scene: PackedScene
@export var graphics_scene_offset: Vector2 = Vector2(0,0)
@export var dialogue_offset: Vector2 = Vector2(0,0)
@export var targeting_computer_image: Texture2D
@export var health_bar_position: Vector2
@export var dice_queue_position: Vector2
