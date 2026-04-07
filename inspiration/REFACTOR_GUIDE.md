# StellaRoller — ScenarioEngine Refactor Guide
## Explicit 1-Hour Work Block Breakdown

---

### Architecture in One Paragraph

Every scenario (combat, shop, event) spins up a **ScenarioEngine** node.
Tiles and enemies queue their work as typed **EffectEvents** into the engine.
Before each event resolves, **Modifiers** (player upgrades, passives, statuses)
get a chance to adjust values or cancel. After resolution, modifiers can enqueue
follow-up events. Effects are authored as **EffectData** resources in the inspector,
assembled into **EffectChainV2** resources, and converted to events by stateless
**EffectHandler** objects looked up from a central **EffectRegistry**.

**Old flow:**   Tile → EffectVariables → EffectChain → Effect.play() → mutates state directly
**New flow:**   Tile → EffectContext → EffectChainV2 → Handlers → Events → ScenarioEngine → Modifiers → resolve()

---

### Reference Files (in `inspiration/`)

| File | What it shows |
|---|---|
| `Core/scenario_engine.gd` | The engine itself — queue, modifiers, process loop |
| `Core/effect_event.gd` | Base event class |
| `Core/damage_event.gd` | Full worked damage resolution |
| `Core/shield_event.gd` | Shield resolution (simple) |
| `Core/heal_event.gd` | Heal resolution (simple) |
| `Core/modifier.gd` | Modifier base class + priority guide |
| `Data/effect_enums.gd` | ALL category + subtype enums |
| `Data/effect_data.gd` | EffectData resource — all exports annotated |
| `Data/conditional_effect_data.gd` | Branching effects (if/else chains) |
| `Data/effect_context.gd` | Replaces EffectVariables |
| `Data/effect_chain_v2.gd` | The chain that calls handlers |
| `Data/effect_registry.gd` | Maps (category, subtype) → handler |
| `Data/effect_handler.gd` | Handler base class |
| `Handlers/` | 8 worked handler implementations |
| `Modifiers/double_damage_modifier.gd` | before-hook modifier example |
| `Modifiers/shield_on_damage_modifier.gd` | after-hook modifier example |
| `Examples/tile_v2_example.gd` | How tile.gd changes |
| `Examples/enemy_v2_example.gd` | How enemies use the same system |
| `Examples/worked_example_damage_tile.md` | Full end-to-end authoring walkthrough |

---

## Block 1 — Orient & Read (~1 hr)

**Goal:** Be able to describe the old data flow and the new one without notes.

### Tasks

1. Read these files from top to bottom, in this order:
   - `Source/Content/Effects/effect.gd`
   - `Source/Content/Effects/effect_variables.gd`
   - `Source/Content/Effects/effect_chain.gd`
   - `Source/Content/Effects/AttributeChangers/damage_effect.gd`
   - `Source/Content/Tiles/tile.gd` — focus on `activate()` and `handle_tile_event()`
   - `Source/Systems/Game/GlobalModifierManager/global_modifier_manager.gd`
   - `Source/Systems/Game/GlobalModifierManager/global_modifier.gd`

2. Read ALL the inspiration files (takes ~20 min). Pay close attention to:
   - How `DealDamageHandler` → `DamageEvent` → `ScenarioEngine` replace `DamageEffect.play()`
   - How `DoubleDamageModifier` replaces `GlobalModifierManager.apply_modifiers_to_amount()`
   - How `EffectContext` replaces `EffectVariables`

3. Sketch on paper or a whiteboard:
   - The current flow: `Tile.activate()` → `EffectVariables` → `EffectChain` → `DamageEffect.play()` → `health.take_damage()`
   - The new flow: `Tile.activate()` → `EffectContext` → `EffectChainV2` → `DealDamageHandler` → `DamageEvent` → `ScenarioEngine.process_events()` → modifier hooks → `DamageEvent.resolve()` → `health.take_damage()`

4. Identify the 3 most common tile types in your game by opening
   `Source/Content/Tiles/TileResources/` and scanning the effect chains.
   These will be your first migration targets in later blocks.

### Done when
You can describe (aloud or in writing) exactly what `DamageEffect.play()` does
and exactly what replaces it in the new system.

---

## Block 2 — Scaffold ScenarioEngine (~1 hr)

