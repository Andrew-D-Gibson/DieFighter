# StellaRoller — Refactor Guide: Block 8 Onward
## Continuing from the ScenarioEngine infrastructure (Blocks 1–7 complete)

This guide assumes:
- `ScenarioEngine` exists and processes a queue of `EffectEvent`s with modifier hooks.
- `EffectChainV2`, `EffectHandler`, `EffectRegistry`, and all core handlers are implemented.
- `TileResource` already has `effect_chain_v2: EffectChainV2` and `event_responses_v2` exports.
- At least one simple tile has been partially wired for testing.

---

## Block 8 — TileActivationEvent + Engine Fixes + First Tile End-to-End (~1 hr)

**Goal:** Introduce `TileActivationEvent` so that dropping a die on a tile enqueues activation
into the `ScenarioEngine` rather than calling `ActivationQueueManager`. Keep the legacy
`ActivationQueueManager` path as a fallback during transition. Verify one tile works completely.

---

### Step 8.1 — Fix Two Bugs in `scenario_engine.gd`

**File:** `Source/Systems/Game/ScenarioEngine/scenario_engine.gd`

**Bug 1 — `break` should be `continue` for canceled events.**

The current code does:
```gdscript
if event.canceled:
    break
```
This stops the entire queue when any single event is canceled. That is wrong — it should
skip the canceled event and keep processing the rest. Change to:
```gdscript
if event.canceled:
    continue
```

Also: `event_resolved` should only emit when the event was NOT canceled. Move the emit
inside the `if not event.canceled` block. The corrected loop looks like this:

```gdscript
func process_event_queue() -> void:
    began_processing_queue.emit()
    currently_processing_queue = true

    while not event_queue.is_empty():
        var event: EffectEvent = event_queue.pop_front()

        for mod in modifiers:
            await mod.on_before_event(event, self)

        if event.canceled:
            continue

        await event.resolve(self)
        event_resolved.emit(event)

        for mod in modifiers:
            await mod.on_after_event(event, self)

    currently_processing_queue = false
    finished_processing_queue.emit()
```

**Bug 2 — Add auto-processing to `queue_event()`.**

Currently, nothing calls `process_event_queue()` when a die is dropped during the player's
turn. Add a fire-and-forget trigger so the engine wakes itself up:

```gdscript
func queue_event(event: EffectEvent) -> void:
    event_queue.append(event)
    if not currently_processing_queue:
        process_event_queue()  # coroutine starts, re-entrancy guard prevents double-start
```

Calling a coroutine without `await` in GDScript 4 is safe and intentional here — it starts
the processing loop running asynchronously and returns immediately. The
`currently_processing_queue` flag prevents a second loop from starting if this is called
while already processing.

---

### Step 8.2 — Make `_clears_activation_criteria` Public

**File:** `Source/Content/Tiles/tile.gd`

Rename `_clears_activation_criteria` → `clears_activation_criteria` (remove the leading
underscore). `TileActivationEvent` will call this directly on the tile, bypassing the static
queue logic in `can_activate()`. Update the one internal call site in `can_activate()` too.

```gdscript
# Before:
func _clears_activation_criteria(activator_die: Dice = null) -> bool:

# After:
func clears_activation_criteria(activator_die: Dice = null) -> bool:
```

---

### Step 8.3 — Create `TileActivationEvent`

**New file:** `Source/Systems/Game/ScenarioEngine/Events/tile_activation_event.gd`

```gdscript
class_name TileActivationEvent
extends EffectEvent

var tile: Tile
var activator_die: Dice


func resolve(engine: ScenarioEngine) -> void:
    if not is_instance_valid(tile):
        return

    # Activation criteria check (uses remaining, ActivationResource checks)
    if not tile.clears_activation_criteria(activator_die):
        # Return the die to the player's hand and get it out of the visual queue
        if is_instance_valid(activator_die):
            Globals.player.dice_manager.add(activator_die, true, false)
        tile.dice_queue.remove(activator_die)
        return

    # Decrement uses now that we're committed to activating
    if tile.uses_remaining != -1:
        tile.uses_remaining -= 1

    # Remove die from the visual stacking queue — it's about to fly to tile center
    tile.dice_queue.remove(activator_die)

    # Tween the die to the tile center (identical to old Tile.activate() tween)
    if activator_die:
        activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
        var tween_time: float = 0.2 / Globals.animation_speed
        var tween: Tween = tile.create_tween().set_parallel(true)
        tween.tween_property(
            activator_die,
            'global_position',
            tile.global_position + Vector2(0, 6),
            tween_time
        ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(
            activator_die,
            'scale',
            Vector2(0.75, 0.75),
            tween_time
        ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        await tween.finished

    tile.shakeable.large_shake()

    # Build the EffectContext for this activation
    var context: EffectContext = EffectContext.new()
    context.actor = Globals.player
    context.effect_source = tile
    context.activator_die = activator_die

    # Play the v2 effect chain — this enqueues more events; the engine's while-loop
    # picks them up automatically because they're appended to the same event_queue.
    if tile.tile_resource.effect_chain_v2:
        await tile.tile_resource.effect_chain_v2.play(context, engine)

    Events.tile_activation_complete.emit()
```

