# Plan: Tile-to-Grid Handoff Cleanup

## Context

Three places add tiles to the player's TileGrid — the save-load path, the reward pickup, and the shop purchase. The save-load path is clean (`TileGrid._setup_tiles()`), but the reward and shop paths are not:

- Both call `Globals.tile_grid._drop_tile_on_grid_pos(...)` — a private method — from external files.
- Both duplicate the same 3-4 line reparenting/connection pattern.
- Both export `tile_scene: PackedScene`, meaning tile instantiation is scattered rather than owned by TileGrid.
- `RewardManager.get_possible_tile_rewards()` uses an untyped array.
- `RewardManager._load_tile_resources()` only scans `TileResources/`, so `ComplicatedTileResources/` tiles can never appear as rewards.

## Files to Change

| File | Change |
|---|---|
| `Systems/Game/TileGrid/tile_grid.gd` | Add `create_tile()` + `receive_tile()` public methods |
| `Systems/Game/RewardManager/reward.gd` | Remove `tile_scene` export, use new methods |
| `Systems/Game/Shop/shop.gd` | Remove `tile_scene` export, use new methods, type one array |
| `Systems/Game/RewardManager/reward_manager.gd` | Type one array, scan both tile resource folders |
| `Systems/Game/RewardManager/reward.tscn` | Remove orphaned `tile_scene` property |
| `Systems/Game/Shop/shop.tscn` | Remove orphaned `tile_scene` property |

---

## Step 1 — Add two public methods to `tile_grid.gd`

Insert after `_setup_tiles()` (after line 75), before `_assign_tile_to_grid_pos()`:

```gdscript
func create_tile(tile_resource: TileResource) -> Tile:
	var tile: Tile = tile_scene.instantiate()
	tile.tile_resource = tile_resource
	return tile


func receive_tile(tile: Tile, drop_position: Vector2) -> void:
	tile.draggable.floating_enabled = false
	tile.draggable.drag_ended.connect(_drop_tile_on_grid_pos)
	tile.reparent(self, true)
	_drop_tile_on_grid_pos(tile.draggable, drop_position)
```

`create_tile()` is a pure factory — it does not `add_child` or assign a grid position. Callers (reward/shop) add it to their own scene tree temporarily, then hand it off.

`receive_tile()` is the public handoff API. It absorbs the 3-4 line pattern duplicated in reward.gd and shop.gd. Calling `_drop_tile_on_grid_pos` here is valid — it's internal to the same class.

`_setup_tiles()` and `_drop_tile_on_grid_pos()` are **not changed**.

---

## Step 2 — Update `reward.gd`

**Remove** line 5:
```gdscript
@export var tile_scene: PackedScene
```

**Replace** tile instantiation block in `give_reward()` (lines 65-72):
```gdscript
# Before
reward = tile_scene.instantiate()
if len(forced_rewards) > 0:
    reward.tile_resource = forced_rewards.pop_front()
else:
    reward.tile_resource = possible_tile_rewards.pick_random()
possible_tile_rewards.erase(reward.tile_resource)

# After
var chosen_resource: TileResource
if len(forced_rewards) > 0:
    chosen_resource = forced_rewards.pop_front()
else:
    chosen_resource = possible_tile_rewards.pick_random()
possible_tile_rewards.erase(chosen_resource)
reward = Globals.tile_grid.create_tile(chosen_resource)
```

**Replace** tile handoff block in `_end_reward()` (lines 98-103):
```gdscript
# Before
if chosen_reward is Tile:
    chosen_reward.draggable.floating_enabled = false
    chosen_reward.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
    chosen_reward.reparent(Globals.tile_grid, true)
    Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)

# After
if chosen_reward is Tile:
    Globals.tile_grid.receive_tile(chosen_reward, end_position)
```

---

## Step 3 — Update `shop.gd`

**Remove** line 6:
```gdscript
@export var tile_scene: PackedScene
```

**Replace** tile instantiation in `_create_shop_tiles()` (line ~74):
```gdscript
# Before
var tile: Tile = tile_scene.instantiate()
tile.tile_resource = possible_shop_tiles.pick_random()

# After
var chosen_resource: TileResource = possible_shop_tiles.pick_random()
var tile: Tile = Globals.tile_grid.create_tile(chosen_resource)
```

**Replace** tile handoff block in `_on_shop_item_dragged()` (lines 124-127):
```gdscript
# Before
if item is Tile:
    item.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
    item.reparent(Globals.tile_grid, true)
    Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)

# After
if item is Tile:
    Globals.tile_grid.receive_tile(item, end_position)
```

**Type the array** in `_get_possible_shop_tiles()` (line ~34):
```gdscript
# Before
var shop_tile_resources = []
# After
var shop_tile_resources: Array[TileResource] = []
```

---

## Step 4 — Update `reward_manager.gd`

**Type the array** in `get_possible_tile_rewards()` (line 31):
```gdscript
# Before
var player_tile_resources = []
# After
var player_tile_resources: Array[TileResource] = []
```

**Replace `_load_tile_resources()` body** to scan both folders:
```gdscript
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
```

`MapTileResources/` is intentionally excluded — `engine_charger.tres`, `map_arrow_left.tres`, `map_arrow_right.tres` are map-specific and should not be player rewards.

---

## Step 5 — Clean up `.tscn` files

The easiest approach: open `reward.tscn` and `shop.tscn` in the Godot editor after making the script changes. Godot will detect the orphaned `tile_scene` property and drop it automatically when you save. No manual `.tscn` editing needed.

If editing manually:

**`reward.tscn`** — remove line 5 (`ext_resource` for tile.tscn, id `3_f8ygb`) and line 14 (`tile_scene = ExtResource("3_f8ygb")`), and change `load_steps=6` → `load_steps=5` on line 1.

**`shop.tscn`** — remove line 4 (`ext_resource` for tile.tscn, id `2_bsm0f`) and line 15 (`tile_scene = ExtResource("2_bsm0f")`), and change `load_steps=7` → `load_steps=6` on line 1.

---

## Pitfalls to Watch

- **`emit_reached_new_home` on reward tiles:** `give_reward()` sets it `false` (suppress the snap sound during the floating preview). `receive_tile()` → `_assign_tile_to_grid_pos()` will reset `home_position`, which flips it back `true`. This means the snap sound plays when the tile lands on the grid — which is the correct behavior. No regression.
- **`floating_enabled` on shop tiles:** Shop tiles never explicitly set `floating_enabled = true` — they rely on the tile's default. `receive_tile()` sets it `false` unconditionally, which is correct.
- **`drag_ended` double-connect:** Both callers disconnect their own handler before calling `receive_tile()`, so `_drop_tile_on_grid_pos` is only connected once. Clean.

## Verification

1. Start a run, complete combat — reward screen appears with tiles.
2. Drag a tile reward outside the reward window — tile snaps into grid slot. Sound plays on snap.
3. Open shop — tiles appear. Drag a tile from shop (with enough money) — tile placed in grid.
4. Check that complicated tiles (e.g., `tactical_boomerang`) can now appear as rewards (may need a few runs or use dev console to verify `RewardManager._all_tile_resources` is populated).
5. Check Godot output for no warnings about missing `tile_scene` property on scene load.