**Goal:** A working ScenarioEngine node in your project that can enqueue and process events.

### Tasks

1. Create `Source/Combat/scenario_engine.gd` by copying from `inspiration/Core/scenario_engine.gd`.
   - No changes needed yet. Copy it verbatim.

2. Create `Source/Combat/effect_event.gd` by copying from `inspiration/Core/effect_event.gd`.

3. Create `Source/Combat/modifier.gd` by copying from `inspiration/Core/modifier.gd`.

4. Open the Godot editor. Create a temporary test scene (call it `ScenarioEngineTest.tscn`):
   - Root node: `Node`
   - Child: Add a `ScenarioEngine` node (attach `scenario_engine.gd`)
   - Attach a test script to the root:

   ```gdscript
   extends Node

   @onready var engine: ScenarioEngine = $ScenarioEngine

   func _ready() -> void:
       # Make a dummy event that just prints when it resolves.
       var test_event := EffectEvent.new()
       test_event.resolve = func(_e): print("Test event resolved!")  # lambda override

       engine.event_resolved.connect(func(event): print("Signal fired!"))
       engine.enqueue_event(test_event)
       await engine.process_events()
       print("process_events() returned — queue is empty.")
   ```

5. Run the scene. You should see:
   ```
   Test event resolved!
   Signal fired!
   process_events() returned — queue is empty.
   ```

6. Add a second event to the queue before calling `process_events()` and verify both resolve in order.

### Done when
You can enqueue two events and watch them both resolve in order via the console.

### Watch out for
- `ScenarioEngine` is a **Node**, not a Resource — it needs to be in the scene tree.
- The lambda override trick for `resolve` is just for testing. Real events will override in their class.

---

## Block 3 — Define DamageEvent + Test Modifiers (~1 hr)

**Goal:** A real DamageEvent that applies damage, with modifiers that affect the amount.

### Tasks

1. Create `Source/Combat/damage_event.gd` from `inspiration/Core/damage_event.gd`.
   - The particle `preload` UIDs are already correct for your project.

2. Create `Source/Combat/shield_event.gd` from `inspiration/Core/shield_event.gd`.

3. Create `Source/Combat/heal_event.gd` from `inspiration/Core/heal_event.gd`.

