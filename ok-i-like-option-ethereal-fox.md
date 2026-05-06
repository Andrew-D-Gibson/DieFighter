# Addendum: Blocks 11 & 12 Rewrite — Modifier-Owned Visual Status Layer

## Context

The original Blocks 11 and 12 described creating `AmplifierModifier` and `LockoutModifier` as
`Modifier` subclasses but deferred the visual layer entirely. This addendum replaces those blocks
with a complete implementation that includes visuals, built on a generalized architecture that
works for any node type (tile, enemy, dice, player ship).

**Architecture:** Modifiers own their own visual lifecycle. Each `Modifier` stores a reference to
the game node it affects (`affected_node: Node2D`) and — when registered with the engine — spawns
a visual scene as a child of that node. When removed from the engine, it frees the visual. Tiles,
enemies, and dice don't need to know anything about the modifier system; the modifier handles
everything itself.

For cases where the same modifier type applies to different node types (e.g., `LockoutModifier`
on a `Tile` vs. on an `Enemy`), the modifier stores a per-type scene dictionary keyed by
GDScript `class_name`. A default fallback scene covers any type not explicitly listed.

**Replaces:** The entire `GridStatusEffect` hierarchy (`GridStatusEffect`, `AmplifierStatus`,
`AmplifierTileStatus`, `LockoutStatus`) and the `Events.add_status_to_grid_pos` pattern.

---

## Step A.1 — Rewrite `Modifier` Base Class

**File:** `Source/Behavior/Modifiers/modifier.gd`

Add all of the following to the existing fields and hooks. Do not remove `priority`,
`modifier_name`, or the existing hook methods.

```gdscript
## The node this modifier visually and semantically affects (tile, enemy, dice, etc.)
## Set this in _init() of any modifier that targets a specific node.
var affected_node: Node2D = null

## Per-type visual scenes, keyed by GDScript class_name (e.g. &"Tile", &"Enemy", &"Dice").
## If the affected_node's class is not in this dict, status_visual_scene is used instead.
var status_visual_scenes: Dictionary = {}

## Default visual scene. Used when status_visual_scenes is empty or has no match.
## Leave null for modifiers with no visual.
var status_visual_scene: PackedScene = null

## If true, this modifier is swept out by ScenarioEngine.clear_temporary_modifiers()
## at the start of each player turn.
var is_temporary: bool = false

var _visual: Node2D = null  # tracks the live instance for cleanup


## Called by ScenarioEngine.add_modifier(). Override to add extra setup logic,
## but always call super.on_registered(engine) to ensure the visual spawns.
func on_registered(_engine: ScenarioEngine) -> void:
    _spawn_visual()


## Called by ScenarioEngine.remove_modifier(). Override for extra cleanup,
## but always call super.on_unregistered(engine) to ensure the visual is freed.
func on_unregistered(_engine: ScenarioEngine) -> void:
    if is_instance_valid(_visual):
        _visual.queue_free()
        _visual = null


func _spawn_visual() -> void:
    if not is_instance_valid(affected_node):
        return
    var scene: PackedScene = _get_visual_for_host(affected_node)
    if not scene:
        return
    _visual = scene.instantiate()
    # Optional: visual can implement configure(host) to adjust itself per host type
    if _visual.has_method("configure"):
        _visual.configure(affected_node)
    affected_node.add_child(_visual)


func _get_visual_for_host(host: Node2D) -> PackedScene:
    if host.get_script() != null:
        var key: StringName = host.get_script().get_global_name()
        if not key.is_empty() and status_visual_scenes.has(key):
            return status_visual_scenes[key]
    return status_visual_scene  # null is fine — no visual spawns
```

---

## Step A.2 — Extend `ScenarioEngine`

**File:** `Source/Systems/Game/ScenarioEngine/scenario_engine.gd`

### 2a — Add signals (optional consumers: HUD, tutorial, debug)

```gdscript
signal modifier_added(mod: Modifier)
signal modifier_removed(mod: Modifier)
```

### 2b — Call lifecycle hooks and emit in `add_modifier()`