**Why no grid-status manipulation here?** The old `activate()` called
`status_effect.manipulate_effect_variables(effect_variables)` to let lockout/amplifier
statuses modify behavior. In the new system, those statuses become `Modifier` subclasses
registered with the engine. `AmplifierModifier` intercepts events in `on_before_event()`;
`LockoutModifier` cancels `TileActivationEvent` in `on_before_event()` before `resolve()`
ever runs. No context manipulation needed here — the engine's modifier hooks handle it all.

---

### Step 8.4 — Update `Tile._on_die_accepted()` to Enqueue `TileActivationEvent`

**File:** `Source/Content/Tiles/tile.gd`

Replace the `ActivationQueueManager` call with a ScenarioEngine enqueue, keeping the legacy
path as a fallback so tiles without a scenario engine still work during the transition:

```gdscript
func _on_die_accepted(die: Dice) -> void:
    if not die:
        return

    dice_queue.add(die, true, false)
    Events.die_placed_on_tile.emit(die, self)

    if scenario_engine:
        var event := TileActivationEvent.new()
        event.tile = self
        event.activator_die = die
        scenario_engine.queue_event(event)
    elif Globals.activation_queue_manager:
        Globals.activation_queue_manager.add_die_to_queue(die)
```

The tile does NOT await anything here. The engine runs asynchronously. If the engine is
already processing a prior die's events, the new `TileActivationEvent` is simply appended
to the queue and will be processed after the current events finish.

---

### Step 8.5 — Author the First V2 Tile and Run the Game

Pick the simplest "deal damage to enemy" tile you have — one that just targets an enemy and
deals fixed damage. Follow the `worked_example_damage_tile.md` guide to author the
`EffectChainV2` resource and assign it to `tile_resource.effect_chain_v2`.

Run the game. Drop a die on that tile. You should see:
- The die flies to the tile center (tween plays).
- The tile shakes.
- The enemy takes damage.
- No errors about `ActivationQueueManager` or the old `activate()` path (the tile uses v2).

If the tile falls through to the legacy path, add a temporary `print("v2 path")` inside
`TileActivationEvent.resolve()` to confirm it's being reached.

### Done when
One tile activates fully through `TileActivationEvent` → `EffectChainV2` → engine event
queue → `DamageEvent.resolve()` in a real game session, with no errors.

### Watch out for
- The `TileActivationEvent` must be added to `Source/Systems/Game/ScenarioEngine/Events/`.
  Godot needs to parse it for the `class_name` to be recognized. If it's not seen, restart
  the editor.
- `tile.dice_queue.remove(activator_die)` is the correct call (see `dice_queue.gd` —
  `remove()` takes a `Dice` and emits `die_removed`).
- `tile.create_tween()` is correct — `TileActivationEvent` doesn't extend Node, so it
  can't call `create_tween()` directly. Delegate to the tile node.

---

## Block 9 — Remove `ActivationQueueManager` (~1 hr)

**Goal:** Delete the old activation manager entirely. The `ScenarioEngine` now owns the
activation queue. Remove all related static state from `tile.gd`.

--

### Step 9.1 — Audit All Usages First

Before deleting anything, search the project for these patterns:
```
activation_queue_manager
dice_activation_queue
can_activate
Tile.dice_activation_queue
```

You should find references in:
- `Source/Content/Tiles/tile.gd` — the static var, `can_activate()`, and the fallback in `_on_die_accepted()`
- `Source/Systems/Autoloads/globals.gd` — `var activation_queue_manager`
- `Source/Systems/Game/TileGrid/ActivationQueueManager/activation_queue_manager.gd` — the whole file
- The scene file where `ActivationQueueManager` is instantiated (find it by searching `.tscn` files)

Make a list. Work through each one.

---

### Step 9.2 — Remove from `tile.gd`

**File:** `Source/Content/Tiles/tile.gd`

1. **Delete the static variable:**
   ```gdscript
   # DELETE this entire line:
   static var dice_activation_queue: Array[Dice] = []
   ```

2. **Delete `can_activate()`** — its only remaining job was managing the static queue.
   The criteria check (`clears_activation_criteria`) is now called directly by
   `TileActivationEvent`. Delete the whole `can_activate()` method.

3. **Simplify `_on_die_accepted()`** — remove the `elif` legacy path since
   `ActivationQueueManager` is being deleted:
   ```gdscript
   func _on_die_accepted(die: Dice) -> void:
       if not die:
           return
       dice_queue.add(die, true, false)
       Events.die_placed_on_tile.emit(die, self)
       if scenario_engine:
           var event := TileActivationEvent.new()
           event.tile = self
           event.activator_die = die
           scenario_engine.queue_event(event)
   ```

4. **Remove the old `activate()` method** only after all tiles have been migrated to
   `effect_chain_v2`. For now, you can leave it as dead code or add a deprecation comment.
   It will be deleted in Block 17.

---

### Step 9.3 — Remove from `globals.gd`

**File:** `Source/Systems/Autoloads/globals.gd`

Delete the line:
```gdscript
var activation_queue_manager: ActivationQueueManager
```

---

### Step 9.4 — Remove the Scene Instance and Delete the File

1. Find the scene that instances `ActivationQueueManager` (search `.tscn` files for
   `"activation_queue_manager"` or the file path). Open that scene in the Godot editor and
   delete the `ActivationQueueManager` node.

2. Delete the files:
   - `Source/Systems/Game/TileGrid/ActivationQueueManager/activation_queue_manager.gd`
   - `Source/Systems/Game/TileGrid/ActivationQueueManager/activation_queue_manager.tscn`

