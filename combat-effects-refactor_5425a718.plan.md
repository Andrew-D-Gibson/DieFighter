---
name: combat-effects-refactor
overview: Refactor the current Effect/EffectChain-based system into a data-driven combat engine with an event queue and modifier-based reactions, based on the design in conversation.md (without an action stack).
todos:
  - id: introduce-combat-engine
    content: Create CombatEngine, EffectEvent/DamageEvent, and Modifier base classes and wire them into the combat scene without changing existing tile/effect usage yet.
    status: pending
  - id: implement-effectdata-and-handlers
    content: Add EffectData Resource, EffectContext, handlers, and registry (EffectChainV2) to mirror the data-driven design from conversation.md.
    status: pending
  - id: wire-tiles-to-engine
    content: Update Tile.activate and handle_tile_event to use the new EffectChainV2 and CombatEngine instead of calling EffectChain.play directly.
    status: pending
  - id: migrate-damageeffect
    content: Port DamageEffect behavior into DamageEvent resolution and DealDamageHandler, and start authoring new damage tiles using EffectData/handlers.
    status: pending
  - id: introduce-real-modifiers
    content: Implement actual game modifiers (e.g., double damage, shield-on-damage) as Modifier subclasses and register them with CombatEngine during combat.
    status: pending
  - id: deprecate-legacy-effects
    content: Once all content uses the new engine, remove or deprecate the old Effect/EffectChain system and any remaining Effect subclasses that mutate combat state directly.
    status: pending
isProject: false
---

## Goal

Refactor your current `Effect`/`EffectChain` system into the architecture described in `conversation.md`, **keeping only the single event queue (no Action Stack)** and introducing:

- **A `CombatEngine` per combat** that owns an event queue and modifier list.
- **Typed combat events** (e.g., `DamageEvent`) that flow through the engine.
- **Modifier objects** that hook into `before` / `after` event phases to change values or enqueue follow-up events.
- **Data-driven effects** (`EffectData` + handlers) that describe intent and push events into the engine, rather than mutating state directly.

The transition should be incremental so the game stays playable while you migrate effects.

---

## 1. Understand and Isolate the Current Effect System

- **Current base effect**: `Effect` is a `Resource` with a virtual `play()` method that effect subclasses override:
  - [Source/Content/Effects/effect.gd](Source/Content/Effects/effect.gd)
- **Effect chains**: `EffectChain` is a `Resource` that holds `Array[Effect]` and calls each `play()` in sequence:
  - [Source/Content/Effects/effect_chain.gd](Source/Content/Effects/effect_chain.gd)
- **Tile integration**: `Tile` triggers effect chains directly when events occur or when a die activates the tile:
  - `handle_tile_event()` uses `tile_resource.event_responses[event_check].play(effect_variables)`.
  - `activate()` builds `EffectVariables` and calls `await tile_resource.effect_chain.play(effect_variables)`.
  - [Source/Content/Tiles/tile.gd](Source/Content/Tiles/tile.gd)
- **Concrete effect example**: `DamageEffect` does **all resolution and side effects itself**:
  - Chooses amount using `amount` / `inherit_die_amount`.
  - Calls `effect_variables.calculate_final_amount_with_global_modifiers(1)`.
  - Spawns hit/explosion particles, mutates `Globals.state_manager`, emits `Events.player_attacked_ship`, and directly calls `health.take_damage(final_amount)`.
  - [Source/Content/Effects/AttributeChangers/damage_effect.gd](Source/Content/Effects/AttributeChangers/damage_effect.gd)

**Implication:** Right now, *effects own behavior and state changes*. The new design moves behavior into a central `CombatEngine` and handler layer; effects become data that describe what should happen and ultimately produce events for the engine.

---

## 2. Define the Desired End-State Architecture (from conversation.md, without Action Stack)

At the end of the refactor, you want:

