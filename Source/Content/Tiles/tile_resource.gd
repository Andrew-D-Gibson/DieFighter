class_name TileResource
extends Resource

@export_category('Info')
@export var tile_name: String
@export_multiline var activation_description: String
@export_multiline var description: String

enum Rarity {COMMON, UNCOMMON, RARE}
@export var rarity: Rarity = Rarity.COMMON

@export_category('Graphics')
@export var textures: SpriteFrames

@export_category('Behavior')
## Set to -1 for infinite uses per turn
@export var uses_per_turn: int
@export var activation_checks: Array[ActivationResource]
@export var effect_chain: EffectChain

@export var event_responses: Dictionary[TileEvent, EffectChain]

@export var dragging_allowed: bool = true