---

### Step 9.5 — Remove `Events.tile_activation_complete` listener (if orphaned)

`ActivationQueueManager._ready()` connected to `Events.tile_activation_complete` to chain
the next activation. Now that the ScenarioEngine's `while` loop handles sequencing,
`tile_activation_complete` is emitted by `TileActivationEvent.resolve()` but nothing needs
to respond to it for sequencing purposes. Check if anything else listens to it. If not,
you can leave the emission in place (it's harmless and useful for tutorial hooks) or remove
it later.

### Done when
No references to `ActivationQueueManager`, `activation_queue_manager`, or
`dice_activation_queue` remain in the codebase. The game runs and tiles activate in the
correct order when multiple dice are dropped in quick succession.

### Watch out for
- If the `TutorialManager` or any other system listens to `tile_activation_complete`, make
  sure those connections still work after this change. The signal is still emitted from
  `TileActivationEvent.resolve()` — listeners just need to stay connected to it.
- Test rapid die placement: drop die on tile A, immediately drop on tile B. Both should
  activate in order. The engine's while-loop handles sequencing naturally.

---

## Block 10 — Remove `GlobalModifierManager` (~1 hr)

**Goal:** Replace the old modifier system entirely. All combat modifications flow through
the `ScenarioEngine`'s modifier list.

*(This is the original Block 9 from the old guide, reproduced here for completeness.)*

### Tasks

1. **Audit `GlobalModifierManager`:** Read `global_modifier_manager.gd`. List every place
   in the project that calls `Globals.modifier_manager.add_modifier(...)`. Search for:
   ```
   modifier_manager.add_modifier
   calculate_final_amount_with_global_modifiers
   ```

2. **For each modifier type found:** Create a corresponding `Modifier` subclass under
   `Source/Systems/Game/ScenarioEngine/Modifiers/`. Model them on the inspiration examples
   (`DoubleDamageModifier`, `ShieldOnDamageModifier`).

3. **Replace registration call sites:**
   ```gdscript
   # OLD — delete this:
   Globals.modifier_manager.add_modifier(GlobalModifier.new(...))

   # NEW — replace with:
   scenario_engine.add_modifier(MyNewModifier.new())
   ```

4. **Remove `calculate_final_amount_with_global_modifiers()` call sites.** In
   `DamageEffect.play()`, `HealEffect`, `ShieldEffect`, etc., this call is now replaced
   by the engine's `on_before_event()` modifier hooks. Delete every call to it.

5. **Delete `GlobalModifierManager` from the project:**
   - Remove from Autoloads (Project Settings → Autoloads).
   - Delete `global_modifier_manager.gd` and `global_modifier.gd`.
   - Remove `var modifier_manager: GlobalModifierManager` from `globals.gd`.

6. **Run the game.** Verify damage amounts are correct and upgrades still apply.

### Done when
No references to `GlobalModifierManager` or `modifier_manager` exist. Combat modifiers
work correctly via the new `Modifier` system.

### Watch out for
- Temporary modifiers (expire after one turn) need active removal.
  Connect to `Events.player_turn_start` and call `engine.remove_modifier(mod)` at the
  right moment. The engine does not manage expiry automatically.

---

## Block 11 — Tile Status Refactor Part 1: AmplifierModifier (~1 hr)

**Goal:** Replace the two-level `AmplifierStatus` / `AmplifierTileStatus` node hierarchy
with a simple `AmplifierModifier` registered on the `ScenarioEngine`. All amplification
flows through the engine's modifier hooks.

---

### Step 11.1 — Add Temporary Modifier Support

**File:** `Source/Systems/Game/ScenarioEngine/Modifiers/modifier.gd`

Add one field:
```gdscript
var is_temporary: bool = false
```

**File:** `Source/Systems/Game/ScenarioEngine/scenario_engine.gd`

Add a method for clearing per-turn temporary modifiers:
```gdscript
func clear_temporary_modifiers() -> void:
    modifiers = modifiers.filter(func(m: Modifier) -> bool: return not m.is_temporary)
```

Wire this to the player turn signal in `ScenarioEngine._ready()`:
```gdscript
func _ready() -> void:
    Events.player_turn_start.connect(clear_temporary_modifiers)
```

This replaces the manual `queue_free()` + signal disconnection that `AmplifierTileStatus`
currently does. Every `is_temporary = true` modifier is swept out automatically at turn start.

---

### Step 11.2 — Create `AmplifierModifier`

**New file:** `Source/Systems/Game/ScenarioEngine/Modifiers/TileStatus/amplifier_modifier.gd`

```gdscript
class_name AmplifierModifier
extends Modifier

var amplified_tile: Tile
var amplify_amount: int


func _init(tile: Tile, amount: int) -> void:
    amplified_tile = tile
    amplify_amount = amount
    priority = 20       # flat additive; runs before multipliers
    is_temporary = true # cleared at turn start


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
    if event is DamageEvent and event.effect_source == amplified_tile:
        event.amount += amplify_amount
```

To also amplify shield events from the same tile, add `or event is ShieldEvent` to the
condition. Keep it narrow for now and expand as gameplay demands it.

---

### Step 11.3 — Create `AddAmplifierHandler`

**New file:** `Source/Behavior/EffectsV2/EffectHandlers/TileStatus/add_amplifier_handler.gd`

This handler replaces `AddAmplifierStatusEffect`. It finds the tiles directly above and
below the source tile on the grid and registers one `AmplifierModifier` per valid neighbor.

```gdscript
class_name AddAmplifierHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
    if not is_instance_valid(context.effect_source):
        return
    if not context.effect_source is Tile:
        return

    var source_pos: Vector2i = Globals.tile_grid.find_tile_pos(context.effect_source)
    if not Globals.tile_grid.is_grid_pos_valid(source_pos):
        return

    for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1)]:
        var neighbor_pos: Vector2i = source_pos + offset
        if Globals.tile_grid.tile_locations.has(neighbor_pos):
            var neighbor_tile: Tile = Globals.tile_grid.tile_locations[neighbor_pos]
            engine.add_modifier(AmplifierModifier.new(neighbor_tile, data.amount))
```

`data.amount` is the amplify value. Set it in the inspector on the `EffectData` resource
for any tile that applies amplification.

**Note on visuals:** The old `AmplifierStatus` node showed a visual indicator on the
amplified tile. For now, skip re-implementing the visual — gameplay correctness first.
After migration is confirmed working, you can add a lightweight visual-only layer without
any game logic.

---

### Step 11.4 — Register the Handler

**File:** `Source/Systems/Autoloads/effect_registry.gd` (or wherever your registry lives)

Add a `TILE_STATUS` category and subtype to your enums if not already present:

**File:** `Source/Behavior/EffectsV2/effect_enums.gd`
```gdscript
enum TileStatusSubtype { ADD_AMPLIFIER, LOCKOUT_TILE }
```

And in `effect_registry.gd._register_all()`:
```gdscript
_register(EffectEnums.Category.TILE_STATUS, EffectEnums.TileStatusSubtype.ADD_AMPLIFIER, AddAmplifierHandler.new())
```

---

### Step 11.5 — Migrate Amplifier Tiles and Delete Old Code

For each tile that used `AddAmplifierStatusEffect` in its old `EffectChain`:
1. Open the tile resource in the inspector.
2. In `effect_chain_v2`, replace the old amplifier effect entry with:
   `category = TILE_STATUS, subtype = ADD_AMPLIFIER, amount = <your_amplify_value>`
3. Test in-game: activate the amplifier tile, then activate the neighbor — confirm boosted
   output. Confirm the boost is gone the following turn.

Once all amplifier tiles are migrated:
- Delete `Source/Content/Effects/TileStatusEffects/add_amplifier_status_effect.gd`
- Delete `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_status.gd`
- Delete `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_tile_status.gd`

### Done when
- Activating an amplifier tile registers `AmplifierModifier` on the engine.
- Neighboring tiles deal boosted damage/shields for that turn.
- Boost is gone at turn start (temporary modifier cleared).
- No old `AmplifierStatus` nodes exist in the scene tree.

---

## Block 12 — Tile Status Refactor Part 2: LockoutModifier (~1 hr)

**Goal:** Replace the lockout status system with `LockoutModifier`, which cancels
`TileActivationEvent` via the engine's `on_before_event()` hook. This is the first time
`TileActivationEvent` cancellation is used — make sure Block 11's engine fix (break →
continue) is in place first.