4. Create two test modifiers (you'll delete these later, but they validate the pipeline):
   - `Source/Combat/Modifiers/double_damage_modifier.gd` from `inspiration/Modifiers/double_damage_modifier.gd`
   - `Source/Combat/Modifiers/shield_on_damage_modifier.gd` from `inspiration/Modifiers/shield_on_damage_modifier.gd`

5. Update your test scene's script:

   ```gdscript
   func _ready() -> void:
       # Register test modifiers.
       engine.add_modifier(DoubleDamageModifier.new())
       engine.add_modifier(ShieldOnDamageModifier.new(2))  # +2 shields

       # Create a fake DamageEvent (target = player for easy testing).
       var dmg := DamageEvent.new()
       dmg.actor   = Globals.player       # or any valid node
       dmg.targets = [Globals.player]     # targeting self, fine for testing
       dmg.amount  = 5

       engine.event_resolved.connect(func(event):
           if event is DamageEvent:
               print("Damage resolved. Final amount was: ", event.amount)
               # Should print 10 (5 * 2 from DoubleDamageModifier)
           elif event is ShieldEvent:
               print("Shield follow-up resolved. Amount: ", event.amount)
               # Should print 2 (from ShieldOnDamageModifier)
       )

       engine.enqueue_event(dmg)
       await engine.process_events()
   ```

6. Run and verify the output shows doubled damage and a follow-up shield event.

### Done when
- DamageEvent prints `amount = 10` (doubled from 5).
- ShieldEvent follow-up fires with `amount = 2`.
- No errors in the Output panel.

### Watch out for
- `Globals.player` may not exist in a test scene. Stub it with any Node2D and assign it manually if needed.
- If `DoubleDamageModifier` checks `event.actor == Globals.player` and actor is null, the modifier won't fire. Make sure `dmg.actor` is set correctly.

---

## Block 4 — Define EffectEnums, EffectData, EffectContext (~1 hr)

**Goal:** Author-facing data classes that show up cleanly in the Godot inspector.

### Tasks

1. Create the data directory: `Source/Content/EffectsV2/`

2. Create `Source/Content/EffectsV2/effect_enums.gd` from `inspiration/Data/effect_enums.gd`.
   (No changes needed — copy verbatim.)

3. Create `Source/Content/EffectsV2/effect_data.gd` from `inspiration/Data/effect_data.gd`.

4. Create `Source/Content/EffectsV2/conditional_effect_data.gd` from `inspiration/Data/conditional_effect_data.gd`.

5. Create `Source/Content/EffectsV2/effect_context.gd` from `inspiration/Data/effect_context.gd`.

6. **Verify in the editor:**
   - Right-click in FileSystem → New Resource → type `EffectData` → create it.
   - Open it. You should see `category` and `subtype` dropdowns/fields.
   - Create a second one as `ConditionalEffectData`. You should see `if_true_effects`
     and `if_false_effects` arrays alongside the base fields.
   - Delete these test resources when done.

7. **Check enum values:** Open `effect_enums.gd` and note the integer values for your most-used subtypes. Write them on a sticky note or keep the file open. You'll be typing these numbers into inspectors frequently.

### Done when
EffectData and ConditionalEffectData appear in the inspector with all fields visible.

### Watch out for
- The `category` field exports as an enum dropdown automatically (Godot 4 does this). `subtype` will show as an integer — that's expected until you write an EditorInspectorPlugin.
- If `EffectEnums` doesn't appear as a class, make sure the file has `class_name EffectEnums`.

---

## Block 5 — EffectHandler, EffectRegistry, EffectChainV2 (~1 hr)

**Goal:** The chain execution and registry infrastructure, verified with stub handlers.

### Tasks

1. Create `Source/Content/EffectsV2/effect_handler.gd` from `inspiration/Data/effect_handler.gd`.

2. Create `Source/Content/EffectsV2/effect_chain_v2.gd` from `inspiration/Data/effect_chain_v2.gd`.

3. Create `Source/Content/EffectsV2/effect_registry.gd` from `inspiration/Data/effect_registry.gd`.
   - **Important:** The registry's `_register_all()` lists handler class names that don't exist yet.
   - For now, **comment out every `_register()` call except the ones for handlers you've already written** (none yet — you'll uncomment as you add handlers in Block 6+).
   - Leave the structure in place so you know what to fill in.

4. **Add EffectRegistry as an Autoload:**
   - Project → Project Settings → Autoloads
   - Add: `Source/Content/EffectsV2/effect_registry.gd` with name `EffectRegistry`

5. **Write two stub handlers** to test the chain plumbing:

   ```gdscript
   # Source/Content/EffectsV2/Handlers/stub_print_handler.gd
   class_name StubPrintHandler
   extends EffectHandler

   func apply(data: EffectData, _context: EffectContext, _engine: ScenarioEngine) -> void:
       print("StubPrintHandler fired! data.amount = ", data.amount)
   ```

6. In `effect_registry.gd._register_all()`, temporarily add:
   ```gdscript
   _register(EffectEnums.Category.UTILITY, EffectEnums.UtilitySubtype.PRINT_DEBUG, StubPrintHandler.new())
   ```

7. In your test scene, create an EffectChainV2 with one EffectData entry
   (category=UTILITY, subtype=PRINT_DEBUG, amount=42) and call `chain.play(context, engine)`.

### Done when
Calling `chain.play()` on a chain with one PRINT_DEBUG entry prints the correct amount.

### Watch out for
- EffectRegistry must be an Autoload — EffectChainV2 calls `EffectRegistry.get_handler(...)` as a global.
- Double-check the autoload name is exactly `EffectRegistry` (capital R, no spaces).

---

## Block 6 — Core Handlers: Targeting + Damage/Shield/Heal (~1 hr)

**Goal:** The most commonly used handlers, ready for real tile use.

### Tasks

Create these handlers in `Source/Content/EffectsV2/Handlers/`:

1. `target_enemies_handler.gd` from `inspiration/Handlers/target_enemies_handler.gd`
2. `target_player_handler.gd` from `inspiration/Handlers/target_player_handler.gd`
3. `deal_damage_handler.gd` from `inspiration/Handlers/deal_damage_handler.gd`
4. `gain_shields_handler.gd` from `inspiration/Handlers/gain_shields_handler.gd`
5. `heal_handler.gd` from `inspiration/Handlers/heal_handler.gd`