- **CombatEngine**
  - A non-singleton object (e.g., a Node in your combat scene) that owns:
    - An **event queue** (FIFO) of typed combat events.
    - A list of **modifiers** (player upgrades, enemy passives, statuses, etc.).
    - A dedicated RNG instance if you want deterministic replays later.
  - Processes events in an **async loop** so you can `await` animations between events.
  - For each event:
    1. Calls `on_before_event(event, engine)` on all modifiers (in deterministic priority order) so they can:
      - Adjust values (e.g., `+2 damage`, `×2 damage`).
      - Change targets.
      - Cancel the event entirely.
    2. Runs the event’s **resolution logic** (e.g., apply damage to shields then HP, set state, etc.).
    3. Calls `on_after_event(event, engine)` on all modifiers so they can:
      - Enqueue follow-up events (e.g., "when you deal damage, gain 1 shield").
- **Typed events**
  - Base `EffectEvent` with common fields (e.g., actor, targets, amount, metadata like die value).
  - Concrete subclasses like `DamageEvent` that know how to resolve themselves given a `CombatEngine` and game state (but don’t know about upgrades).
- **Modifier objects**
  - A `Modifier` base class with something like `on_before_event(event, engine)` and `on_after_event(event, engine)`.
  - Each upgrade / passive / status is a `Modifier` instance registered with the `CombatEngine`.
  - Both player and enemies use the *same* modifier system; order is controlled by numeric priority.
- **Data-driven effects & handlers** (from the earlier part of conversation.md)
  - `EffectData` Resource that designers edit in the inspector:
    - Stores **category** (e.g., TARGETING, AMOUNT, STATUS).
    - Stores **subtype enum** per category (e.g., TARGET_ENEMIES, TARGET_PLAYER; DAMAGE, HEAL).
    - Stores **parameters** (e.g., `damage_amount = 5`, `inherit_die_amount = true`).
  - `EffectHandler` base class and small concrete handlers (e.g., `TargetEnemiesHandler`, `TargetPlayerHandler`, `DealDamageHandler`) that:
    - Take `EffectData` + a context (`EffectContext`, e.g., actor, tile, targets, die, etc.).
    - Construct appropriate **events** and push them into the `CombatEngine`’s queue.
    - Do **not** talk to upgrades or modifiers; they just describe what should happen.
- **Effect chains v2**
  - Instead of `Array[Effect]` where each `Effect` mutates state, you have `Array[EffectData]`.
  - When a chain is executed, it:
    - Iterates `EffectData` elements.
    - For each, finds the appropriate handler from a registry.
    - Asks the handler to push events into the `CombatEngine` (which then drives actual damage, shields, etc.).
- **Tiles and other triggers**
  - `Tile` no longer directly calls `EffectChain.play()` that mutates health; it:
    - Builds an `EffectContext` (actor, tile, die, etc.).
    - Either:
      - Runs a v2 `EffectChain` which pushes events into the `CombatEngine`, **or**
      - Directly enqueues high-level events (e.g., a `DamageEvent`) into the `CombatEngine`.

---

## 3. What Needs to Be Removed or Reworked

You don’t delete everything at once; instead, you introduce the new system alongside the old, migrate behavior, then remove legacy pieces.

### 3.1. Legacy Effect behavior

- **Eventually remove or stop using** the `Effect` base class as the primary behavior carrier:
  - The current `play(_effect_variables)` pattern in `Effect` and all subclasses will be replaced by data + handlers feeding events to the `CombatEngine`.
- **Deprecate and then remove** concrete `Effect` subclasses where they:
  - Compute final amounts using `EffectVariables.calculate_final_amount_with_global_modifiers`.
  - Directly mutate health/shields.
  - Emit scenario signals (`Events.*`) from inside effect logic.
  - Set global state in `Globals.state_manager`.

### 3.2. Legacy EffectChain orchestration

- **Stop using** `EffectChain.play()` as the top-level orchestrator of combat effects:
  - The while-loop over `effect_variables.repetitions` and `for effect in effects: await effect.play(...)` will be replaced by:
    - A v2 `EffectChain` that delegates to handlers.
    - Or direct event enqueueing into `CombatEngine`.
