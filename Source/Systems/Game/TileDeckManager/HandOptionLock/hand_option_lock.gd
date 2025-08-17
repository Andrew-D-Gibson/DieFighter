class_name HandOptionLock
extends Node2D

@export var hand_option_lock_tile_resources: Array[TileResource]

func set_unlock_die_value(die_value: int) -> void:
	$Tile.tile_resource = hand_option_lock_tile_resources[die_value - 1]
