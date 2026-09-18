# Die Fighter - Architecture Overview

## Executive Summary

Die Fighter is a turn-based sci-fi roguelike built in Godot 4.7 where players place dice on an ability grid to trigger tile effects, then enemies use the same dice values to act. The core architecture centers around a **ScenarioEngine** (event queue + modifier system) that processes combat events through a deterministic pipeline: modifiers adjust → event resolves → follow-ups trigger.

The codebase uses a **component-based composition pattern** with minimal inheritance, heavy reliance on GDScript signals for decoupling, and data-driven resource assets for game content. A refactor in progress moves from direct behavior execution (Effect classes) to an event-driven architecture (EffectEvent subclasses + handlers).

---

## Global Architecture

### System Components

**Autoloads** (persistent singletons loaded before any scene)

| Node | File | Responsibility |
|------|------|----------------|
| `InputManager` | `Autoloads/input_manager.gd` | Global input actions (screenshot, pause menu, end turn) |
| `Globals` | `Autoloads/globals.gd` | Central registry for all system singletons and global constants (colors, settings) |
| `Events` | `Autoloads/events.gd` | Central event bus—35+ signals for all game events (combat start, player health hit, dice placed, etc.) |
| `SFXPlayer` | `Autoloads/sound_effects_player.gd` | Audio playback through SoundEffectResource and AudioStreamPlayer |
| `DebugLogger` | `Autoloads/debug_logger.gd` | Centralized logging and debug output |
| `Screenshotter` | `Autoloads/screenshotter.gd` | Screenshot capture |
| `QuitManager` | `Autoloads/quit_manager.gd` | Graceful application quit |
| `EffectRegistry` | `Autoloads/effect_registry.gd` | Maps effect categories/subtypes to handler classes |
| `ContentRegistry` | `Autoloads/content_registry.gd` | Maps stable string IDs to `res://` paths so saves survive `.tres` renames/moves; stores IDs in save instead of raw paths |
| `RNGManager` | `Autoloads/rng_manager.gd` | Owns all RNG "buckets" (`RUN`, `DICE`, `ENEMY_AI`, `TARGETING`, `REWARDS`, `BACKGROUND`, `COSMETIC`); keeps gameplay randomness reproducible from a seed, cosmetic free-running; re-seeds on `Events.load_scenario` |
| `SaveManager` | `Autoloads/save_manager.gd` | Single autosave slot to `user://save_game.json` (JSON, `SAVE_VERSION = 1`); deletes save on `game_over`; `GameStateManager` keeps a `GameSaveResource` current and calls `write_save()` at checkpoints |
| `MCPInteractionServer` | `Autoloads/mcp_interaction_server.gd` (mirrored at repo root) | TCP server on port 9090 for external MCP interaction; runs `PROCESS_MODE_ALWAYS` |

**Core Game Systems** (Scene-organized with singleton references)

| System | Scene/Node | File | Responsibility |
|--------|-----------|------|----------------|
| `GameStateManager` | `Systems/GameStateManager` | `GameStateManager/game_state_manager.gd` | State machine: OUT_OF_COMBAT → IN_COMBAT → GAME_OVER / VICTORY; generates each sector, detects a cleared jump gate and advances to the next sector, owns the run's difficulty multipliers |
| `Player` | `Systems/Player` | `Systems/Game/Player/player.gd` | Player ship with health/shields/dice queue; manages turn flow: spawn dice, reroll, end turn |
| `TileGrid` | `Systems/Player/MainViewer/TileGrid` | `Systems/Game/TileGrid/tile_grid.gd` | 3x5 grid coordinates, tile placement/snap logic, push mechanics, status effects per cell |
| `EnemyManager` | `Systems/EnemyManager` | `Systems/Game/EnemyManager/enemy_manager.gd` | Spawns/enemy management; runs enemy turns sequentially via dice queue |
| `Map` | `Systems/Player/MainViewer/Map` | `Systems/Game/Map/map.gd` | Hyperspace map with waypoint selection, fate corruption zones, sector gate jumps |
| `ScenarioManager` | `Systems/ScenarioManager` | `Systems/Game/ScenarioManager/scenario_manager.gd` | Per-scenario event dispatch; faction tracking (PIRATE/CIVILIAN/BOSS); combat resolution logic |
| `TargetingComputer` | `Systems/Player/TargetingComputer` | `Systems/Game/TargetingComputer/targeting_computer.gd` | Enemy intent display: shows die → action mapping for currently targeted enemy |
| `JumpManager` | `Systems/JumpManager` | `Systems/Game/JumpManager/jump_manager.gd` | Plays the hyperspace transition (intro → load scenario → outro → start). Public `jump_to_scenario()`, used both by map jumps and sector advances |
| `HazardManager` | `Systems/HazardManager` | `Systems/Game/HazardManager/hazard_manager.gd` | Runs the current scenario's `ScenarioHazardResource`: counts down in player turns, queues its chain onto the engine, broadcasts the countdown |
| `RunStats` | `Systems/RunStats` | `Systems/Game/RunStats/run_stats.gd` | Tallies sectors reached / encounters cleared / ships destroyed / credits earned for the end-of-run summary |

