class_name TileUnlocks
extends RefCounted
## Which tiles the player's runs can offer. A new player starts on the Basic
## tiles, every offered tile in no TileFamilyResource. Each jump into a new
## sector, in any run, unlocks the next family in tile_unlock_order.tres for
## good (kept by CollectionManager), and its tiles join the pool at once, so
## the sector the player just reached can already offer them.
##
## Only the player's own runs are held back (CollectionManager.is_recording()).
## The Scenario Lab and the AutoPilot see every tile, so a balance batch comes
## out the same whatever the machine's player has unlocked.

const ORDER_PATH: String = "res://Source/Content/Tiles/TileFamilies/tile_unlock_order.tres"

static var _order: TileUnlockOrderResource
## Tile resource_path -> every family in the order that lists it.
static var _families_by_tile: Dictionary[String, Array] = {}


## The order families unlock in, loaded on first use: loading it pulls in
## every tile it lists, which nothing early in the boot should pay for.
static func order() -> TileUnlockOrderResource:
	if _order == null:
		_order = load(ORDER_PATH)
		_index_families()
	return _order


static func families() -> Array[TileFamilyResource]:
	return order().families


static func family_by_id(id: String) -> TileFamilyResource:
	for family: TileFamilyResource in families():
		if family.id() == id:
			return family
	return null


static func is_gated() -> bool:
	return CollectionManager.is_recording()


static func is_unlocked(family: TileFamilyResource) -> bool:
	return CollectionManager.has_family(family.id())


static func unlocked_count() -> int:
	var count: int = 0
	for family: TileFamilyResource in families():
		if is_unlocked(family):
			count += 1
	return count


## The first family in the order the player doesn't have, or null once they
## have them all.
static func next_locked_family() -> TileFamilyResource:
	for family: TileFamilyResource in families():
		if not is_unlocked(family):
			return family
	return null


## Whether an offer may hold [param tile] right now.
static func is_tile_available(tile: TileResource) -> bool:
	return not is_gated() or _families_unlocked(tile)


## [param pool] without the tiles still locked away.
static func filter_pool(pool: Array[TileResource]) -> Array[TileResource]:
	if not is_gated():
		return pool
	var available: Array[TileResource] = []
	for tile: TileResource in pool:
		if _families_unlocked(tile):
			available.append(tile)
	return available


## What a sector's unlock is filed under, so it's only ever earned once: a
## Continue that replays the jump finds the family it already unlocked. Empty
## (always a fresh unlock) for a run whose seed isn't known, a save from
## before the seed was saved.
static func claim_for(run_seed: int, sector_index: int) -> String:
	if run_seed < 0:
		return ""
	return "%d:%d" % [run_seed, sector_index]


## The family [param claim] unlocks: the next locked one, or the one it
## already unlocked if this jump is being replayed. Null outside the player's
## own runs and once every family is unlocked.
static func unlock_for(claim: String) -> TileFamilyResource:
	if not is_gated():
		return null
	var claimed: String = CollectionManager.family_for_claim(claim)
	if not claimed.is_empty():
		return family_by_id(claimed)
	var family: TileFamilyResource = next_locked_family()
	if family:
		CollectionManager.record_family(family.id(), claim)
	return family


## The tiles [param family] adds to offers: those it lists that are offered
## at all. (A tile listed in two families by mistake would wait for both;
## test_tile_families.gd stops that happening.)
static func tiles_opened_by(family: TileFamilyResource) -> Array[TileResource]:
	var opened: Array[TileResource] = []
	for tile: TileResource in family.tiles:
		if tile and tile.offered_as_reward and _families_unlocked(tile):
			opened.append(tile)
	return opened


## Every family [param tile] is in, in unlock order. Empty for a Basic tile.
static func families_of(tile: TileResource) -> Array[TileFamilyResource]:
	order()
	var found: Array[TileFamilyResource] = []
	found.assign(_families_by_tile.get(tile.resource_path, []))
	return found


static func _families_unlocked(tile: TileResource) -> bool:
	for family: TileFamilyResource in families_of(tile):
		if not is_unlocked(family):
			return false
	return true


static func _index_families() -> void:
	_families_by_tile.clear()
	for family: TileFamilyResource in _order.families:
		for tile: TileResource in family.tiles:
			if tile == null:
				continue
			if not _families_by_tile.has(tile.resource_path):
				_families_by_tile[tile.resource_path] = []
			_families_by_tile[tile.resource_path].append(family)