- Once all tiles / abilities use the new path, you can:
  - Remove `EffectChain` (or keep a thin compatibility wrapper that uses `EffectData` internally).

### 3.3. Tile ↔ Effect coupling

- In `Tile`:
  - `handle_tile_event()` currently calls `await tile_resource.event_responses[event_check].play(effect_variables)`.
  - `activate()` currently ends with `await tile_resource.effect_chain.play(effect_variables)`.
- These call sites will be rewritten so that:
  - Tiles **don’t** directly run effect logic.
  - Tiles instead:
    - Obtain a reference to the current `CombatEngine` (passed in or looked up via combat scene).
    - Run a v2 `EffectChain` **that uses handlers to queue events in the engine**, or enqueue events directly.

### 3.4. Global modifier calculation inside EffectVariables

- `DamageEffect` uses `effect_variables.calculate_final_amount_with_global_modifiers(1)`.
- That functionality should be **moved into the modifier / event pipeline**:
  - Modifiers adjust the event value in `on_before_event()`.
  - `EffectVariables` no longer needs to know about “global modifiers”; it becomes mostly context (actor, tile, die, etc.) or can be replaced by a more focused `EffectContext`.

### 3.5. Direct scenario/event emissions inside effects

- `DamageEffect.play()` emits signals (`Events.player_attacked_ship`) and sets global state.
- In the new design:
  - The **resolution of a `DamageEvent`** (inside the engine or the event itself) should:
    - Handle shield vs HP splitting.
    - Emit any scenario-level game events that the rest of the game listens to.
  - Effect handlers and modifiers shouldn’t emit scenario/gameplay signals directly.

---

## 4. Step-by-Step Migration Plan

### Phase 1 – Introduce CombatEngine and core event types (no integration yet)

1. **Create a `CombatEngine` class** (e.g., `[Source/Combat/combat_engine.gd]`):
  - Holds:
    - `var event_queue: Array[EffectEvent] = []` (or `PackedArray` equivalent).
    - `var modifiers: Array[Modifier] = []`.
  - Public API:
    - `func enqueue_event(event: EffectEvent) -> void`.
    - `func add_modifier(mod: Modifier) -> void` / `func remove_modifier(mod: Modifier) -> void`.
    - `func has_pending_events() -> bool`.
  - Async processor:
    - `func process_events() -> void` that loops while queue not empty:
      - Pop first event.
      - Run `on_before_event` hooks ordered by priority.
      - If not canceled, run event’s `resolve(engine)`.
      - Run `on_after_event` hooks.
      - `await` any animation yields in `resolve`.
2. **Define base event and a concrete `DamageEvent`** (e.g., `[Source/Combat/effect_event.gd]` and `[Source/Combat/damage_event.gd]`):
  - `EffectEvent` with fields like:
    - `actor`, `targets`, `amount`, `source_tile`, `die_value`, etc.
    - A `canceled: bool` flag.
  - `DamageEvent` extends `EffectEvent` and implements `func resolve(engine: CombatEngine) -> void`:
    - Applies damage to shields then HP on each target.
    - Emits any necessary global `Events.*` (e.g., `player_attacked_ship`) and updates `Globals.state_manager`.
    - Optionally enqueues `EnemyDiedEvent` etc.
3. **Define a `Modifier` base class** (e.g., `[Source/Combat/modifier.gd]`):
  - Fields:
    - `priority: int`.
  - Methods:
    - `func on_before_event(event: EffectEvent, engine: CombatEngine) -> void` (default no-op).
    - `func on_after_event(event: EffectEvent, engine: CombatEngine) -> void` (default no-op).
  - Modifiers can:
    - Check event type (e.g., only for `DamageEvent`).
    - Adjust `event.amount`, `event.targets`, or set `event.canceled = true`.
    - Enqueue new events in `on_after_event` (e.g., “gain shield when dealing damage”).
4. **Create a couple of example modifiers** to exercise the pipeline (without wiring them into gameplay yet):
  - `DoubleDamageModifier` (`priority` in multiplier range).
  - `GainShieldOnDamageModifier` (uses `on_after_event` to enqueue a `GainShieldEvent` or similar).