**UI Systems**

| System | Scene/Node | Responsibility |
|--------|-----------|----------------|
| `InfoShower` | `UI/InfoShower` | Hover-to-show info graphics with tween animation |
| `MoneyIndicator` | `Systems/Player/MoneyIndicator` | Displays current money with spawn particles |
| `PlayerHealthBar` | `Systems/Player/PlayerHealthBar` | HP/shields UI with reveal animations |
| `EngineCharger` | `Systems/Game/EngineCharger` | Engine charge bar (recharges when not in combat) |
| `PauseMenu` | `UI/PauseMenu` | Pause state toggle, save/quit, option screen |
| `GameOver` | `UI/GameOver` | Game over **and** victory sequence, with the run summary line |
| `SectorIndicator` | `Systems/Player/MainViewer/TabButtons` | `SECTOR n/3` readout; pulses on `sector_advanced` |
| `HazardIndicator` | `UI/HazardIndicator` | Countdown banner for the active scenario hazard |
| `MainMenu` | Root scene (title_screen) | Start game, options, wishlist link |
| `TutorialManager` | `Systems/TutorialManager` | Tutorial step progression with popups |

**Background & Visuals**

| System | Scene/Node | Responsibility |
|--------|-----------|----------------|
| `BackgroundManager` | `Graphics/BackgroundManager` | Parallax layer manager: black holes, nebulae, stars, debris |
| `Vignette` | `Graphics/Vignette` | Flash overlay for camera shake/impact emphasis |
| `GlitchController` | `UI/GlitchShader` | CSS glitch shader activation on large camera shake |

---

## Core Gameplay Loop

### 3.1 Turn Structure

1. **Player Turn**
   - `Events.start_scenario` → `GameStateManager` checks combat state
   - `Events.player_turn_start` → Player rerolls dice, enables dragging
   - Player places dice on tiles
   - Tiles trigger effects via ScenarioEngine (event queue)
   - When dice queue empty: `Events.player_turn_over`

2. **Enemy Turn**
   - EnemyManager sequentially processes each enemy's dice queue
   - Enemy uses die → triggers Pre-chosen actions → emit `Events.enemy_used_die`
   - When all enemies out of dice: `Events.enemy_turn_over`

3. **Round Reset**
   - `Events.combat_finished` (if combat ended) or loop to step 1

---

## Combat Architecture

### 4.1 ScenarioEngine (Central Combat Processor)

**Location:** `Source/Systems/Game/ScenarioEngine/scenario_engine.gd`

```gdscript
class_name ScenarioEngine
extends Node

var event_queue: Array[EffectEvent]      # FIFO queue of events to process
var modifiers: Array[Modifier]           # Active modifiers (sorted by priority)
```

**Event Processing Pipeline**

For each event in `event_queue`:

1. **Before Hooks** → Run `modifier.on_before_event(event, self)` for all modifiers (in priority order 0–99)
   - Modifiers can: adjust `event.amount`, replace `event.targets`, set `event.canceled = true`
   
2. **Resolution** → Call `await event.resolve(self)` if not canceled
   - Concrete subclasses implement their own resolution logic
   - Used for animations, damage application, and side effects
   
3. **After Hooks** → Run `modifier.on_after_event(event, self)`
   - Modifiers can enqueue follow-up events (e.g., "gain shield when dealing damage")

4. Emit `event_resolved(event)` signal

**Event Queue Management**

| Method | Behavior |
|--------|----------|
| `queue_event(event)` | Append to queue end, start processing if idle |
| `inject_event(event)` | Insert at current injection index (for mid-chain follow-ups) |
| `clear_events()` | Empty queue immediately |

### 4.2 EffectEvent Base Class

**Location:** `Source/Behavior/EffectsV2/EffectEvents/effect_event.gd`

All combat actions flow through typed subclass instances of `EffectEvent`:

```gdscript
class_name EffectEvent extends RefCounted

var actor: Node              # Player or Enemy that triggered this
var effect_source: Node      # Tile or enemy ship that owns the chain
var activator_die: Dice      # The die that activated the effect (optional)
var die_value: int           # Cached at activation time
var targets: Array[Node]     # Set by targeting handlers
var amount: int              # Primary numeric value (damage/shields/heal)
var canceled: bool = false   # Set by modifiers to abort
var metadata: Dictionary     # Free-form data storage
```

**Key Subclasses**

| Event | Location | Responsibility |
|-------|----------|----------------|
| `DamageEvent` | `AttributeChange/damage_event.gd` | Deals damage to shields then health; spawns particles |
| `ShieldEvent` | `AttributeChange/shield_event.gd` | Adds shield buffer; clamps at max_shields |
| `HealEvent` | `AttributeChange/heal_event.gd` | Restores HP up to max_health |
| `TileActivationEvent` | `TileControl/tile_activation_event.gd` | Triggers a tile's effect chain with an activator die |

**Tile Grid Integration**

- Each `Tile` has a `scenario_engine` reference set during scenario start
- When player places a die: Tile enqueues `TileActivationEvent`
- When grid events fire (tile push, manual move): Tile enqueues corresponding events
- Events flow through ScenarioEngine → modifiers → resolution

### 4.3 Modifier System

**Location:** `Source/Behavior/Modifiers/modifier.gd`

```gdscript
class_name Modifier extends RefCounted

var priority: int           # Lower runs first (see ranges below)
var modifier_name: String
var affected_node: Node2D   # Tile, Enemy, or Dice node this modifies
var status_visual_scene: PackedScene  # Visual indicator for UI/HUD
var is_temporary: bool      # Swept by clear_temporary_modifiers() on player turn start
```

**Priority Ranges**

| Range | Purpose |
|-------|---------|
| 0–9   | Cancellation / immunity (run first, can stop everything) |
| 10–29 | Additive flat modifiers (+N damage/shields) |
| 30–49 | Conditional additive (only if die odd) |
| 50–69 | Multiplicative (×2 damage) |
| 70–89 | Clamping / caps (cap damage at 10) |
| 90–99 | Follow-up enqueuers (gain shield when dealing damage) |

**Modifier Lifecycle**

- `add_modifier(mod)` → Add to array, sort, call `mod.on_registered()`, emit signal
- `remove_modifier(mod)` → Remove, call `mod.on_unregistered()`
- `clear_temporary_modifiers()` → Called on player turn start, removes all `is_temporary = true`

### 4.4 Tile Activation Flow

**Step-by-step when player drops a die on a tile:**

1. Player's `DiceQueue` receives die → enqueues to `dice_manager.queue`
2. `Tile._on_die_accepted()` called
3. `Events.die_placed_on_tile.emit(die, tile)` (tutorial)
4. Tile enqueues to ScenarioEngine:

```gdscript
var event: TileActivationEvent = TileActivationEvent.new()
event.tile = self
event.activator_die = die
scenario_engine.queue_event(event)
```

5. ScenarioEngine processes:
   - `on_before_event()` → Modifiers adjust tile behavior if needed
   - Resolve → Tile's effect chain executes (see 4.6)
   - `on_after_event()` → Follow-up modifiers (status, etc.)

### 4.5 Enemy Turn Flow

1. `Events.player_turn_over` triggers `EnemyManager.run_enemy_turn()`
2. For each enemy with dice:
   - targeting_computer shows intent UI (`Events.enemy_received_die` updates dice view)
   - Tween die to front of enemy ship (0.75s)
   - Popup action indicator texture
   - `action.effect_chain.play(effect_variables)` (legacy chain, see 4.7)
   - Emit `Events.enemy_used_die(enemy, die_value)`
3. When all enemies out of dice: `Events.enemy_turn_over`

---

## Data-Driven Content System

### 5.1 Resources ( `.tres` files)

**Content hierarchy:**

| Resource | Location Pattern | Purpose |
|----------|------------------|---------|
| `TileResource` | `Source/Content/Tiles/TileResources/*.tres` | Defines tile behavior, textures, uses per turn, activation criteria, effect chains |
| `ScenarioHazardResource` | `Source/Content/ScenarioResources/Hazards/*.tres` | A recurring environmental event on a scenario (solar flare, ion storm, asteroid impact): timing plus an `EffectChainV2` |
| `EnemyResource` | Embedded in enemy instances | Base stats, graphics scene, dice queue position, action options weight list |
| `EffectChain` | In TileResource fields | Legacy effect chain (deprecated, see refactoring) |
| `EffectChainV2` | In TileResource fields | Data-driven effect chain (refactored) |
| `ActivationResource` | In TileResource.activation_checks | Dice criteria checks (value range, odd/even, same die value) |