---

### Step 12.1 — Create `LockoutModifier`

**New file:** `Source/Systems/Game/ScenarioEngine/Modifiers/TileStatus/lockout_modifier.gd`

```gdscript
class_name LockoutModifier
extends Modifier

var locked_tile: Tile


func _init(tile: Tile) -> void:
    locked_tile = tile
    priority = 0        # cancellation runs first, before any value adjustments
    is_temporary = true # cleared at turn start


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
    if event is TileActivationEvent and event.effect_source == locked_tile:
        event.canceled = true
        # Queue a follow-up event to handle the locked-out activation
        var lockout_event := LockoutEffectEvent.new()
        lockout_event.effect_source = locked_tile
        lockout_event.actor = event.actor
        lockout_event.activator_die = (event as TileActivationEvent).activator_die
        engine.queue_event(lockout_event)
```

---

### Step 12.2 — Update `TileActivationEvent` to Expose `activator_die`

`LockoutModifier` needs to read `activator_die` from the `TileActivationEvent`. The field
is already there (you defined it in Block 8). But `on_before_event` receives an `EffectEvent`
base reference, so cast it:
```gdscript
lockout_event.activator_die = (event as TileActivationEvent).activator_die
```
This is correct — GDScript 4 allows this cast safely.

---

### Step 12.3 — Create `LockoutEffectEvent`

**New file:** `Source/Systems/Game/ScenarioEngine/Events/lockout_effect_event.gd`

This event handles what happens when a locked tile is activated: the die needs to be
removed from the visual queue (it was already there when the die was dropped), and the
tile's lockout effects need to play.

```gdscript
class_name LockoutEffectEvent
extends EffectEvent

var activator_die: Dice


func resolve(engine: ScenarioEngine) -> void:
    # Remove die from visual queue (it was added in _on_die_accepted, 
    # but TileActivationEvent.resolve() never ran to remove it since the event was canceled)
    if effect_source is Tile and is_instance_valid(activator_die):
        var tile := effect_source as Tile
        tile.dice_queue.remove(activator_die)

    # Play the tile's lockout effect chain (if it has one)
    if effect_source is Tile:
        var tile := effect_source as Tile
        if tile.tile_resource.event_responses_v2.has(TileEvent.EventType.ON_LOCKOUT):
            var context: EffectContext = EffectContext.new()
            context.actor = actor
            context.effect_source = tile
            context.activator_die = activator_die
            await tile.tile_resource.event_responses_v2[TileEvent.EventType.ON_LOCKOUT].play(context, engine)

    # The die is consumed by the lockout — give it away or handle as game design requires.
    # Check your current lockout behavior in LockoutStatus.gd for the exact die fate.
```