5. **Instantiate `CombatEngine` in your combat scene**:
  - Make it a Node that is created when combat starts and freed when combat ends.
  - Do not yet connect tiles or effects; you can manually enqueue test `DamageEvent`s and run `process_events()` to validate behavior.

### Phase 2 – Introduce EffectData, handlers, and a v2 EffectChain

1. **Add shared enums and EffectData Resource** (mirroring conversation.md):
  - Create `[Source/Content/EffectsV2/effect_enums.gd]` with:
    - Effect categories (TARGETING, AMOUNT, STATUS, etc.).
    - Subtype enums per category (TARGET_ENEMIES, TARGET_PLAYER, DAMAGE, HEAL, etc.).
  - Create `[Source/Content/EffectsV2/effect_data.gd]` as a `Resource`:
    - Exports `category` and the per-category subtype enum.
    - Exports parameters like `damage_amount`, `inherit_die_amount`, etc.
    - This is what you’ll create/duplicate in the editor.
2. **Add an `EffectContext` or reuse a slimmed `EffectVariables`** (e.g., `[Source/Content/EffectsV2/effect_context.gd]`):
  - Contains things handlers need:
    - `actor`, `effect_source` (tile or enemy), `activator_die`, `targets`, maybe `repetitions`, etc.
  - Does **not** contain global modifier logic; that’s now in `CombatEngine`.
3. **Create `EffectHandler` base and a small handler set** (e.g., `[Source/Content/EffectsV2/handlers/...]`):
  - `EffectHandler` base with `func apply(data: EffectData, context: EffectContext, engine: CombatEngine) -> void`.
  - Concrete handlers:
    - `TargetEnemiesHandler` — fills `context.targets` based on current enemy list.
    - `TargetPlayerHandler` — sets player as target.
    - `DealDamageHandler` — builds a `DamageEvent` per target using `EffectData` (e.g., `damage_amount` or die value) and enqueues into `CombatEngine`.
4. **Create an effect handler registry** (e.g., `[Source/Content/EffectsV2/effect_registry.gd]`):
  - Map `(category, subtype)` to a handler instance.
  - Used by the new `EffectChain` to look up handlers.
5. **Implement `EffectChainV2`** (e.g., `[Source/Content/EffectsV2/effect_chain_v2.gd]`):
  - Holds `@export var effects: Array[EffectData]`.
    - Has `func play(context: EffectContext, engine: CombatEngine) -> void` that:
      - Optionally handles repetitions / die reset like the old `EffectChain`.
      - For each `EffectData` in order:
        - Looks up handler in registry.
        - Calls `handler.apply(data, context, engine)`.
      - Does **not** directly mutate health or call `Events`.
6. **(Optional but recommended) Add a small `EditorInspectorPlugin` for EffectData** to make category/subtype dropdowns nicer, as in conversation.md. This is purely UX and can be done after the core system works.

### Phase 3 – Wire Tiles to CombatEngine using the new chain

1. **Decide how `Tile` gets a reference to `CombatEngine`**:
  - Recommended: the combat scene owns `CombatEngine` and passes it explicitly to tiles (via a setter, dependency injection, or via a combat manager that tiles query).
    - Avoid making `CombatEngine` a `Globals` singleton if you can.
2. **Adapt `Tile._generate_effect_variables()` into an `EffectContext` builder**:
  - Either:
    - Replace `EffectVariables` with `EffectContext`, or
    - Wrap `EffectVariables` so handlers and engine see only what they need.
    - Ensure context includes actor, tile, activator die, and any grid-status adjustments.
3. **Update `Tile.activate()` to use `CombatEngine` + `EffectChainV2`**:
  - Instead of `await tile_resource.effect_chain.play(effect_variables)`, do:
    - Build `EffectContext` (including grid status modifications).
    - Call `tile_resource.effect_chain_v2.play(context, combat_engine)`.
    - Separately, ensure the combat loop is running `await combat_engine.process_events()` somewhere in the turn flow.
    - Keep the old `effect_chain` field around for tiles you haven’t migrated yet, behind a feature flag or an if/else.
