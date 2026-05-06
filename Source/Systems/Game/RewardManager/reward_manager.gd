class_name RewardManager
extends Node2D

@export var reward_scene: PackedScene
var _all_tile_resources: Array[TileResource]


func _ready() -> void:
	Globals.reward_manager = self
	_load_tile_resources()
	
	Events.spawn_reward.connect(_spawn_reward)

	
func _load_tile_resources() -> void:
	_all_tile_resources = []

	var dir_locations: Array[String] = [
		"res://Source/Content/Tiles/TileResources/",
		"res://Source/Content/Tiles/ComplicatedTileResources/",
	]

	for dir_location: String in dir_locations:
		var dir := DirAccess.open(dir_location)
		if dir:
			for file_name: String in dir.get_files():
				if file_name.ends_with(".tres"):
					var res = ResourceLoader.load(dir_location + file_name)
					if res is TileResource:
						_all_tile_resources.append(res)
	
	
func get_possible_tile_rewards() -> Array[TileResource]:
	var player_tiles = Globals.tile_grid.tile_locations.values()
	
	var player_tile_resources: Array[TileResource] = []
	for tile in player_tiles:
		player_tile_resources.append(tile.tile_resource)
		
	return Utils.array_while_excluding(_all_tile_resources, player_tile_resources)
		

func _spawn_reward(pos: Vector2, reward_resource: RewardResource) -> void:
	var reward := reward_scene.instantiate()
	add_child(reward)
	reward.global_position = pos
	reward.give_reward(reward_resource)
