class_name RewardManager
extends Node2D

@export var reward_scene: PackedScene
var _all_tile_resources: Array[TileResource]


func _ready() -> void:
	Globals.reward_manager = self
	_load_tile_resources()
	
	Events.spawn_reward.connect(_spawn_reward)
	Events.start_scenario.connect(_restore_offers)

	
func _load_tile_resources() -> void:
	_all_tile_resources = []

	var dir_locations: Array[String] = [
		"res://Source/Content/Tiles/TileResources/",
	]

	for dir_location: String in dir_locations:
		var dir := DirAccess.open(dir_location)
		if dir:
			for file_name: String in dir.get_files():
				if file_name.ends_with(".tres"):
					var res = ResourceLoader.load(dir_location + file_name)
					if res is TileResource:
						_all_tile_resources.append(res)
	
	
## Relative likelihood a tile of each rarity is offered. Rarity previously only
## affected shop *pricing*, so a Grudge Cannon dropped exactly as often as a
## plain Shield — which flattens the whole rarity axis and makes finding a
## strong tile feel like nothing.
const _RARITY_WEIGHTS: Dictionary[TileResource.Rarity, float] = {
	TileResource.Rarity.COMMON: 1.0,
	TileResource.Rarity.UNCOMMON: 0.45,
	TileResource.Rarity.RARE: 0.18,
}


## Picks one tile out of a pool, biased by rarity. Returns null for an empty
## pool so callers can fall back to a dice reward.
func pick_weighted_tile_reward(pool: Array[TileResource]) -> TileResource:
	if pool.is_empty():
		return null

	var total_weight: float = 0.0
	for tile_resource: TileResource in pool:
		total_weight += _RARITY_WEIGHTS.get(tile_resource.rarity, 1.0)

	var roll: float = RNGManager.randf_range(RNGManager.Bucket.REWARDS, 0.0, total_weight)
	for tile_resource: TileResource in pool:
		var weight: float = _RARITY_WEIGHTS.get(tile_resource.rarity, 1.0)
		if roll <= weight:
			return tile_resource
		roll -= weight

	# Float drift only; the loop above almost always returns.
	return pool[-1]


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


## Offers still waiting to be picked from, for the save.
func capture_offers() -> Array:
	var offers: Array = []
	for child: Node in get_children():
		if child is Reward and not child.is_queued_for_deletion() and not child.items.is_empty():
			offers.append({
				"x": child.global_position.x,
				"y": child.global_position.y,
				"items": child.items,
			})
	return offers


## Continuing a save taken partway through a scenario puts its untaken offers
## back where they were. Done on start_scenario, alongside the ships arriving.
func _restore_offers() -> void:
	if not Globals.state_manager:
		return
	for offer: Variant in Globals.state_manager.get_restore().get("offers", []):
		var reward: Reward = reward_scene.instantiate()
		add_child(reward)
		reward.global_position = Vector2(float(offer["x"]), float(offer["y"]))
		reward.restore_offer(offer["items"])