4. **Update `handle_tile_event()` in `Tile` similarly**:
  - Where it currently calls `tile_resource.event_responses[event_check].play(effect_variables)`, switch to:
    - Building `EffectContext`.
    - Calling the v2 chain or directly enqueuing events in `CombatEngine`.

### Phase 4 – Migrate DamageEffect and related logic into events + modifiers

1. **Move damage resolution and side effects into `DamageEvent.resolve()`**:
  - Port the logic from `DamageEffect.play()` into `DamageEvent` or a helper used during resolution:
    - Shield vs HP splitting.
    - Particle spawning (hit/explosion) and color choice.
    - Changing `Globals.state_manager.state` to IN_COMBAT when appropriate.
    - Emitting `Events.player_attacked_ship`.
    - Calling `health.take_damage(final_amount)`.
    - `final_amount` will now come from the **event’s `amount` after modifiers**, not from `EffectVariables.calculate_final_amount_with_global_modifiers`.
2. **Update the new `DealDamageHandler` to create `DamageEvent`s**:
  - Use `EffectData` parameters (`amount`, `inherit_die_amount`) to set the base amount.
    - Let modifiers (in the engine) adjust the amount before resolution.
3. **Introduce real game modifiers** mirroring the examples from conversation.md:
  - “When the player deals damage, double it”:
    - A `Modifier` that listens to `DamageEvent` in `on_before_event()` when actor is player.
    - “When the player deals damage, gain shield”:
      - A `Modifier` that listens in `on_after_event()` and enqueues a `GainShieldEvent`.
4. **Stop using `DamageEffect` in new content**:
  - For new tiles/abilities, author `EffectData` + `EffectChainV2` entries instead of `DamageEffect` resources.
5. **Gradually replace existing `DamageEffect` resources**:
  - For each tile or event that uses a `DamageEffect` in its old `EffectChain`:
    - Create equivalent `EffectData` entries (targeting + damage) in a v2 chain.
    - Wire the tile to the v2 chain and test.

### Phase 5 – Remove/deprecate legacy pieces

1. **Once all live content uses the new system, deprecate legacy classes**:
  - Mark `Effect` and `EffectChain` as deprecated in comments.
    - Remove or simplify `EffectVariables.calculate_final_amount_with_global_modifiers` so it no longer drives core logic.
2. **Remove unused Effect subclasses**:
  - Delete `DamageEffect` and other old effect scripts once you’ve migrated their behavior into handlers/events.
3. **Simplify `Tile`**:
  - Remove old code paths that still call `effect_chain.play()`.
    - Ensure all activation and event responses go through the `CombatEngine`.
4. **Audit for direct state mutation**:
  - Search for places (especially in any remaining effects) that directly mutate combat state (HP, shields, statuses, dice) or emit combat-related signals.
    - Move that logic into events / event resolution where appropriate so **everything combat-related flows through the engine**.
5. **Add tests or debug helpers as you go** (optional but very helpful):
  - A debug mode that logs the event queue and modifier changes per event.
    - Simple unit tests for `DamageEvent` resolution (shields vs HP) and basic modifiers.

---

## 5. How to Phase This Safely

- **Keep the old system running** while you build `CombatEngine`, events, and modifiers.
- First wire up **one simple tile** (e.g., a basic “damage enemy” tile) to the new pipeline:
  - Tile → `EffectChainV2` → handlers → `CombatEngine` → `DamageEvent`.
- Once that works with a couple of modifiers, **clone the pattern** for other effect types (shields, status, particles-only, etc.).
- Only after the majority of combat flows through `CombatEngine` should you start deleting old `Effect`/`EffectChain`-based code.

This approach keeps the refactor incremental, debuggable, and aligned with the architecture you developed in `conversation.md`, while explicitly skipping the Action Stack and relying solely on a robust event queue.