**Action required:** Look at the existing `LockoutStatus.gd` to confirm what happens to
the die when a tile is locked (is it given to an enemy? Returned to the player? Destroyed?).
Port that behavior into the resolve method above.

---

### Step 12.4 — Create `LockoutTileHandler`

**New file:** `Source/Behavior/EffectsV2/EffectHandlers/TileStatus/lockout_tile_handler.gd`

```gdscript
class_name LockoutTileHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
    if not is_instance_valid(context.effect_source):
        return

    # Find the target tile (from context.targets, set by a preceding TARGETING entry)
    for target in context.targets:
        if target is Tile:
            engine.add_modifier(LockoutModifier.new(target as Tile))
```

Register it in `effect_registry.gd`:
```gdscript
_register(EffectEnums.Category.TILE_STATUS, EffectEnums.TileStatusSubtype.LOCKOUT_TILE, LockoutTileHandler.new())
```

---

### Step 12.5 — Migrate Lockout Tiles and Delete Old Code

For each tile or enemy action that applies a lockout:
1. Open the tile/enemy resource.
2. Replace the old lockout effect with `EffectData` entries:
   - `category = TARGETING, subtype = TARGET_RANDOM_TILE` (or whatever targeting applies)
   - `category = TILE_STATUS, subtype = LOCKOUT_TILE`
3. Test: activate the tile that causes lockout, then try to activate the locked tile —
   it should NOT fire, and the lockout chain should play instead.
4. Confirm the lockout expires at turn start (temporary modifier cleared).

Once confirmed working:
- Delete `Source/Content/Effects/TileStatusEffects/lockout_target_tile_effect.gd`
- Delete `Source/Systems/Game/TileGrid/GridStatusEffects/LockoutStatus/lockout_status.gd`
- Delete `Source/Systems/Game/TileGrid/GridStatusEffects/grid_status_effect.gd` (if now unused)

### Done when
- Locking a tile prevents its activation for the turn.
- The lockout chain plays and the die is handled correctly.
- No old `LockoutStatus` nodes remain.
- `GridStatusEffect` base class is deleted (or empty and pending deletion in Block 17).

### Watch out for
- The `event.canceled = true` in `LockoutModifier.on_before_event()` means the engine
  skips `TileActivationEvent.resolve()` entirely. That's why `LockoutEffectEvent` must
  do the die removal from the visual queue itself — `TileActivationEvent` never got there.
- If a tile can have both Lockout AND Amplifier modifiers at the same time, priority order
  matters. `LockoutModifier` has priority 0 (runs first). If it cancels the event,
  `AmplifierModifier` (priority 20) never sees it — this is correct behavior.

---

## Block 13 — Migrate More Tiles (~2 hrs, split into two sessions)

**Goal:** All common tile types migrated to `EffectChainV2`.

*(Corresponds to original Block 10.)*

### Strategy — process in this order (easiest to hardest):

1. **Simple damage tiles** — `TARGET_ENEMIES + DAMAGE` (you already did one in Block 8)
2. **Simple shield/heal tiles** — `TARGET_PLAYER + SHIELD` or `HEAL`
3. **Tiles with die value inheritance** — same as above but `inherit_die_amount = true`
4. **Tiles with conditionals** — use `ConditionalEffectData`
5. **Tiles with visual effects** — add `VISUAL` `EffectData` entries
6. **Tiles with tile control** — `TILE_CONTROL` subtypes

### For each tile:
1. Open the `.tres` tile resource in the Godot inspector.
2. Read its current `effect_chain.effects` array to understand what it does.
3. Create equivalent `EffectData` resources.
4. Create an `EffectChainV2` resource and assign the `EffectData` entries to it.
5. Assign the `EffectChainV2` to `effect_chain_v2` on the tile resource.
6. Test the tile in-game via `TileActivationEvent`.
7. Once confirmed working, clear or leave `effect_chain` as a backup — it will be
   deleted in Block 17.

### Track your progress with a checklist:
Open `Source/Content/Tiles/TileResources/` and list every tile. Check off each one
as you migrate it.

### Done when
All tiles in your combat/scenario scenes have a working `effect_chain_v2`.

---

## Block 14 — Migrate Enemy Actions (~1 hr)

**Goal:** Enemies use `EffectChainV2` for their attacks and actions.

*(Corresponds to original Block 11.)*

### Tasks

1. Read your current enemy action scripts — wherever enemies call `effect_chain.play()`.
2. Add `effect_chain_v2: EffectChainV2` to your `EnemyActionResource` (or equivalent).
3. Update enemy action execution:
   ```gdscript
   # Build context — the enemy is the actor, not the player
   var context: EffectContext = EffectContext.new()
   context.actor = self  # the enemy ship node
   context.effect_source = self
   context.activator_die = received_die  # the die the player gave them

   if action_resource.effect_chain_v2 and scenario_engine:
       await action_resource.effect_chain_v2.play(context, scenario_engine)
       await scenario_engine.process_event_queue()  # wait for all events to resolve
   elif action_resource.effect_chain:
       # legacy fallback
       await action_resource.effect_chain.play(effect_variables)
   ```

   Note: enemy actions call `process_event_queue()` explicitly and `await` it, unlike tiles
   which use the auto-processing path. This is because enemy turns are sequential and
   orchestrated differently — the enemy manager drives them one at a time.

