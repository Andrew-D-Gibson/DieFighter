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

@export_category('Graphics')
@export var textures: SpriteFrames

@export_category('Behavior')
## Refilled at the start of every player turn. Set to -1 for infinite uses
@export var uses_per_turn: int
@export var activation_checks: Array[ActivationResource]

@export var effect_chain: EffectChain
@export var event_responses: Dictionary[TileEvent, EffectChain]

@export var dragging_allowed: bool = true

## This limit is ignored when the max dice allowed in queue is -1
@export var max_dice_in_queue: int = -1
