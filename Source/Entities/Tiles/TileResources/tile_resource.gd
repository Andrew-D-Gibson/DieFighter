class_name TileResource
extends Resource

@export_category('Info')
@export var tile_name: String
@export_multiline var description: String

@export_category('Graphics')
@export var base_texture: Texture2D

@export_category('Behavior')
@export var activation: ActivationResource
@export var effect_chain: Dictionary[PackedScene, int]