4. Author `EffectChainV2` resources for each enemy action type. A typical "attack for 3":
   ```
   effects[0]: category=TARGETING,        subtype=TARGET_PLAYER
   effects[1]: category=ATTRIBUTE_CHANGE, subtype=DAMAGE, amount=3
   ```

5. Test each enemy type in combat. Verify the player takes correct damage and that modifiers
   affecting incoming damage (e.g., "reduce enemy damage by 1") are applied correctly via
   the engine's modifier hooks.

### Done when
All enemies use v2 chains. Combat plays through a full encounter without errors.

---

## Block 15 — Implement Remaining Handlers (~1 hr, possibly 2)

**Goal:** All stub handlers replaced with real implementations.

*(Corresponds to original Block 12.)*

Work through every stub handler created in Block 7. For each one, look at the corresponding
old `Effect` subclass in `Source/Content/Effects/` and port its logic into the handler +
event pattern.

**Quick reference — old Effect → new Handler:**

| Old Effect | New Handler |
|---|---|
| `AmountMultiplierEffect` | Temporary `Modifier` registered and removed within the chain |
| `AddRepetitionsEffect` | `AddRepetitionsHandler` → increment `context.repetitions` |
| `RerollActivatorDieEffect` | `RerollActivatorHandler` → `context.activator_die.reroll()` |
| `ChangeActivatorValueEffect` | `ChangeActivatorValueHandler` |
| `GiveAwayDiceEffect` | `GiveDieAwayHandler` |
| `DestroySourceEffect` | `DestroySourceHandler` → `context.effect_source.queue_free()` |
| `JumpEffect` | `JumpHandler` → enqueue a `JumpEvent` |
| `PlaySoundEffect` | `PlaySoundHandler` → `Events.play_sound.emit(data.sound_resource)` |
| `WaitForMillisecondsEffect` | `WaitHandler` → `await get_tree().create_timer(data.amount / 1000.0).timeout` |
| `MoveTileWithOffset` | `MoveTileWithOffsetHandler` |
| `AttackTargetTweenEffect` | `AttackTweenHandler` → tween `effect_source` toward `targets[0]` |
| `SpawnParticleExplosion` | `SpawnParticlesHandler` |

### Done when
No stub handlers remain. All effect types produce correct behavior in-game.

---

## Block 16 — Migrate `handle_tile_event()` to V2 (~1 hr)

**Goal:** Event-driven tile responses (ON_TURN_START, ON_TILE_PUSHED, etc.) use
`EffectChainV2` instead of the old `EffectChain` path.

Currently, `Tile._connect_tile_event_signals()` connects to global events and calls
`handle_tile_event()`, which runs `tile_resource.event_responses[event_check].play(effect_variables)`.
This needs to use `event_responses_v2` and the engine instead.

---

### Step 16.1 — Update `handle_tile_event()`

**File:** `Source/Content/Tiles/tile.gd`

```gdscript
func handle_tile_event(tile: Tile, event: TileEvent.EventType) -> void:
    for event_check: TileEvent in tile_resource.event_responses_v2.keys():
        if event_check.event == event:
            if (tile == self) or (not event_check.listen_only_for_self):
                if scenario_engine:
                    var context: EffectContext = EffectContext.new()
                    context.actor = Globals.player
                    context.effect_source = self
                    await tile_resource.event_responses_v2[event_check].play(context, scenario_engine)
                    # Don't call process_event_queue() here — the auto-processing 
                    # in queue_event() handles it. The outer await on play() waits
                    # for handler dispatch, not event resolution.
                else:
                    # Legacy fallback
                    var effect_variables: EffectVariables = _generate_effect_variables()
                    await tile_resource.event_responses[event_check].play(effect_variables)
```

---

### Step 16.2 — Author V2 Event Responses

For each tile that has entries in `event_responses`, create equivalent `EffectChainV2`
resources and assign them to `event_responses_v2` in the inspector. Test each event
trigger in-game.

### Done when
All tiles with event responses use the v2 path. The old `event_responses` dictionary
is empty or unused, ready for deletion in Block 17.

---

## Block 17 — Delete Legacy Code (~1 hr)

**Goal:** Remove all old `Effect`/`EffectChain` code. No dead code remains.

*(Corresponds to original Block 13, expanded to include the activation manager cleanup.)*

---

### Step 17.1 — Confirm Everything Is Migrated

Before deleting anything:
1. Every `TileResource` has `effect_chain_v2` set (or is a non-combat tile with no effects).
2. Every `TileResource` with event responses has `event_responses_v2` set.
3. Every enemy action resource has `effect_chain_v2` set.
4. No `GridStatusEffect` subclasses remain (Amplifier and Lockout replaced in Blocks 11-12).

---

### Step 17.2 — Search for Remaining Legacy Usages