### 5.2 Tile Resource Fields

```gdscript
class_name TileResource extends Resource

@export var tile_name: String
@export_multiline var activation_description: String
@export_multiline var description: String
@export_multiline var hint_text: String

@export var textures: SpriteFrames                    # 0 = infinite uses, 1-∞ = uses remaining
@export var uses_per_combat: int = -1                # -1 = unlimited uses
@export var activation_checks: Array[ActivationResource]
@export var effect_chain: EffectChain                  # Legacy (to be removed)
@export var effect_chain_v2: EffectChainV2             # Refactored (active)
@export var event_responses: Dictionary[TileEvent, EffectChain]      # Legacy
@export var event_responses_v2: Dictionary[TileEvent, EffectChainV2] # Refactored
```

### 5.3 Effect Chains

**Two implementations coexist:**

1. **EffectChain (Legacy)**
   - Located in `Source/Content/Effects/effect_chain.gd`
   - Direct node execution via `play(effect_variables)`
   - No modifier interaction
   - Being phased out

2. **EffectChainV2 (Refactored)**
   - Located in `Source/Behavior/EffectsV2/EffectChainV2/effect_chain_v2.gd`
   - Contains array of `EffectData` nodes
   - Calls EffectRegistry to resolve handlers
   - Integrates with ScenarioEngine modifiers

---

## Save System

### Autosave Slot

**Autoload:** `SaveManager` (`Autoloads/save_manager.gd`)

Single autosave slot serialized to JSON at `user://save_game.json` (`SAVE_VERSION = 1`). `GameStateManager` keeps a current `GameSaveResource` in sync and calls `write_save()` at checkpoints; `SaveManager` deletes the save on `game_over` **and** on `victory` — a run ends either way.

`GameSaveResource.sector_index` (zero-based) persists how deep the run is. It's read with a default, so pre-sector saves load as sector 1 without a version bump.

Nothing writes to disk during a sector transition — the next checkpoint is the `start_scenario` at the far end of the jump — so quitting mid-transition reloads at the jump gate with its fight intact rather than in a half-advanced state.

| Resource | Location | Responsibility |
|----------|----------|----------------|
| `GameSaveResource` | `Resources/game_save_resource.gd` | Serializable game state (renamed from `game_save.gd`) |
| Slot resources | `Resources/SaveResources/*.tres` | Per-slot save templates (`game_start.tres`, `tutorial_start.tres`) |

---

## Run Progression

A run is `demo_sector_count` sectors long (3 by default). Each sector is
generated by `GameStateManager._randomize_sector_scenarios()` and laid out as:

```
[fate] ... [shops / combat / event mix] ... [boss] [jump gate]
```

The **jump gate**, not the boss, is the last tile and the actual sector-end
trigger. Both are flagged `sector_gate_scenario`, which protects them from
being cleared or overwritten by `Map.clear_current_scenario_slot()`.

| Step | Where |
|------|-------|
| Gate cleared → advance or win | `GameStateManager._check_sector_cleared()` on `combat_finished` |
| Generate the next sector | `_randomize_sector_scenarios()` (safe to call repeatedly — it resets its own state) |
| Repoint the map | `Map.load_sector()` |
| Play the transition | `JumpManager.jump_to_scenario()` — the same animation as a normal map jump |
| Run ends | `Events.victory` → `GameState.VICTORY`, save deleted, summary shown |

**Difficulty** is two numbers, deliberately separate:

| Multiplier | Applied at | Default per sector |
|---|---|---|
| `get_difficulty_multiplier()` — enemy health & shields | `Enemy._update_health_from_resource()` | +0.35 |
| `get_damage_multiplier()` — enemy intent amounts | `EnemyActionOptionResource.get_action()` | +0.20 |

Damage scales slower than health on purpose: tankier enemies lengthen a fight,
harder-hitting ones can invalidate a defensive build outright.

The **boss is indexed by sector** rather than picked at random
(`boss_combat_scenarios[sector]`, clamped), so the one encounter a player is
guaranteed to meet each sector is also the clearest place to show escalation.
Sector 1 arrives at the authored `starting_scenario`; later sectors arrive at a
random question scenario not already placed in that sector.

---

## Scenario Hazards