```gdscript
func add_modifier(mod: Modifier) -> void:
    modifiers.append(mod)
    sort_modifiers()
    mod.on_registered(self)   # modifier spawns its visual here
    modifier_added.emit(mod)  # for any other listeners (HUD, tutorial, etc.)
```

### 2c — Add `remove_modifier()`

```gdscript
func remove_modifier(mod: Modifier) -> void:
    modifiers.erase(mod)
    mod.on_unregistered(self)   # modifier frees its visual here
    modifier_removed.emit(mod)
```

### 2d — Add `clear_temporary_modifiers()`

```gdscript
func clear_temporary_modifiers() -> void:
    var to_remove: Array[Modifier] = []
    for mod: Modifier in modifiers:
        if mod.is_temporary:
            to_remove.append(mod)
    for mod: Modifier in to_remove:
        remove_modifier(mod)
```

### 2e — Wire to turn start in `_ready()`

```gdscript
func _ready() -> void:
    Events.player_turn_start.connect(clear_temporary_modifiers)
```

---

## Step A.3 — Clean Up `Tile`

**File:** `Source/Content/Tiles/tile.gd`

Since modifiers now manage their own visuals, `Tile` does not need to listen to
`modifier_added` / `modifier_removed` at all. The `set_scenario_engine()` setter stays as-is
(just storing the reference). No signal connections or handler methods are needed here.

The only required change is removing the `GridStatusEffect` check from `_get_tile_info()`.
Currently lines 107–115 return `null` when a status effect with info is present. Delete that
block — the method should always construct and return the `InfoResource`:

```gdscript
func _get_tile_info() -> InfoResource:
    var info: InfoResource = InfoResource.new()
    info.title_label_text = tile_resource.tile_name
    info.top_label_text = tile_resource.activation_description
    info.texture = tile_resource.textures.get_frame_texture('default', 0)
    info.bottom_label_text = _replace_event_data_in_string(tile_resource.description)
    info.side_label_text = tile_resource.hint_text
    return info
```

---

## Step A.4 — Create the Amplifier Visual Scene

**New scene:** `Source/Content/Tiles/StatusVisuals/amplifier_visual.tscn`
**New script:** `Source/Content/Tiles/StatusVisuals/amplifier_visual.gd`

This replaces the visual behavior of the old `AmplifierStatus`. The scene root is a `Node2D`.
Port the pulsing opacity tween from `amplifier_status.gd._ready()`:

```gdscript
class_name AmplifierVisual
extends Node2D


func _ready() -> void:
    var tween: Tween = create_tween().set_loops()
    tween.tween_property(self, "modulate:a", 0.4, 1.0)\
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "modulate:a", 0.1, 1.0)\
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
```

Add whatever sprite/polygon geometry the old `amplifier_status.tscn` had as children. The
tween operates on `modulate.a` of the root node so the entire visual pulses together.

---

## Step A.5 — Create the Lockout Visual Scenes

Create one scene per node type you want to support. Start with just the tile version; add the
enemy version when you reach Block 14.

**Tile lockout visual:**
- **New scene:** `Source/Content/Tiles/StatusVisuals/lockout_tile_visual.tscn`
- **New script:** `Source/Content/Tiles/StatusVisuals/lockout_tile_visual.gd`

```gdscript
class_name LockoutTileVisual
extends Node2D
# Pure visual — port sprite/label from the old lockout_status.tscn.
# Add animation in _ready() as desired.
```

**Enemy lockout visual (add when ready in Block 14):**
- **New scene:** `Source/Content/Tiles/StatusVisuals/lockout_enemy_visual.tscn`
- **New script:** `Source/Content/Tiles/StatusVisuals/lockout_enemy_visual.gd`

```gdscript
class_name LockoutEnemyVisual
extends Node2D
# Scale or offset differently from the tile version as needed.
```

---

## Step A.6 — Create `AmplifierModifier`

**New file:** `Source/Systems/Game/ScenarioEngine/Modifiers/TileStatus/amplifier_modifier.gd`

Amplifiers only ever target `Tile` nodes, so a single default scene is sufficient — no
per-type dictionary needed.