Search the project for these patterns and eliminate each one:
```
effect_chain.play
EffectVariables.new()
calculate_final_amount_with_global_modifiers
Effect.play(
await effect.play(
_generate_effect_variables
can_activate(
dice_activation_queue
activation_queue_manager
```

---

### Step 17.3 — Clean Up `tile.gd`

Remove from `tile.gd`:
- `_generate_effect_variables()` method (was used for v1 chains)
- `activate()` method (was used for v1 path; all activation is now via `TileActivationEvent`)
- The `elif tile_resource.effect_chain:` branch in `handle_tile_event()` (v1 fallback)
- The `elif Globals.activation_queue_manager:` fallback in `_on_die_accepted()` (already removed in Block 9 — double-check)
- Any remaining reference to `EffectVariables`

---

### Step 17.4 — Clean Up `tile_resource.gd`

Remove:
```gdscript
@export var effect_chain: EffectChain
@export var event_responses: Dictionary[TileEvent, EffectChain]
```

---

### Step 17.5 — Delete Effect Files

Delete these files and directories entirely:
- `Source/Content/Effects/effect.gd`
- `Source/Content/Effects/effect_chain.gd`
- `Source/Content/Effects/effect_variables.gd`
- All files in `Source/Content/Effects/AttributeChangers/`
- All files in `Source/Content/Effects/Targeters/`
- All files in `Source/Content/Effects/AmountModifiers/`
- All files in `Source/Content/Effects/Conditionals/`
- All files in `Source/Content/Effects/Repetitions/`
- All remaining files in `Source/Content/Effects/TileStatusEffects/`
- Any remaining `GridStatusEffect` files

**Run the game after each deletion.** Fix errors before continuing. Do not batch-delete.

---

### Step 17.6 — Final Globals Cleanup

Remove from `globals.gd` (if not already done in earlier blocks):
- `var modifier_manager: GlobalModifierManager`
- `var activation_queue_manager: ActivationQueueManager`

### Done when
`Source/Content/Effects/` is empty or deleted. No references to `EffectChain`,
`EffectVariables`, `DamageEffect`, `GridStatusEffect`, or `ActivationQueueManager`
remain anywhere.

---

## Block 18 — Debug Mode & Polish (~1 hr)

**Goal:** Confidence the whole system is correct. A debug mode for tracing event flow.

*(Corresponds to original Block 15.)*

---

### Step 18.1 — Add Debug Logging to `ScenarioEngine`

**File:** `Source/Systems/Game/ScenarioEngine/scenario_engine.gd`

Add a `debug_log` flag and instrument the processing loop:

```gdscript
var debug_log: bool = false

func process_event_queue() -> void:
    began_processing_queue.emit()
    currently_processing_queue = true

    while not event_queue.is_empty():
        var event: EffectEvent = event_queue.pop_front()

        if debug_log:
            print("[ScenarioEngine] Processing: %s" % event.get_class())

        for mod in modifiers:
            await mod.on_before_event(event, self)

        if event.canceled:
            if debug_log:
                print("[ScenarioEngine] Event CANCELED by modifier.")
            continue

        if debug_log:
            print("[ScenarioEngine] Resolving...")

        await event.resolve(self)
        event_resolved.emit(event)

        for mod in modifiers:
            await mod.on_after_event(event, self)

    currently_processing_queue = false
    finished_processing_queue.emit()
```

---

### Step 18.2 — Play Through Full Encounters with Logging On

Set `engine.debug_log = true` in your combat scene setup. Play through 3–5 full combat
encounters. Watch the output and confirm:
- `TileActivationEvent` appears first when a die is placed.
- Effect events (`DamageEvent`, `ShieldEvent`, etc.) follow in the correct order.
- Modifier adjustments (if debug-logging amounts) show correct before/after values.
- No unexpected cancellations or duplicate events.

---

### Step 18.3 — Edge Case Testing

1. **Enemy dies mid-queue.** If a `DamageEvent` targets an enemy that was killed by an
   earlier event in the same queue, check `is_instance_valid(target)` guards in each
   event's `resolve()`.

2. **Tile destroyed during its own chain.** If `DestroySourceHandler` frees a tile that
   has more events pending in the queue for it, those events should guard with
   `is_instance_valid(effect_source)` at the start of `resolve()`.

3. **0 targets.** All attribute-change events (`DamageEvent`, `ShieldEvent`, `HealEvent`)
   should have early-return guards for empty target arrays.

4. **Multiple dice placed rapidly.** Drop three dice on three different tiles in quick
   succession. All three `TileActivationEvent`s should queue up and resolve in order.

5. **Tile with 1 use remaining.** Place a die — it activates. Place a second die
   immediately — it should see `uses_remaining == 0`, fail `clears_activation_criteria`,
   return the die to the player, and not activate.

### Done when
- Debug log shows a clean, expected event sequence through a full combat.
- No crashes from invalid node references mid-queue.
- Multiple rapid die placements resolve correctly in order.
- You've played a complete run of the game without seeing legacy effect code in the output.

---

## Summary: Files Created / Modified / Deleted

### New Files
- `Source/Systems/Game/ScenarioEngine/Events/tile_activation_event.gd`
- `Source/Systems/Game/ScenarioEngine/Events/lockout_effect_event.gd`
- `Source/Systems/Game/ScenarioEngine/Modifiers/TileStatus/amplifier_modifier.gd`
- `Source/Systems/Game/ScenarioEngine/Modifiers/TileStatus/lockout_modifier.gd`
- `Source/Behavior/EffectsV2/EffectHandlers/TileStatus/add_amplifier_handler.gd`
- `Source/Behavior/EffectsV2/EffectHandlers/TileStatus/lockout_tile_handler.gd`

