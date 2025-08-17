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
	
	var dir_location := "res://Source/Content/Tiles/TileResources/"
	var dir := DirAccess.open(dir_location)
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				var res = ResourceLoader.load(dir_location + file_name)
				if res is TileResource:
					_all_tile_resources.append(res)
	
	
func get_possible_tile_rewards() -> Array[TileResource]:
	var player_tiles = Globals.deck_manager.deck_at_start_of_scenario
	return Utils.array_while_excluding(_all_tile_resources, player_tiles)
		

func _spawn_reward(pos: Vector2, money: int, num_of_rewards: int, dice_probability: float) -> void:
	var reward := reward_scene.instantiate()
	add_child(reward)
	reward.global_position = pos
	reward.give_reward(money, num_of_rewards, dice_probability)