A `ScenarioResource` may carry a `ScenarioHazardResource`: a recurring
environmental event with a first-trigger delay, a repeat interval, and an
`EffectChainV2`. `HazardManager` counts down in player turns and queues a
`HazardEvent` onto the live scenario engine, so hazard damage passes the same
modifier pipeline as everything else.

The countdown banner (`HazardIndicator`) is not decoration — it's the feature's
justification. An unannounced board-wide flare is a dice roll; one the player
watched approach for two turns while deciding whether to spend on shields is a
decision. Same rule the enemy intent telegraph follows.

Authored hazards live in `Source/Content/ScenarioResources/Hazards/`.

---

## Refactoring Status (EffectsV2)

### 6.1 Data-Driven Effect System

**New architecture in progress:**

| Component | Location | Description |
|-----------|----------|-------------|
| `EffectContext` | `Source/Behavior/EffectsV2/effect_context.gd` | "Who and what" for effect execution: actor, effect_source, activator_die, targets, repetitions |
| `EffectEnums` | `Source/Behavior/EffectsV2/effect_enums.gd` | Central category/subtype enums for effect classification |
| `EffectRegistry` | `Autoloads/effect_registry.gd` | Maps Category/Subtype to handler GDScript classes |
| `EffectEvents/*` | `Source/Behavior/EffectsV2/EffectEvents/` | Event subclasses per subtype (50+ concrete event types) |

**Effect Categories**

| Category | Subtypes |
|----------|----------|
| TARGETING | TARGET_ENEMIES, TARGET_PLAYER, TARGET_RANDOM_SHIP, TARGET_RANDOM_OTHER_ENEMY, etc. |
| ATTRIBUTE_CHANGE | DAMAGE, HEAL, SHIELD, CHANGE_ENGINE_CHARGE |
| AMOUNT_MODIFIER | MULTIPLY, ADD_ADJACENT_TILES, ADD_EMPTY_ADJACENT_CELLS, SET_TO_ENGINE_CHARGE |
| DICE_CONTROL | REROLL_ACTIVATOR, FLIP_1S_AND_6S, SPAWN_HOLOGRAPHIC_DIE, KEEP_DIE_WITH_ACTOR |
| AUDIO_VISUAL | SPAWN_HIT_PARTICLES, ANIMATE_DIE_TO_TILE, PLAY_SOUND |
| TILE_CONTROL | ACTIVATE_SELF, PUSH_TILE_IN_DIRECTION, PUSH_TARGETED_TILES, PASS_DIE_TO_TILE, ADD_AMPLIFIER_STATUS |
| SCENARIO_CONTROL | OPEN_SHOP, CLOSE_SHOP, JUMP, FLEE |
| CONDITIONAL | IF_ACTIVATOR_ODD, IF_ENEMY_TARGETED, IF_ENGINE_CHARGED, IF_TARGET_HOLDS_MATCHING_DIE |
| REPETITION | ADD_REPETITIONS |
| UTILITY | DESTROY_SOURCE, PRINT_DEBUG |

> **Subtype numbering is load-bearing.** `.tres` files store `category` and
> `subtype` as raw ints, so a new value inserted mid-enum silently rewires every
> authored effect below it — with no error anywhere. Always append.

> **Runaway chains.** `ScenarioEngine.process_event_queue()` aborts after
> `_MAX_EVENTS_PER_RUN` (2000) events in one drain and logs the likely cause.
> Without it, two tiles activating each other hard-freezes the game silently.
> Relevant to anything using `ACTIVATE_TARGETED_TILES` or `PASS_DIE_TO_TILE`.

**Flow when EffectChainV2 executes:**

1. Caller builds `EffectContext` (actor, source, die, targets)
2. Iterates through `EffectData` nodes
3. For each, lookup handler in `EffectRegistry`
4. Handler instantiates appropriate `EffectEvent` subclass
5. Event enqueued to ScenarioEngine → modifiers → resolution

---

## UI & Input Architecture

### 7.1 main_game Scene (Root)

**Main scene tree:**