### Modified Files
- `Source/Systems/Game/ScenarioEngine/scenario_engine.gd` — fix break→continue, auto-processing, debug log, clear_temporary_modifiers
- `Source/Systems/Game/ScenarioEngine/Modifiers/modifier.gd` — add `is_temporary`
- `Source/Content/Tiles/tile.gd` — `_on_die_accepted`, remove `can_activate`, remove static queue, remove `activate`, update `handle_tile_event`
- `Source/Content/Tiles/tile_resource.gd` — remove legacy `effect_chain` and `event_responses` exports
- `Source/Systems/Autoloads/globals.gd` — remove `activation_queue_manager`, `modifier_manager`
- `Source/Behavior/EffectsV2/effect_enums.gd` — add `TILE_STATUS` category and subtypes
- `Source/Systems/Autoloads/effect_registry.gd` — register new handlers

### Deleted Files
- `Source/Systems/Game/TileGrid/ActivationQueueManager/activation_queue_manager.gd`
- `Source/Systems/Game/TileGrid/ActivationQueueManager/activation_queue_manager.tscn`
- `Source/Content/Effects/` — entire directory
- `Source/Systems/Game/TileGrid/GridStatusEffects/` — entire directory (after Blocks 11-12)
- `Source/Systems/Game/GlobalModifierManager/` — entire directory (Block 10)

---

## Non-Obvious Pitfalls for This Block Set

1. **`queue_event()` auto-processing is fire-and-forget.** Don't add `await` to the
   `process_event_queue()` call inside `queue_event()`. It starts the coroutine running
   and returns immediately. The re-entrancy guard (`currently_processing_queue`) ensures
   it won't double-start.

2. **Die visual queue removal happens in `TileActivationEvent.resolve()`, not before.**
   When the die is dropped, it goes into the visual `dice_queue` immediately
   (`_on_die_accepted` → `dice_queue.add()`). It stays there, stacked visually, until the
   `TileActivationEvent` runs. At the start of `resolve()`, before the tween, call
   `tile.dice_queue.remove(activator_die)`. This is correct and produces the expected
   visual behavior: dice stack while waiting, then fly to center when their turn comes.

3. **Canceled `TileActivationEvent` leaves the die in the visual queue.**
   When `LockoutModifier` cancels a `TileActivationEvent`, the engine skips `resolve()`,
   so the die is never removed from the visual queue. `LockoutEffectEvent.resolve()` must
   call `tile.dice_queue.remove(activator_die)` itself.

4. **`TileActivationEvent.effect_source` vs `TileActivationEvent.tile`.**
   The `EffectEvent` base class likely has an `effect_source` field. Set both:
   `event.effect_source = self` AND `event.tile = self` in `_on_die_accepted()`. Modifiers
   check `event.effect_source`; lockout and amplifier logic checks `event.effect_source`.
   Having both makes the event compatible with generic modifier patterns.

5. **`clears_activation_criteria` still shows an error popup on failure.**
   The method emits `Events.error_text_popup` when a check fails. This behavior is
   preserved — you want the player to see why their tile didn't activate. No change needed.

6. **`handle_tile_event` and `process_event_queue`.** When event-driven tile responses
   (ON_TURN_START, etc.) play a v2 chain, the handlers enqueue events into the engine.
   The auto-processing in `queue_event()` will start processing if the engine is idle.
   If the engine is already processing (e.g., resolving a player turn's tile chain), the
   new events simply join the queue and are resolved by the running loop. This is the
   correct behavior — do not add a separate `process_event_queue()` call after
   `handle_tile_event`.


Cleanup / Step #19:
- Move PauseMenu under UI, not under Main
- Phase 1: Architectural Decoupling

The goal is to move away from the "junk drawer" Events.gd and implement a domain-specific bus.  

    Create UIEvents.gd Autoload:

        Define a new script and register it as an Autoload in Project Settings.

        Migrate the error_text_popup signal from Events.gd to UIEvents.gd.  

        Benefit: Restricts UI logic to a dedicated namespace, making the "Events" bus cleaner.  

    Update Signal Calls:

        Search and replace all instances of Events.error_text_popup.emit() with UIEvents.error_text_popup.emit().

Phase 2: Script Logic Refactor (error_popup_manager.gd)

Simplify the internal state and fix the timing issue where popups are misaligned.  

    Simplify Storage:

        Remove var _current_popups: Array[ErrorTextPopup].  

        Replace it with var _current_popup: ErrorTextPopup to reflect that only one exists at a time.  

    Fix Layout Timing:

        Insert await get_tree().process_frame immediately after add_child(error_text).  

        This ensures error_text.size is calculated before setting the global_position.  

    Modernize the API:

        Rename the internal _create_error_popup to a public-facing show_error.

        Ensure it still connects to UIEvents.error_text_popup in _ready().

Instead of doing math like Vector2(-popup.size.x / 2, -popup.size.y) in the manager, try to set up your ErrorTextPopup scene with its Pivot Offset centered and use Top-Center anchors. If you do that, you can just set popup.global_position = global_pos and let Godot's UI system handle the centering automatically.