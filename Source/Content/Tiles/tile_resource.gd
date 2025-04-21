class_name TileResource
extends Resource

@export_category('Info')
@export var tile_name: String
@export_multiline var activation_description: String
@export_multiline var description: String

@export_category('Graphics')
@export var textures: SpriteFrames

@export_category('Behavior')
## Set to -1 for infinite uses per turn
@export var uses_per_turn: int
@export var activation_checks: Array[ActivationResource]
@export var effect_chain: Array[Effect]