```
Main (Node2D)
├── WorldEnvironment (Environment, glow settings)
├── MusicPlayer (AudioStreamPlayer, autoplay)
├── UI (CanvasLayer)
│   ├── InfoShower
│   ├── GameOver
│   ├── GlitchShader (ColorRect with shader)
│   ├── FPSCounter
│   ├── FadeIn (overlay for fade-in/fade-out)
│   └── MouseCursor
├── Graphics (Node2D, z_index=-2)
│   ├── Camera2D (zoom=6x, 320×180→1920×1080)
│   │   └── Shakeable (Shakeable component)
│   ├── Cockpit Walls
│   ├── DiceAreaHighlight (shader pulse)
│   └── BackgroundManager
├── Systems (Node2D)
│   ├── Player (player.gd)
│   │   ├── DiceQueue
│   │   ├── Health (Health.gd)
│   │   ├── TargetingComputer
│   │   ├── MoneyIndicator
│   │   └── MainViewer (Systems map toggle)
│   │       ├── TileGrid
│   │       └── Map
│   ├── EnemyManager (enemies array)
│   ├── RewardManager
│   ├── Shop
│   ├── ScenarioManager
│   ├── JumpManager
│   ├── TutorialManager
│   ├── GameStateManager
│   └── GameAnimationPlayer (fade animations)
└── PauseMenu (on top layer)
```

### 7.2 UI Interaction Patterns

**Drag & Drop (Dice/Grid)**

- Uses `Draggable` component on Dice and Tile
- `draggable.drag_ended.connect(drop_handler)`
- `draggable.reached_new_home.connect(homemovement_finished)`

**Click-to-Show (Targeting)**

- Click enemy → `Events.enemy_received_die` → update intent dice textures
- Click action indicator → show action info

**Tab Switching**

- MainViewer toggles between SYSTEMS and MAP views
- `Events.show_systems.emit()` / `Events.show_map.emit()`

---

## Core Classes Reference

### 8.1 Player (`Systems/Game/Player/player.gd`)

```gdscript
@export var num_of_dice: int          # Dice count → determines max_engine_charge
@export var engine_charge: int        # Max: (6*(num-1)) - floor(1.7078 * sqrt(num))
var dice_manager: DiceQueue           # Queue node with drag management

func spawn_dice(num_to_spawn, value=0, holographic=false) -> void
func reroll_dice() -> void            # Tween each die with sound SFX
func end_turn() -> void               # Emit player_turn_over when queue empty
```

**Turn Logic**

- `Events.load_scenario` → seed RNG
- `Events.start_scenario` → clear dice, spawn new set
- `Events.player_turn_start` → reroll dice, enable dragging
- `Events.tile_activation_complete` (from tile grid) → check empty queue, enable end-turn button

### 8.2 Tile (`Source/Content/Tiles/tile.gd`)

```gdscript
@export var uses_remaining: int                  # Decrements on activation
var effect_data: Dictionary[String, int]         # Tile-specific state (turns_since_last_active, etc.)
var scenario_engine: ScenarioEngine

func clears_activation_criteria(die: Dice) -> bool   # Checks uses, dice value criteria
func handle_tile_event(tile, event_type) -> void     # Hook for event-driven activation (disabled, TODO)
```

**Activation Check Resource**

- `ActivationResource` checks die properties
- Examples: value in range [min,max], die odd/even, same value as another tile

### 8.3 TileGrid (`Source/Systems/Game/TileGrid/tile_grid.gd`)

```gdscript
var grid_width: int = 5
var grid_height: int = 3
var grid_spacing: int = 24
var tile_locations: Dictionary[Vector2i, Tile]  # Coordinate → Tile mapping

func receive_tile(tile, drop_position) -> void     # Drop from outside grid into cell
func move_tile(tile, new_pos) -> void              # Swap or move to new cell
func push_tile(tile, direction) -> void            # Cardinal push (Asteroids style)
func find_available_grid_pos() -> Vector2i         # First empty coordinate
```

### 8.4 Enemy (`Source/Content/Enemies/enemy.gd`)

```gdscript
@export var enemy_resource: EnemyResource          # Base stats, graphics, action options
@export var scenario_state: ScenarioShipState      # Runtime state (faction, attitude)
var turn_actions: Array[EnemyActionResource]       # 6 pre-chosen actions per turn
static var rng: RandomNumberGenerator              # Shared RNG per scenario

func generate_turn_actions() -> void               # Build 6 actions from weighted selection
func run_turn() -> void                            # Use all dice in queue sequentially
```

**Action Selection**

- 6 action slots per enemy per turn
- Action options with weights (likelihood)
- `force_include` forces specific actions (used by tutorials, and to guarantee
  exactly one of a signature verb appears — weight 0 plus `force_include` means
  "one and only one")
- Weighted random fill remaining slots

**Which pool a turn draws from** is set by `EnemyResource.pool_selection`:

| Mode | Index |
|---|---|
| `TURN_CYCLE` (default) | `turns_alive % pool_count` — rhythms like charge/fire |
| `HEALTH_THRESHOLD` | health bar mapped onto the pools; full HP → first, near death → last |
| `SQUAD_LOSSES` | how many of its own faction have died this fight |

