class_name TileResource
extends Resource

@export_category('Info')
@export var tile_name: String
@export_multiline var activation_description: String
@export_multiline var description: String

enum Rarity {COMMON, UNCOMMON, RARE}
@export var rarity: Rarity = Rarity.COMMON
## Untick to hold a tile out of reward and shop offers while it's being
## reworked. It still loads everywhere else (dev console, saves), so it can be
## tested and a run that already owns it keeps working.
@export var offered_as_reward: bool = true

@export_category('Upgrade')
## The better version of this tile: its own TileResource beside this one, with
## is_upgrade ticked and offered_as_reward unticked. A copy of this tile
## dropped on one already on the grid merges into this. Null for a tile that
## can't be upgraded.
@export var upgraded_version: TileResource
## Ticked on an upgraded version: drawn with the upgrade shimmer and sparks.
@export var is_upgrade: bool = false

@export_category('Graphics')
@export var textures: SpriteFrames

@export_category('Behavior')
## Refilled at the start of every player turn. Set to -1 for infinite uses
@export var uses_per_turn: int
@export var activation_checks: Array[ActivationResource]

@export var effect_chain: EffectChain
@export var event_responses: Dictionary[TileEvent, EffectChain]

## A countdown tile counts down from this (dice on it, COUNT_DOWN, take
## their value off) and fires its ON_COUNTDOWN_ZERO response each time it
## runs out. 0 for a tile that doesn't count down. See TileCountdown.
@export_range(0, 99) var countdown: int = 0

@export var dragging_allowed: bool = true

## Untick for a tile that must never be locked out. The Engine Charger is the
## one: it is the only way to charge the jump drive, so locking it could leave
## the player unable to ever leave. Lockouts refuse such a tile (see
## AddLockoutModifierEvent). Random lockouts already draw only from the grid,
## which the Engine Charger is never on; a grid tile with this unticked would
## need a lockable-only random pick, or a random lockout would fizzle on it.
@export var can_be_locked_out: bool = true

## Whether an echo (EchoModifier) may repeat this tile. Off for a tile whose
## effect compounds on itself (Fortress Protocol doubling shields), where a
## second pass multiplies rather than adds. An echo skips such a tile and
## waits for the next one.
@export var can_be_echoed: bool = true

## This limit is ignored when the max dice allowed in queue is -1
@export var max_dice_in_queue: int = -1
