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

## Which die faces this enemy's stronger actions tend to land on. Positive puts
## them on high faces, so a 6 is the die the player least wants to hand over;
## negative puts them on low faces instead. 0 places actions with no regard to
## strength. Around ±0.5 is a gentle lean, ±1 a clear one, and ±3 nearly a
## strict sort. A pool can override it (EnemyTurnActionList.override_face_bias).
## The default is the house rule: a gentle lean toward high faces, so a higher
## die is always a bit more to hand over. Set an enemy's own value only to
## depart from it.
@export_range(-3.0, 3.0, 0.25, "or_greater", "or_less") var face_bias: float = 0.5


@export_category('Overload')
## When the dice this ship holds at the start of its turn add up to this much,
## it overloads instead of acting: it skips the turn, vents every die it holds
## back to the player and plays overload_chain. 0 means it never overloads.
##
## It turns the gift into a weapon: the player can stuff a ship like this with
## big dice on purpose to trip its breaker, at the risk of falling short and
## eating whatever those big faces do.
@export var overload_threshold: int = 0
## Added to the threshold each time the ship overloads, so stuffing it gets
## harder every time it works.
@export var overload_threshold_growth: int = 0
## What overloading does to the ship, usually a jolt of damage to itself.
@export var overload_chain: EffectChain
## Where the heat gauge sits, relative to the ship.
@export var overload_gauge_position: Vector2 = Vector2(0, 28)

@export_category('Graphics')
@export var ship_graphics_scene: PackedScene
@export var graphics_scene_offset: Vector2 = Vector2(0,0)
@export var dialogue_offset: Vector2 = Vector2(0,0)
@export var targeting_computer_image: Texture2D
@export var health_bar_position: Vector2
## Where the health bar moves when the formation is too crowded for it to hang
## off the ship's side: tucked above the hull, inside the ship's own width.
@export var compact_health_bar_position: Vector2 = Vector2(0, -27)
@export var dice_queue_position: Vector2
## How much of the formation's width the hull takes up. Ordinary ships are
## 32px across; a capital ship needs its real width here, or the formation
## parks its escorts underneath it.
@export var formation_width: float = 32.0