```gdscript
class_name AmplifierModifier
extends Modifier

var amplify_amount: int


func _init(tile: Tile, amount: int) -> void:
    affected_node = tile
    amplify_amount = amount
    priority = 20        # flat additive; runs before multipliers
    is_temporary = true
    modifier_name = "Amplifier"
    status_visual_scene = preload("res://Source/Content/Tiles/StatusVisuals/amplifier_visual.tscn")


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
    if event is DamageEvent and event.effect_source == affected_node:
        event.amount += amplify_amount
```

**Note:** `affected_node` is the **neighbor tile** (the one being amplified), not the source
tile that triggered the effect. The visual appears on the neighbor.

---

## Step A.7 — Rewrite `AddAmplifierStatusEvent`

**File:** `Source/Behavior/EffectsV2/EffectEvents/TileControl/add_amplifier_status_event.gd`

Replace the entire body. No longer instantiates `AmplifierTileStatus`; registers one
`AmplifierModifier` per valid neighbor directly on the engine:

```gdscript
class_name AddAmplifierStatusEvent
extends EffectEvent


func resolve(engine: ScenarioEngine) -> void:
    if not is_instance_valid(effect_source):
        return
    if effect_source is not Tile:
        return

    var source_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(effect_source)
    if not Globals.tile_grid.is_grid_pos_valid(source_pos):
        return

    for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1)]:
        var neighbor_pos: Vector2i = source_pos + offset
        if Globals.tile_grid.tile_locations.has(neighbor_pos):
            var neighbor_tile: Tile = Globals.tile_grid.tile_locations[neighbor_pos]
            engine.add_modifier(AmplifierModifier.new(neighbor_tile, amount))
```

`engine.add_modifier()` calls `mod.on_registered()` which spawns the visual on the neighbor
tile automatically. No separate signal handling required.

---

## Step A.8 — Create `LockoutModifier`

**New file:** `Source/Systems/Game/ScenarioEngine/Modifiers/TileStatus/lockout_modifier.gd`

Uses the per-type scene dictionary. The enemy branch is a forward-declared stub for Block 14 —
the `EnemyActionEvent` class won't exist yet, but GDScript won't error on the `is` check at
parse time; it just never matches. Add the enemy visual scene to the dict when you create it.

```gdscript
class_name LockoutModifier
extends Modifier


func _init(node: Node2D) -> void:
    affected_node = node
    priority = 0         # cancellation runs first, before any value adjustments
    is_temporary = true
    modifier_name = "Lockout"
    status_visual_scenes = {
        &"Tile":  preload("res://Source/Content/Tiles/StatusVisuals/lockout_tile_visual.tscn"),
        # &"Enemy": preload("res://Source/Content/Tiles/StatusVisuals/lockout_enemy_visual.tscn"),
        # Uncomment above when lockout_enemy_visual.tscn exists (Block 14)
    }


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
    # Tile lockout
    if event is TileActivationEvent and (event as TileActivationEvent).tile == affected_node:
        event.canceled = true
        var lockout_event := LockoutEffectEvent.new()
        lockout_event.effect_source = affected_node
        lockout_event.activator_die = (event as TileActivationEvent).activator_die
        engine.inject_event(lockout_event)

    # Enemy lockout (Block 14: uncomment when EnemyActionEvent exists)
    # elif event is EnemyActionEvent and event.actor == affected_node:
    #     event.canceled = true
    #     # Handle die or other enemy lockout consequences here
```

---

## Step A.9 — Create `LockoutEffectEvent`

**New file:** `Source/Behavior/EffectsV2/EffectEvents/TileControl/lockout_effect_event.gd`

Handles the die cleanup that `TileActivationEvent.resolve()` never ran (because it was
canceled). Die fate: **return to player**.

```gdscript
class_name LockoutEffectEvent
extends EffectEvent

var activator_die: Dice


func resolve(_engine: ScenarioEngine) -> void:
    if effect_source is not Tile:
        return

    var tile := effect_source as Tile

    # Die is still in the visual queue — TileActivationEvent never got to remove it
    if is_instance_valid(activator_die):
        tile.dice_queue.remove(activator_die)
        Events.error_text_popup.emit("LOCATION LOCKED", tile.global_position)
        Globals.player.dice_manager.add(activator_die, true, false)
```