None of these cost anything from the perfect-information pillar: the six
resolved slots are still shown in full before the player commits a die. Only
the *table they were drawn from* changes.

---

## Signal Bus (Events.gd)

### 9.1 Combat Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `start_scenario` | Begin new scenario | Player (spawn dice), EnemyManager, TileGrid, Tutorial |
| `player_turn_start` | Player begins turn | Dice reroll, enable dragging, update UI |
| `player_turn_over` | Dice queue empty | Start enemy turn |
| `enemy_turn_over` | All enemies out of dice | Loop to player turn |
| `start_combat` | Enter combat state | Disable map switch, update UI colors |
| `combat_finished` | Combat ends (all enemies gone) | Re-enable grid dragging, unlock engine charge |
| `jump` | Hyperspace jump begins | Clear dice, reset player state |
| `sector_advanced` | A new sector has been generated (zero-based index) | SectorIndicator, RunStats |
| `victory` | Final sector's jump gate cleared | GameOver screen, SaveManager (deletes save), GameStateManager |
| `hazard_armed` / `hazard_countdown_changed` | Scenario hazard set up / ticked | HazardIndicator |
| `hazard_triggered` | Hazard fired | HazardIndicator, camera shake |

### 9.2 Player Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `die_added` | Dice spawned/rerolled/dropped | Update dice queue layout, engine charge (out of combat) |
| `set_money` | Money changed | Update UI display |
| `player_health_hit` | HP damage taken | SFX + large shake + glitch (if critical) |
| `player_shields_hit` | Shield damage taken | SFX + small shake |
| `player_shields_broken` | Shields hit zero (protected → exposed) | Large shake + long cyan vignette |
| `player_fatal_damage` | Hull reaches 0 | Emit GAME_OVER |
| `engine_charge_changed` | Engine charge changed | Update engine bar, map unlock indicators |

### 9.3 Tile Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `tile_manually_moved` | Player drops tile at new cell | Tile activation event |
| `tile_pushed` | Grid push mechanic | Tile activation event |
| `die_placed_on_tile` | Die accepted on tile | Tutorial logging |
| `tile_activation_complete` | Tile effect chain finished | Check end of turn (dice queue empty) |

Tiles also respond to `TileEvent.EventType` hooks via `event_responses_v2`:
`ON_TURN_START`, `ON_TILE_PUSHED`, `ON_TILE_MANUALLY_MOVED`,
`ON_ENEMY_TURN_OVER`, `ON_PLAYER_HEALTH_HIT`, `ON_PLAYER_FATAL_DAMAGE`. The
last two enable tiles that take **no dice at all** and pay out reactively —
they cost a grid cell instead of a die.

### 9.4 Enemy Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `enemy_received_die` | Enemy gains die in turn | Update targeting intent dice UI |
| `enemy_used_die` | Die used for action | Pulse intent indicator, emit enemy_acted |
| `enemy_left` | Enemy removed (death/flee) | Remove from array, spawn reward, faction check |
| `enemy_flew_in` | New enemy enters screen | Re-enable bobbing animation |

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           INPUT LAYER                                │
│  ┌──────────────┐  InputManager (InputAction)                      │
│  │ Keyboard/Mouse├─────────────────────▶ Events (Signal Bus)       │
│  └──────────────┘                                    ▼              │
└─────────────────────────────────────────────────────────────────────┘
                                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         STATE LAYER                                  │
│  GameStateManager (IN_COMBAT / OUT_OF_COMBAT)                      │
│  Map (Sector Scenarios, Index, Fate Corruption)                   │
└─────────────────────────────────────────────────────────────────────┘
                                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       SCENARIO ENGINE                                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ ScenarioEngine                                               │   │
│  │  event_queue: Array[EffectEvent]                            │   │
│  │  modifiers: Array[Modifier] (sorted by priority)           │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │ On Event:                                            │   │   │
│  │  │  1. Before-Hooks (modifiers adjust event)           │   │   │
│  │  │  2. Resolve (event.resolve())                       │   │   │
│  │  │  3. After-Hooks (modifiers enqueue follow-ups)      │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      EFFECT EXECUTION LAYER                          │
│  EffectChain (Legacy)      EffectChainV2 (Refactored)              │
│  Direct Method Calls       → EffectContext                         │
│                            → EffectRegistry                        │
│                            → EffectEvent Subclasses                │
│                            → ScenarioEngine.queue_event()          │
└─────────────────────────────────────────────────────────────────────┘
                                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       COMPONENT LAYER                                │
