class_name RewardManager
extends Node2D

@export var reward_scene: PackedScene
var possible_tile_rewards: Array[TileResource]


func _ready() -> void:
	Globals.reward_manager = self
	_load_tile_resources()
	
	Events.spawn_reward.connect(_spawn_reward)

	
func _load_tile_resources() -> void:
	possible_tile_rewards = []
	
	var dir_location := "res://Source/Content/Tiles/TileResources/"
	var dir := DirAccess.open(dir_location)
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				var res = ResourceLoader.load(dir_location + file_name)
				if res is TileResource:
					possible_tile_rewards.append(res)
	

func _spawn_reward(pos: Vector2, money: int, dice_probability: float) -> void:
	var reward := reward_scene.instantiate()
	add_child(reward)
	reward.global_position = pos
	reward.give_reward(money, dice_probability)