6. Also create stub handlers for the remaining targeting subtypes
   (TARGET_RANDOM_ENEMY, TARGET_ALL_SHIPS, etc.) — you can copy the
   TargetEnemiesHandler pattern, just change the assignment in `apply()`.
   These stubs prevent the registry from erroring on unregistered subtypes.

7. **Uncomment the matching `_register()` lines** in `effect_registry.gd._register_all()`.

8. **End-to-end test** in your test scene:
   ```gdscript
   var context := EffectContext.new()
   context.actor = Globals.player
   context.effect_source = some_tile_node

   # Manually call the targeting handler to confirm it populates context.targets:
   var target_handler := TargetEnemiesHandler.new()
   var target_data := EffectData.new()
   target_data.category = EffectEnums.Category.TARGETING
   target_data.subtype  = EffectEnums.TargetingSubtype.TARGET_ENEMIES
   target_handler.apply(target_data, context, engine)
   print("Targets after targeting handler: ", context.targets)

   # Then manually call the damage handler:
   var dmg_handler := DealDamageHandler.new()
   var dmg_data := EffectData.new()
   dmg_data.category = EffectEnums.Category.ATTRIBUTE_CHANGE
   dmg_data.subtype  = EffectEnums.AttributeChangeSubtype.DAMAGE
   dmg_data.amount   = 3
   dmg_handler.apply(dmg_data, context, engine)
   print("Events in queue: ", engine.event_queue.size())  # Should be 1

   await engine.process_events()
   print("Done!")
   ```

### Done when
- `context.targets` is populated after the targeting handler.
- One DamageEvent is in the queue after the damage handler.
- `process_events()` resolves it and the target takes damage.

---

## Block 7 — ConditionalHandler + Non-Combat Handlers (~1 hr)

**Goal:** Branching logic and at least one non-combat scenario handler.

### Tasks

1. Create `Source/Content/EffectsV2/Handlers/conditional_handler.gd`
   from `inspiration/Handlers/conditional_handler.gd`.

2. Create `Source/Content/EffectsV2/Handlers/open_shop_handler.gd`
   from `inspiration/Handlers/open_shop_handler.gd`.
   - You'll need a corresponding `OpenShopEvent` class. Create
     `Source/Combat/Events/open_shop_event.gd` — see the inline definition
     in the open_shop_handler inspiration for what it should contain.

3. Uncomment the matching `_register()` lines in `effect_registry.gd`.

4. **Test a conditional** in your test scene:
   ```gdscript
   # Create a ConditionalEffectData that prints different messages
   # depending on whether the activator die value is odd.
   var cond_data := ConditionalEffectData.new()
   cond_data.category = EffectEnums.Category.CONDITIONAL
   cond_data.subtype  = EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD

   var true_step := EffectData.new()
   true_step.category = EffectEnums.Category.UTILITY
   true_step.subtype  = EffectEnums.UtilitySubtype.PRINT_DEBUG
   true_step.string_param = "Die was odd!"
   cond_data.if_true_effects = [true_step]

   var false_step := EffectData.new()
   false_step.category = EffectEnums.Category.UTILITY
   false_step.subtype  = EffectEnums.UtilitySubtype.PRINT_DEBUG
   false_step.string_param = "Die was even!"
   cond_data.if_false_effects = [false_step]

   var chain := EffectChainV2.new()
   chain.effects = [cond_data]

   var context := EffectContext.new()
   context.activator_die = my_die  # set die.value to 3 (odd)
   await chain.play(context, engine)
   await engine.process_events()
   # Should print "Die was odd!"
   ```

5. Also create stub handlers for the remaining unregistered subtypes
   (tile control, dice control, visual, etc.) to prevent registry errors
   as you start running the game with the new system active.
   Stubs just need to be empty `apply()` methods — they prevent crashes
   while you implement them one by one.

### Done when
- Conditional branches correctly for odd/even die values.
- OpenShopEvent resolves and calls `scenario_manager.open_shop()` without errors.
- No "no handler registered" errors in the Output panel for common subtypes.

---

## Block 8 — Wire One Tile to the New System (~1 hr)

**Goal:** The first real tile using EffectChainV2, running in the actual game.

**This is the most important milestone.** Everything before this was infrastructure.
This block proves the whole pipeline works end-to-end.

### Tasks

