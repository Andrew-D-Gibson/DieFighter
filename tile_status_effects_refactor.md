# Plan: Refactor Tile Status Effects into ScenarioEngine Modifiers

## Context

The current `GridStatusEffect` system is architecturally disconnected from the new `ScenarioEngine`. Statuses like `AmplifierStatus` hook into combat by injecting Callables into `EffectVariables.amount_modifiers` during `Tile.activate()`, bypassing the modifier/event pipeline entirely. The result is two parallel modifier systems that don't know about each other, complex two-level status hierarchies (AmplifierTileStatus spawning child AmplifierStatus nodes), and fragile lifecycle management via manual signal connections.

The goal is to replace tile statuses with `Modifier` subclasses registered directly with the `ScenarioEngine`, so all combat modification flows through a single pipeline.

---

## Answer to the Core Design Question

**Yes — tile statuses become global Modifiers with conditional checks.** An `AmplifierModifier` is added to the engine for each amplified tile; in `on_before_event()` it checks `event.effect_source == amplified_tile` before adjusting `event.amount`. This is the right tradeoff: the engine's modifier list is a small O(N) scan per event, and the conditional is trivially cheap.

---

## Files to Create

- `Source/Behavior/Modifiers/TileStatus/amplifier_modifier.gd`
- `Source/Behavior/Modifiers/TileStatus/lockout_modifier.gd` (see below)
- `Source/Behavior/EffectsV2/EffectHandlers/TileStatus/add_amplifier_handler.gd`
- `Source/Behavior/EffectsV2/EffectHandlers/TileStatus/lockout_tile_handler.gd`
- `Source/Behavior/EffectsV2/EffectEvents/TileControl/lockout_effect_event.gd`

## Files to Modify

- `Source/Behavior/Modifiers/modifier.gd` — add `is_temporary: bool = false`
- `Source/Systems/Game/ScenarioEngine/scenario_engine.gd` — add `clear_temporary_modifiers()`
- `Source/Systems/Autoloads/effect_registry.gd` — register new handlers
- `Source/Behavior/EffectsV2/effect_enums.gd` — add TILE_STATUS subtype entries

## Files to Delete (after migration)

- `Source/Content/Effects/TileStatusEffects/add_amplifier_status_effect.gd`
- `Source/Content/Effects/TileStatusEffects/lockout_target_tile_effect.gd`
- `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_status.gd`
- `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_tile_status.gd`
- `Source/Systems/Game/TileGrid/GridStatusEffects/LockoutStatus/lockout_status.gd`
- `Source/Systems/Game/TileGrid/GridStatusEffects/grid_status_effect.gd`

---

## Step 1 — Add Temporary Modifier Support to Modifier + Engine

**`modifier.gd`:** Add one field:
```gdscript
var is_temporary: bool = false
```

**`scenario_engine.gd`:** Add one method called at the start of the player's turn:
```gdscript
func clear_temporary_modifiers() -> void:
    modifiers = modifiers.filter(func(m): return not m.is_temporary)
```

Wire this call to `Events.player_turn_start` inside `ScenarioEngine._ready()`. This replaces the manual `queue_free()` + signal disconnection in `AmplifierTileStatus`.

---

## Step 2 — AmplifierModifier

**`amplifier_modifier.gd`:**
```gdscript
class_name AmplifierModifier
extends Modifier

var amplified_tile: Tile
var amplify_amount: int

func _init(tile: Tile, amount: int) -> void:
    amplified_tile = tile
    amplify_amount = amount
    priority = 20           # flat additive, runs early
    is_temporary = true     # cleared at turn start

func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
    if event is DamageEvent and event.effect_source == amplified_tile:
        event.amount += amplify_amount
```

Note: scope `event is DamageEvent` broadly — if you later want amplifier to also boost ShieldEvents, add `or event is ShieldEvent`.

---

## Step 3 — AddAmplifierHandler

Replaces `AddAmplifierStatusEffect`. Gets the source tile's grid position, looks up the tiles directly above and below it, and registers one `AmplifierModifier` per valid neighbor.