│  Player (DiceQueue, Health)      TileGrid (3×5, Snap, Push)       │
│  EnemyManager (Turns)            TargetingComputer (Intent UI)    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## File Structure Summary

```
Source/
├── Autoloads/                 # Global singletons
│    ├── input_manager.gd
│    ├── events.gd               # Central signal bus
│    ├── globals.gd              # Registry + color constants
│    ├── sound_effects_player.gd
│    ├── debug_logger.gd
│    ├── screenshotter.gd
│    ├── quit_manager.gd
│    ├── effect_registry.gd
│    ├── content_registry.gd
│    ├── rng_manager.gd
│    ├── save_manager.gd
│    └── mcp_interaction_server.gd    # also mirrored at repo root
│
├── Content/
│   ├── Tiles/                 # Tile resources & behavior
│   │   ├── TileResources/*.tres
│   │   ├── TileEventListener/tile_event.gd         # Event types for tiles
│   │   └── tile.gd                                # Core tile logic
│   │   └── tile_resource.gd                       # Data resource
│   │
│   ├── Enemies/
│   │   ├── enemy.gd                               # Enemy ship behavior
│   │   └── ... action/resource files ...
│   │
│   └── ScenarioResources/
│       ├── scenario_resource.gd                   # Per-scenario data
│       ├── scenario_hazard_resource.gd            # Recurring environmental event
│       └── Hazards/*.tres                         # Solar flare, ion storm, ...
│
├── Systems/
│   ├── Game/
│   │   ├── Player/                              # Player components
│   │   │   ├── player.gd                        # Main player controller
│   │   │   ├── DiceQueue/dice_queue.gd          # Dice arrangement logic
│   │   │   └── Health/health.gd                 # HP/shields component
│   │   │
│   │   ├── TileGrid/tile_grid.gd               # Grid management
│   │   ├── Map/map.gd                          # Hyperspace map
│   │   ├── EnemyManager/enemy_manager.gd       # Enemy spawner/turn runner
│   │   ├── TargetingComputer/targeting_computer.gd  # Intent display
│   │   ├── MainViewer/main_viewer.gd           # Systems/Map tabs
│   │   ├── ScenarioManager/scenario_manager.gd # Faction events
│   │   ├── ScenarioEngine/                     # Combat processor
│   │   │   ├── scenario_engine.gd              # Core engine
│   │   │   └── effect_event.gd                 # Event base class
│   │   ├── EngineCharger/engine_charger.gd     # Engine charge UI
│   │   ├── Dice/dice.gd                        # Die behavior & RNG
│   │   └── RewardManager/reward_manager.gd     # Tile unlocks
│   │
│   ├── UI/                                    # Interface nodes
│   │   ├── InfoShower/info_shower.gd           # Hover info display
│   │   ├── PauseMenu/pause_menu.gd             # Pause/Quit UI
│   │   ├── Mainmenu/main_menu.gd               # Title screen
│   │   └── ... other UI files ...
│   │
│   │   ├── JumpManager/jump_manager.gd          # Hyperspace transition
│   │   ├── HazardManager/hazard_manager.gd      # Scenario hazard countdown
│   │   ├── RunStats/run_stats.gd                # End-of-run tally
│   │
│   ├── TutorialManager/tutorial_manager.gd     # Tutorial state machine
│   ├── GameStateManager/game_state_manager.gd  # State transitions, sectors
│   └── Background/
│       └── background_manager.gd               # Parallax layers
│
└── Behavior/EffectsV2/                        # Refactored effect system
    ├── EffectEvents/                          # Event subclasses (50+)
    │   ├── AttributeChange/damage_event.gd
    │   ├── TileControl/tile_activation_event.gd
    │   └── ...
    ├── EffectChainV2/effect_chain_v2.gd       # New chain runner
    └── effect_context.gd                      # Context for effect execution
```

---

## Migration Status

### Legacy Pipeline (No longer active)

1. Tile activation → `EffectChain.play(effect_variables)`
2. Direct node execution within chain
3. No modifier hook points
4. Hard-coded behavior in Effect classes

### Refactored Pipeline (Active for New Content)

1. Tile activation → `ScenarioEngine.queue_event(effect_event)`
2. Event flows through:
   - Modifier before-hooks → Event resolution → Modifier after-hooks
3. Data-driven via EffectRegistry
4. Fully composable modifiers

**Migration Strategy**

- NewTileResource fields use `effect_chain_v2` + `event_responses_v2`
- Legacy fields retained but not called by default