1. **Pick the simplest "deal damage to enemy" tile** in your game.
   A tile with just: target enemy → deal fixed damage. No conditionals, no specials.

2. **Add the new exports to `tile_resource.gd`:**
   ```gdscript
   @export var effect_chain_v2: EffectChainV2
   @export var event_responses_v2: Dictionary[TileEvent, EffectChainV2]
   ```

3. **Add ScenarioEngine wiring to `tile.gd`** (see `inspiration/Examples/tile_v2_example.gd`):
   ```gdscript
   var scenario_engine: ScenarioEngine = null

   func set_scenario_engine(engine: ScenarioEngine) -> void:
       scenario_engine = engine
   ```

4. **Update `tile.gd`'s `activate()` method** with the v2/v1 if/else fallback
   as shown in `inspiration/Examples/tile_v2_example.gd`.

5. **Author the EffectData resources and EffectChainV2** for your chosen tile
   (follow the `worked_example_damage_tile.md` guide step by step).

6. **Assign the new chain** to the tile resource in the inspector
   (`effect_chain_v2` field).

7. **Create ScenarioEngine in your combat scene** and inject it into tiles:
   ```gdscript
   # In your combat scene or CombatManager _ready():
   var engine := ScenarioEngine.new()
   engine.name = "ScenarioEngine"
   add_child(engine)

   # Inject into all tiles on the grid:
   for tile in Globals.tile_grid.get_all_tiles():
       tile.set_scenario_engine(engine)
   ```

8. **Run the game.** Place a die on your chosen tile. Verify:
   - The tile activates normally.
   - The enemy takes damage.
   - Any damage upgrades you have are applied (if you already registered modifiers).

### Done when
One tile works end-to-end through the new pipeline in a real game session.