**`add_amplifier_handler.gd`:**
```gdscript
class_name AddAmplifierHandler
extends EffectHandler

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
    if not is_instance_valid(context.effect_source):
        return
    if context.effect_source is not Tile:
        return

    var source_pos: Vector2i = Globals.tile_grid.find_tile_pos(context.effect_source)
    if not Globals.tile_grid.is_grid_pos_valid(source_pos):
        return

    # Amplify the tiles directly above and below
    for offset in [Vector2i(0, -1), Vector2i(0, 1)]:
        var neighbor_pos: Vector2i = source_pos + offset
        if Globals.tile_grid.tile_locations.has(neighbor_pos):
            var neighbor_tile: Tile = Globals.tile_grid.tile_locations[neighbor_pos]
            engine.add_modifier(AmplifierModifier.new(neighbor_tile, data.amount))
```

`data.amount` carries the amplify value (previously `amplify_amount` exported on the old effect).

**Visual representation:** The old `AmplifierStatus` node provided visual feedback on the tile. For now, keep a lightweight visual-only node (no gameplay logic) that gets added/removed separately — or skip visuals and add them back later as a polish pass. Gameplay correctness first.

---

## Step 4 — LockoutModifier + LockoutTileHandler

Lockout is trickier because it prevents activation rather than modifying a numeric value. Two-phase approach:

### Phase A — Introduce a TileActivationEvent

When a tile activates, instead of calling `EffectChainV2.play()` directly, `Tile.activate()` queues a `TileActivationEvent`. The engine processes it; if not canceled, the event's `resolve()` calls `effect_chain_v2.play(context, engine)`.

This makes lockout a first-class engine concern:

**`lockout_modifier.gd`:**
```gdscript
class_name LockoutModifier
extends Modifier

var locked_tile: Tile

func _init(tile: Tile) -> void:
    locked_tile = tile
    priority = 0        # runs first; cancellation/immunity range
    is_temporary = true

func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
    if event is TileActivationEvent and event.effect_source == locked_tile:
        event.canceled = true
        # Queue the "on lockout" chain instead
        var lockout_event := LockoutEffectEvent.new()
        lockout_event.effect_source = locked_tile
        lockout_event.actor = event.actor
        lockout_event.activator_die = event.activator_die
        engine.queue_event(lockout_event)
```

**`lockout_effect_event.gd`:**
```gdscript
class_name LockoutEffectEvent
extends EffectEvent

func resolve(_engine: ScenarioEngine) -> void:
    # Play the tile's on_lockout_disabled_effects chain
    if effect_source is Tile:
        var tile := effect_source as Tile
        # ... call tile's lockout chain
```

### Phase B — If TileActivationEvent is too large a scope right now

Keep `Tile.can_activate()` checking for lockout at the tile level (hybrid approach), but port the lockout *effects* (the chain that plays when you try to use a locked tile) into `EffectChainV2` so it uses the new data-driven system. This is a smaller change that still cleans up the Callable mess.

**Recommendation:** Do Phase A — it's the architecturally correct move and `TileActivationEvent` is a natural fit for the engine. But Phase B is a valid intermediate step if you want to ship the amplifier refactor first.

---

## Step 5 — Register New Handlers in EffectRegistry

Add subtype enum entries in `effect_enums.gd`:
```gdscript
enum TileStatus { ADD_AMPLIFIER, LOCKOUT_TILE }
```

Register in `effect_registry.gd`:
```gdscript
_register(Category.TILE_STATUS, TileStatus.ADD_AMPLIFIER, AddAmplifierHandler.new())
_register(Category.TILE_STATUS, TileStatus.LOCKOUT_TILE, LockoutTileHandler.new())
```

---

## Step 6 — Migrate Tile Resources and Delete Old Code

For each tile that used `AddAmplifierStatusEffect` in its old EffectChain:
1. Open the tile resource in the inspector
2. Replace the old effect with an `EffectData` entry: `category=TILE_STATUS, subtype=ADD_AMPLIFIER, amount=<amplify_value>`
3. Test that amplification works

Once all tiles are migrated, delete the old `GridStatusEffect` classes and their scenes.

---

## Verification

1. Activate an amplifier tile — confirm adjacent tiles deal boosted damage
2. Confirm boosted damage is gone on the next turn (temporary modifier cleared)
3. Activate a locked tile — confirm it doesn't fire, lockout chain plays, die is consumed
4. Confirm `ScenarioEngine.modifiers` list has no leaks after a full turn cycle (add a debug print in `clear_temporary_modifiers`)
5. Confirm `DoubleDamageModifier` still stacks correctly with `AmplifierModifier` (check priority ordering)