---

## Step A.10 — Rewrite `LockoutTileEvent`

**File:** `Source/Behavior/EffectsV2/EffectEvents/TileControl/lockout_tile_event.gd`

Replace the entire body. No longer instantiates `LockoutStatus`:

```gdscript
class_name LockoutTileEvent
extends EffectEvent


func resolve(engine: ScenarioEngine) -> void:
    for target: Node in targets:
        if not is_instance_valid(target):
            continue
        if target is not Tile:
            continue
        engine.add_modifier(LockoutModifier.new(target as Tile))
```

---

## Step A.11 — Delete Old Code

Work through these in order. Run the game after each deletion and fix any remaining references.

1. **Delete** `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_status.gd`
2. **Delete** `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_status.tscn`
3. **Delete** `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_tile_status.gd`
4. **Delete** `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_tile_status.tscn`
5. **Delete** `Source/Systems/Game/TileGrid/GridStatusEffects/LockoutStatus/lockout_status.gd`
6. **Delete** `Source/Systems/Game/TileGrid/GridStatusEffects/LockoutStatus/lockout_status.tscn`
7. **Delete** `Source/Systems/Game/TileGrid/GridStatusEffects/grid_status_effect.gd`
8. **Search** for any remaining `GridStatusEffect` type annotations in `tile.gd` and remove them.
9. **Search** for `Events.add_status_to_grid_pos` — should be zero calls left. Remove any found.
10. **Search** for `Globals.tile_grid.grid_status_effects` — remove remaining references.
    The dictionary itself can be removed from `TileGrid` once nothing uses it.

---

## Block 14 Hook — Extending to Enemies

When you reach Block 14 and create `EnemyActionEvent`:

1. Create `Source/Content/Tiles/StatusVisuals/lockout_enemy_visual.tscn` with an appropriate
   visual for showing a locked enemy.
2. Uncomment the `&"Enemy"` entry in `LockoutModifier.status_visual_scenes`.
3. Uncomment the `EnemyActionEvent` branch in `LockoutModifier.on_before_event()`.
4. In `LockoutTileEvent.resolve()` (or a new `LockoutEnemyEvent`), change the target check
   from `target is Tile` to also accept `Enemy` nodes:
   ```gdscript
   engine.add_modifier(LockoutModifier.new(target))  # works for any Node2D
   ```

No other changes needed — the modifier and visual system generalizes automatically.

---

## Known Limitation — Amplifier Visual on Mid-Turn Tile Movement

The old `AmplifierTileStatus` recomputed neighbor amplification when the source tile was pushed
mid-turn. This addendum does not implement that behavior. Since `AmplifierModifier` is
`is_temporary`, stale visuals clear at turn start regardless. If mid-turn tile pushes become a
design issue, the fix is to remove and re-register the amplifier modifiers in response to
`Events.tile_pushed`.

---

## Verification

1. **Amplifier tile:**
   - Activate an amplifier tile. The pulsing visual appears on the tiles above and below it
     (not on the amplifier source tile itself).
   - Activate a neighbor. Damage is boosted by the correct amount.
   - Start the next turn. Visuals disappear, boost is gone.

2. **Lockout tile:**
   - Activate a tile that locks a target. Lockout visual appears on the target tile.
   - Drop a die on the locked tile. "LOCATION LOCKED" popup appears, die is returned to player,
     tile does not activate.
   - Start the next turn. Lockout visual disappears.

3. **Modifier lifecycle smoke test:**
   - Temporarily add `print("registered: ", mod.modifier_name)` in `Modifier.on_registered()`
     and `print("unregistered: ", mod.modifier_name)` in `Modifier.on_unregistered()`.
   - Confirm "registered" prints when the amplifier/lockout fires, and "unregistered" prints
     at `player_turn_start`.

4. **No `GridStatusEffect` references remain** — search for `GridStatusEffect`,
   `add_status_to_grid_pos`, and `grid_status_effects`. All should return zero results.