### Watch out for
- If `scenario_engine` is null when `activate()` runs, the tile will silently
  fall through to the v1 path (that's intentional). Add a `print` to confirm
  which path is running during debugging.
- Make sure `add_child(engine)` runs BEFORE tiles are activated (i.e., before
  player turn starts). Put it in `_ready()` of the combat scene.
- The first time you inject the engine, some tiles may not have a `set_scenario_engine`
  method yet — add it to tile.gd before injecting.

---

## Block 9 — Remove GlobalModifierManager (~1 hr)

**Goal:** Replace the old modifier system entirely. This block makes the new Modifier
system do real work.

### Tasks

1. **Audit `GlobalModifierManager`:** Read `global_modifier_manager.gd` carefully.
   List every modifier type that's been registered anywhere in your codebase
   (search for `Globals.modifier_manager.add_modifier`).

2. **For each modifier type found:**
   - Create a corresponding `Modifier` subclass in `Source/Combat/Modifiers/`.
   - Model it on the inspiration examples (`DoubleDamageModifier`, `ShieldOnDamageModifier`).

3. **Register modifiers with ScenarioEngine** instead of GlobalModifierManager:
   ```gdscript
   # OLD (remove this):
   Globals.modifier_manager.add_modifier(GlobalModifier.new(...))

   # NEW (replace with):
   scenario_engine.add_modifier(MyNewModifier.new())
   ```
   Wherever modifiers were being registered, pass them to the ScenarioEngine instead.

4. **Remove calls to `calculate_final_amount_with_global_modifiers()`:**
   Search the entire project for this method name.
   - In `DamageEffect.play()` (and `HealEffect`, `ShieldEffect`): this call is
     replaced by modifier before-hooks on the engine. Delete these calls.
   - In any other effects: same — delete and let the engine handle it.

5. **Delete GlobalModifierManager from the project:**
   - Remove it from Autoloads (Project Settings → Autoloads).
   - Delete `global_modifier_manager.gd` and `global_modifier.gd`.
   - Remove `var modifier_manager: GlobalModifierManager` from `globals.gd`.

6. **Run the game.** Verify:
   - Damage amounts are still correct.
   - Upgrades that affect damage/shields/heal still work.
   - No "modifier_manager" references remain (search the project).

### Done when
No references to `GlobalModifierManager` or `modifier_manager` remain in the codebase.
Damage modifiers work correctly through the new Modifier system.

### Watch out for
- If modifiers were registered in many places, make a list first and work through
  it systematically — don't search-and-replace blindly.
- Temporary modifiers (ones that expire after one turn) need to be managed carefully.
  In the old system they were stored globally. In the new system, call
  `engine.remove_modifier(mod)` at the right moment (e.g., on turn end signal).

---

## Block 10 — Migrate More Tiles (~2 hrs, split into two sessions)

**Goal:** All common tile types migrated to EffectChainV2.

This is the grind phase. Work systematically through your tile library.

### Strategy

Process tiles in this order (easiest to hardest):
1. **Simple damage tiles** — TARGET_ENEMIES + DAMAGE (you already did one)
2. **Simple shield/heal tiles** — TARGET_PLAYER + SHIELD or HEAL
3. **Tiles with die inheritance** — same as above but `inherit_die_amount = true`
4. **Tiles with conditionals** — use ConditionalEffectData
5. **Tiles with visual effects** — add VISUAL EffectData entries
6. **Tiles with tile control** — TILE_CONTROL subtypes

### For each tile:
1. Open the `.tres` tile resource.
2. Read its current `effect_chain.effects` array to understand what it does.
3. Create equivalent EffectData resources.
4. Create an EffectChainV2 resource.
5. Assign it to `effect_chain_v2`.
6. Test the tile in-game.
7. Once confirmed working, you can optionally clear `effect_chain` (or leave it as backup).

### Track progress with a checklist
Open `Source/Content/Tiles/TileResources/` and list every tile:
- [ ] basic_cannon.tres
- [ ] (etc.)

Check off each one as you migrate it.

### Done when
All tiles in your combat/scenario scenes have a v2 chain and work correctly.

---

## Block 11 — Migrate Enemy Actions (~1 hr)

**Goal:** Enemies use EffectChainV2 for their attacks and actions.

### Tasks

1. Read your current enemy action scripts (wherever enemies call `effect_chain.play()`).

2. Add `effect_chain_v2: EffectChainV2` to your EnemyActionResource (or equivalent).

3. Update the enemy's action execution to use the pattern in
   `inspiration/Examples/enemy_v2_example.gd`.
   - The enemy's `actor` in EffectContext is the enemy ship node.
   - Enemies target the player via `TARGET_PLAYER` EffectData.
   - Everything else is identical to tiles.

4. Author EffectChainV2 resources for each enemy action type.
   A typical "enemy attacks for 3 damage" chain:
   ```
   effects[0]: category=TARGETING,        subtype=TARGET_PLAYER
   effects[1]: category=VISUAL,           subtype=ANIMATE_DIE_TO_TILE  (optional)
   effects[2]: category=ATTRIBUTE_CHANGE, subtype=DAMAGE, amount=3
   ```

5. Test each enemy type in combat. Verify:
   - Player takes correct damage.
   - `Events.player_attacked_ship` is still emitted (it's in DamageEvent.resolve()).
   - Modifiers that affect incoming damage work (e.g., a "reduce enemy damage by 1" modifier).

### Done when
All enemies use v2 chains. Combat plays through a full encounter without errors.

---

## Block 12 — Implement Remaining Handlers (~1 hr, possibly 2)

**Goal:** All stubs replaced with real implementations.

### Tasks

Work through the stub handlers created in Block 7. For each one, look at the
corresponding old `Effect` subclass in `Source/Content/Effects/` and port its logic
into the new handler + event pattern.

**Quick reference — old Effect → new Handler:**

| Old Effect | New Handler |
|---|---|
| `AmountMultiplierEffect` | Add flat `AmountMultiplierModifier` OR make it an engine modifier |
| `AddRepetitionsEffect` | `AddRepetitionsHandler` → increment `context.repetitions` |
| `RerollActivatorDieEffect` | `RerollActivatorHandler` → `context.activator_die.reroll()` |
| `ChangeActivatorValueEffect` | `ChangeActivatorValueHandler` |
| `GiveAwayDiceEffect` | `GiveDieAwayHandler` |
| `DestroySourceEffect` | `DestroySourceHandler` → `context.effect_source.queue_free()` |
| `JumpEffect` | `JumpHandler` → enqueue a JumpEvent |
| `PlaySoundEffect` | `PlaySoundHandler` → call `Events.play_sound.emit(data.sound_resource)` |
| `WaitForMillisecondsEffect` | `WaitHandler` → `await get_tree().create_timer(data.amount / 1000.0).timeout` |
| `MoveTileWithOffset` | `MoveTileWithOffsetHandler` |
| `AttackTargetTweenEffect` | `AttackTweenHandler` → tween effect_source toward targets[0] |
| `SpawnParticleExplosion` | `SpawnParticlesHandler` |

**For AmountMultiplierEffect specifically:**
The old system added a Callable to `effect_variables.amount_modifiers`.
In the new system, this is a Modifier on the ScenarioEngine.
If the multiplier is temporary (just for this chain), you have two options:
- Enqueue a special event that adjusts the next event's amount (complex).
- Register a temporary Modifier, let the next event use it, then immediately remove it (simpler).
Prefer the simpler approach for now.

### Done when
No stub handlers remain. All effect types are implemented.

---

## Block 13 — Delete Legacy Code (~1 hr)

**Goal:** Remove all old Effect/EffectChain code. Leave no dead code behind.

### Tasks

1. **Confirm all tiles and enemies are migrated** (every TileResource has `effect_chain_v2` set).

2. **Search for remaining uses of the old system:**
   ```
   # Search for these patterns in the project:
   effect_chain.play
   EffectVariables.new()
   calculate_final_amount_with_global_modifiers
   Effect.play(
   await effect.play(
   ```

3. **Remove from `tile.gd`:**
   - The old `EffectVariables` builder method (`_generate_effect_variables()`).
   - The `elif tile_resource.effect_chain:` fallback branches in `activate()` and `handle_tile_event()`.

4. **Remove from `tile_resource.gd`:**
   - `@export var effect_chain: EffectChain`
   - `@export var event_responses: Dictionary[TileEvent, EffectChain]`

5. **Delete these files entirely:**
   - `Source/Content/Effects/effect.gd`
   - `Source/Content/Effects/effect_chain.gd`
   - `Source/Content/Effects/effect_variables.gd`
   - All files in `Source/Content/Effects/AttributeChangers/`
   - All files in `Source/Content/Effects/Targeters/`
   - All files in `Source/Content/Effects/AmountModifiers/`
   - All files in `Source/Content/Effects/Conditionals/`
   - All files in `Source/Content/Effects/Repetitions/`
   - All other Effect subclass files (scan the full Effects/ directory)

6. **Run the game** after each deletion step. Fix errors immediately before deleting more.

7. **Clean up `globals.gd`:** Remove `var modifier_manager` (already done in Block 9).

### Done when
`Source/Content/Effects/` directory is empty or deleted. No references to `EffectChain`,
`EffectVariables`, `DamageEffect`, etc. remain anywhere.

---

## Block 14 — More Event Types (as needed, ~1 hr each)

**Goal:** Create typed events for any remaining unported effect behaviors.

As you migrate complex effects, you may find behaviors that belong in new Event classes
rather than in existing ones. Create them as needed:

| Behavior | Suggested Event Class |
|---|---|
| Engine charge change | `EngineChargeEvent` |
| Die value change | `DieValueChangeEvent` |
| Tile activation (activate another tile) | `ActivateTileEvent` |
| Player jump | `JumpEvent` |
| Enemy flee | `FleeEvent` |
| Tile status added | `AddTileStatusEvent` |

**Pattern:** Every new event should:
1. Extend `EffectEvent`.
2. Override `resolve(engine)`.
3. Keep resolution focused — no modifier logic, no signal buses inside `resolve`.
4. Emit any relevant `Events.*` signals from inside `resolve` (not from handlers).

---

## Block 15 — Audit, Debug Mode & Polish (~1 hr)

**Goal:** Confidence that the whole system works correctly and is easy to debug.

### Tasks

1. **Add a debug log mode to ScenarioEngine:**

   ```gdscript
   var debug_log: bool = false

   func process_events() -> void:
       if _processing:
           return
       _processing = true
       while not event_queue.is_empty():
           var event: EffectEvent = event_queue.pop_front()
           if debug_log:
               print("[ScenarioEngine] Processing: %s (amount=%d, targets=%d)" % [
                   event.get_class(), event.amount, event.targets.size()
               ])
           for mod: Modifier in modifiers:
               if event.canceled: break
               await mod.on_before_event(event, self)
           if debug_log and not event.canceled:
               print("[ScenarioEngine] After modifiers: amount=%d" % event.amount)
           if not event.canceled:
               await event.resolve(self)
               event_resolved.emit(event)
               for mod: Modifier in modifiers:
                   await mod.on_after_event(event, self)
           elif debug_log:
               print("[ScenarioEngine] Event CANCELED.")
       _processing = false
       all_events_processed.emit()
   ```

2. **Play through 3–5 full combat encounters** with debug_log enabled.
   Watch the event queue and confirm amounts are correct at each step.

3. **Test edge cases:**
   - What happens if an enemy dies mid-queue (other events target it)? Check `is_instance_valid()` guards in event resolve methods.
   - What happens if a tile is destroyed during its own chain? Check DestroySourceHandler ordering.
   - What happens with 0 targets? All attribute change handlers have early-return guards.

4. **Optional: EditorInspectorPlugin** for EffectData.
   This makes authoring much nicer by showing the correct enum dropdown for `subtype`
   based on the selected `category`. It's a pure UX improvement and does not affect runtime.
   Look up "Godot EditorInspectorPlugin GDScript" for a tutorial when you're ready.

### Done when
- Debug log shows correct before/after amounts for modifiers.
- No crashes from invalid targets or mid-queue node death.
- You've played through a full run of the game without seeing legacy effect code in the output.

---

## Quick Reference: Enum Cheat Sheet

When authoring EffectData in the inspector, use these integer values:

```
Category:
  TARGETING=0  ATTRIBUTE_CHANGE=1  AMOUNT_MODIFIER=2  DICE_CONTROL=3
  VISUAL=4     TILE_CONTROL=5      SCENARIO_CONTROL=6  CONDITIONAL=7
  REPETITION=8  UTILITY=9

TARGETING subtypes:
  TARGET_ENEMIES=0  TARGET_PLAYER=1  TARGET_RANDOM_ENEMY=2  TARGET_ALL_SHIPS=3
  TARGET_ALL_OTHER_SHIPS=4  TARGET_RANDOM_SHIP=5  TARGET_RANDOM_TILE=6
  TARGET_SURROUNDING_TILES=7  TARGET_WITH_TARGETING_COMPUTER=8
  TARGET_EFFECT_SOURCE=9  TARGET_SELF=10

ATTRIBUTE_CHANGE subtypes:
  DAMAGE=0  HEAL=1  SHIELD=2  CHANGE_ENGINE_CHARGE=3

CONDITIONAL subtypes:
  IF_ACTIVATOR_ODD=0  IF_ENEMY_TARGETED=1  IF_ENGINE_CHARGED=2
  IF_DIE_VALUE_IN_RANGE=3

VISUAL subtypes:
  SPAWN_HIT_PARTICLES=0  SPAWN_EXPLOSION_PARTICLES=1  ANIMATE_DIE_TO_TILE=2
  ATTACK_TWEEN=3  SHAKE_DICE=4  PLAY_SOUND=5  WAIT=6

SCENARIO_CONTROL subtypes:
  OPEN_SHOP=0  CLOSE_SHOP=1  JUMP=2  FLEE=3  MOVE_SHIP=4
```

---

## Non-Obvious Things That Will Bite You

1. **`await` is required in `process_events()`** — forgetting `await` before any async handler means animations resolve instantly and sequencing breaks.

2. **`context.targets` is a live Array reference** — `DealDamageHandler` calls `context.targets.duplicate()` when building the event. This is intentional: if a later handler clears `context.targets`, events already in the queue still have their original target list.

3. **Order in the chain matters** — TARGETING must always come before ATTRIBUTE_CHANGE. If you put damage before targeting, `context.targets` is empty and `DealDamageHandler` returns early (silently).

4. **Re-entrancy guard is correct behavior** — if you call `process_events()` while already processing (e.g., from inside a resolve), the second call is silently ignored. Events you enqueue from inside a resolve are still picked up by the outer loop. Do not try to "fix" this.

5. **ScenarioEngine is a Node, not a Resource** — it must be in the scene tree. `add_child(engine)` before any event processing.

6. **Modifiers sort by priority on insertion** — if you add two modifiers with the same priority, their relative order is insertion order. Assign distinct priorities to avoid surprises.

7. **Temporary status modifiers** — if a status should expire after one turn, connect to `Events.player_turn_start` and call `engine.remove_modifier(mod)` from there. The engine doesn't manage modifier expiry automatically.
