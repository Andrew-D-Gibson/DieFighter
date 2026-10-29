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
		for path: String in Utils.list_resource_paths(dir_location):
			var res: Resource = ResourceLoader.load(path)
			if res is TileResource and res.offered_as_reward:
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


## The tiles in [param pool] at or above [param minimum_rarity]. Falls back to
## the whole pool when none qualify, so a raised floor narrows an offer but
## never empties it.
static func filter_by_minimum_rarity(
	pool: Array[TileResource],
	minimum_rarity: TileResource.Rarity
) -> Array[TileResource]:
	var filtered: Array[TileResource] = []
	for tile_resource: TileResource in pool:
		if tile_resource.rarity >= minimum_rarity:
			filtered.append(tile_resource)
	return filtered if not filtered.is_empty() else pool


## Every tile an offer can hold. Tiles the player already has are in it: a
## copy dropped on its twin upgrades it (Tile.upgrade()).
func get_possible_tile_rewards() -> Array[TileResource]:
	return _all_tile_resources.duplicate()
		

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
