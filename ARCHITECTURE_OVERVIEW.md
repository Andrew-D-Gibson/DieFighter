# Die Fighter - Architecture Overview

## Executive Summary

Die Fighter is a turn-based sci-fi roguelike built in Godot 4.7 where players place dice on an ability grid to trigger tile effects, then enemies use the same dice values to act. The core architecture centers around a **ScenarioEngine** (event queue + modifier system) that processes combat events through a deterministic pipeline: modifiers adjust → event resolves → follow-ups trigger.

The codebase uses a **component-based composition pattern** with minimal inheritance, heavy reliance on GDScript signals for decoupling, and data-driven resource assets for game content. All effects run through the event-driven pipeline: data-authored `EffectChain`s dispatch to stateless handlers, which inject `EffectEvent` subclasses into the `ScenarioEngine`. (The older direct-execution Effect classes are gone.)

---

## Global Architecture

### System Components

**Autoloads** (persistent singletons loaded before any scene)

| Node | File | Responsibility |
|------|------|----------------|
| `InputManager` | `Autoloads/input_manager.gd` | Global input actions (screenshot, pause menu, end turn via `Player.request_end_turn()`), the controller's `VirtualCursor`, `pointer_position()` (what the drawn cursor follows) and listening for rebinds (`listen_for_binding()`, `binding_captured`) |
| `Globals` | `Autoloads/globals.gd` | Central registry for all system singletons and global constants (colors, settings) |
| `Events` | `Autoloads/events.gd` | Central event bus—75+ signals for all game events (combat start, player health hit, dice placed, etc.) |
| `SFXPlayer` | `Autoloads/sound_effects_player.gd` | Audio playback through SoundEffectResource and AudioStreamPlayer |
| `MusicDirector` | `Autoloads/music_director.gd`, decks in `Systems/Music/music_deck.gd` | The one owner of music. Plays a `MusicPlaylistResource` back to back from boot and crossfades (equal-power, real time) when a scene cues `play_track(id)`; the playlist carries on from the cued track, and a track marked `repeats` restarts instead of handing over. Each playing track is a `MusicDeck` running its layers as one `AudioStreamSynchronized`, so `set_layer_enabled()` can fade stems in and out. Cues today: main menu (start theme, from the top), opening cutscene and Continue (Trailer 1) |
| `DebugLogger` | `Autoloads/debug_logger.gd` | Play-by-play of the latest session in `user://debug_log.txt`: a header (version, git commit when run from the editor, debug/release, Godot, OS, GPU, locale), each run's seed, every resolved engine event (skipping AudioVisual), turn snapshots (dice rolled, vitals, statuses, intent tables), backgrounds, modifiers and hazards. Its `ErrorSink` (an `OS.add_logger()` Logger) writes every engine error into the same file with its GDScript backtrace (`debug/settings/gdscript/always_track_call_stacks` keeps those in release exports), skipping warnings and capping an error that repeats at 3. Each launch keeps the previous 5 logs as `debug_log_<time>.txt`. A playtester's crash report is that file. Wording in `debug_log_format.gd` (`DebugLogFormat`). Off in headless instances and on the web |
| `Screenshotter` | `Autoloads/screenshotter.gd` | Screenshot capture (off on the web) |
| `QuitManager` | `Autoloads/quit_manager.gd` | Graceful application quit. `can_quit()` is false on the web, where the Quit buttons hide |
| `EffectRegistry` | `Autoloads/effect_registry.gd` | Maps effect categories/subtypes to handler classes |
| `ContentRegistry` | `Autoloads/content_registry.gd` | Maps stable string IDs (the file name) to `res://` paths for tiles, scenarios and enemies, so saves and the codex's collection survive `.tres` renames/moves; stores IDs in save instead of raw paths. Scans with `Utils.list_resource_paths()` (`ResourceLoader.list_directory()`), which still sees `.tres` names in an export, where `DirAccess` sees `.remap` |
| `RNGManager` | `Autoloads/rng_manager.gd` | Owns all RNG "buckets" (`RUN`, `DICE`, `ENEMY_AI`, `TARGETING`, `REWARDS`, `BACKGROUND`, `COSMETIC`); keeps gameplay randomness reproducible from a seed, cosmetic free-running; re-seeds on `Events.load_scenario` |
| `SaveManager` | `Autoloads/save_manager.gd` | Single autosave slot to `user://save_game.json` (JSON, `SAVE_VERSION = 2`); deletes save on `player_destroyed`, `game_over` and `victory`; `GameStateManager` keeps a `GameSaveResource` current and calls `write_save()` at checkpoints |
| `CollectionManager` | `Autoloads/collection_manager.gd` | What the player has found across every run, for the codex: tiles they've owned, enemies met/destroyed and region rules/hazards read. Kept in `user://collection.json`, outside the run save (see Codex below) |
| `OptionsSettings` | `Autoloads/options_settings.gd` | Registry of player options (see 7.4): each registered once with its default and how to read and apply its live value, keyed "Section/name" as saved in `user://options_settings.cfg`. Loads and applies them at boot, saves on `Events.save_options_config`, resets them for the menu's Defaults. Owns `PixelPerfectScaler` and `BackgroundFocus`. Also holds the `times_run` counter. Window options (size, monitor, vsync, pixel perfect) aren't registered on the web (`controls_window()`) |
| `MCPInteractionServer` | `Autoloads/mcp_interaction_server.gd` (the Godot MCP tool also writes a gitignored copy to the repo root on each run) | TCP server on port 9090 for external MCP interaction; runs `PROCESS_MODE_ALWAYS`. Editor-launched runs only: in any exported build (debug or release) it frees itself without opening the port |
| `AutoPilot` | `Autoloads/auto_pilot.gd`, helpers in `Systems/AutoPilot/` | Plays runs by itself for QA and balance testing (see AutoPilot below). Editor binaries with `-- --autoplay` only; otherwise it frees itself |

**Core Game Systems** (Scene-organized with singleton references)

| System | Scene/Node | File | Responsibility |
|--------|-----------|------|----------------|
| `GameStateManager` | `Systems/GameStateManager` | `GameStateManager/game_state_manager.gd` | State machine: OUT_OF_COMBAT → IN_COMBAT → GAME_OVER / VICTORY; generates each sector (elites and a boss-guarded gate included), advances to the next sector through the open gate (`go_through_gate()`), owns the run's difficulty multipliers |
| `Player` | `Systems/Player` | `Systems/Game/Player/player.gd` | Player ship with health/shields/dice queue; manages turn flow: spawn dice, reroll, end turn |
| `TileGrid` | `Systems/Player/MainViewer/TileGrid` | `Systems/Game/TileGrid/tile_grid.gd` | The ship's grid (3x5 by default; see Player Ships), tile placement/snap logic, push mechanics, per-turn tile activation count |
| `EnemyManager` | `Systems/EnemyManager` | `Systems/Game/EnemyManager/enemy_manager.gd` | Spawns/enemy management; runs enemy turns sequentially via dice queue; places ships along the spawning path via `EnemyFormation`, spacing each by its footprint (hull plus side-hung health bar; on a board too crowded for that, every bar tucks above its hull) and splitting the wing across free space either side of a reservation such as salvage, which also turns each ship's speech box toward its clearer side; waits for in-flight tractor beams (`TractorBeam.wait_for_landings`) before an enemy turn starts |
| `Map` | `Systems/Player/MainViewer/Map` | `Systems/Game/Map/map.gd` | Hyperspace map with waypoint selection, fate corruption zones, sector gate jumps |
| `ScenarioManager` | `Systems/ScenarioManager` | `Systems/Game/ScenarioManager/scenario_manager.gd` | Per-scenario event dispatch; faction tracking (PIRATE/CIVILIAN/BOSS); combat resolution logic |
| `TargetingComputer` | `Systems/Player/TargetingComputer` | `Systems/Game/TargetingComputer/targeting_computer.gd` | Enemy intent display: shows die → action mapping for currently targeted enemy. `target_for(die)` answers who a dropped die should hit. The reticle is placed every frame from its ship's live position (so it rides a slide), and a real target change resets every running intent pulse |
| `JumpManager` | `Systems/JumpManager` | `Systems/Game/JumpManager/jump_manager.gd` | Plays the hyperspace transition (intro → load scenario → outro → start). Public `jump_to_scenario()`, used both by map jumps and sector advances |
| `JumpGate` | `Graphics/JumpGate` | `Systems/Game/JumpGate/jump_gate.gd` | The ring at a beaten sector gate: warps in clear of salvage, `is_open()` gates the way out, plays the passage, owns the white flash and the sector title |
| `HazardManager` | `Systems/HazardManager` | `Systems/Game/HazardManager/hazard_manager.gd` | Runs the current background's `BackgroundHazardResource` for the length of each fight: arms on `start_combat`, counts down at each turn start (or, for `YOUR_TURN_ENDS` hazards, each `enemy_turn_starting`), queues its chain onto the engine, broadcasts the countdown |
| `RunStats` | `Systems/RunStats` | `Systems/Game/RunStats/run_stats.gd` | Tallies sectors reached / encounters cleared / ships destroyed / credits earned for the end-of-run summary |

**UI Systems**

| System | Scene/Node | Responsibility |
|--------|-----------|----------------|
| `InfoShower` | `UI/InfoShower` | Click-to-show info panel (title, activation, description) with tween animation. Keywords in it are hoverable and pop up their rule. While open it consumes Esc (`PauseMenu` action) to close itself, so the pause menu doesn't open |
| `MoneyIndicator` | `Systems/Player/MoneyIndicator` | Displays current money with spawn particles |
| `PlayerHealthBar` | `Systems/Player/PlayerHealthBar` | HP/shields UI with reveal animations |
| `EngineCharger` | `Systems/Game/EngineCharger` | Engine charge bar (recharges when not in combat) |
| `PauseMenu` | `PauseLayer/PauseMenu` | Pause state toggle, save/quit, option screen |
| `GameOver` | `UI/GameOver` | Game over **and** victory sequence, with the run summary line |
| `MainMenu` | Root scene (`main_menu.tscn`) | Start game, options, wishlist link |
| `TutorialManager` | `Systems/TutorialManager` | Seeded first-run tutorial: step popups over the opening fight |

**Background & Visuals**

| System | Scene/Node | Responsibility |
|--------|-----------|----------------|
| `BackgroundManager` | `Graphics/BackgroundManager` | Parallax layer manager: black holes, nebulae, stars, shader planets and suns (`CelestialBody`) laid out from a picked `SetPieceComposition`, scrolling objects (debris, asteroids, ice, scrap, fate shards, embers, ion motes); see Background Layouts and Star Parallax |
| `Vignette` | `Graphics/Vignette` | Flash overlay for camera shake/impact emphasis |
| `Juice` | `Systems/Graphics/Juice/juice.gd` (static helpers) | Bumps, wiggles, rings, sparkles and callouts; see 4.7 |
| `GlitchController` | `UI/GlitchShader` | CSS glitch shader activation on large camera shake |

---

## Core Gameplay Loop

### 3.1 Turn Structure

1. **Player Turn**
   - `Events.start_scenario` → `GameStateManager` checks combat state
   - `Events.player_turn_refresh` → every tile refills to `uses_per_turn`; `TileGrid` zeroes its activation count
   - `Events.player_turn_start` → Player rerolls dice, enables dragging; `ON_TURN_START` tile responses fire
   - Player places dice on tiles
   - Tiles trigger effects via ScenarioEngine (event queue)
   - When dice queue empty: `Events.player_turn_over` (any die a tile is still holding returns to the hand)

2. **Enemy Turn**
   - Statuses tick first (`ScenarioEngine.tick_statuses()` — Burn deals its damage) and resolve before any ship acts
   - EnemyManager sequentially processes each enemy's dice queue, left to right, then goes round again for dice relayed to a ship after its turn
   - Enemy uses die → triggers Pre-chosen actions → emit `Events.enemy_used_die`
   - When no ship holds an unspent die: `Events.enemy_turn_over`

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

A modifier that cancels an event stops the remaining before-hooks; the event
skips resolve and after-hooks and `event_canceled(event)` fires instead. Hooks
iterate a snapshot of the modifier list, since a hook can await and modifiers
may be added or removed meanwhile.

**Lifecycle.** `ScenarioManager` creates one engine per scenario on
`load_scenario`. On a jump it calls `shutdown()` before freeing it: the queue is
dropped, every modifier is unregistered (freeing status visuals parented to
tiles that outlive the scenario), and anything awaiting
`finished_processing_queue` is released. A drain suspended in an await checks
`is_shut_down()` on resuming and bails.

**Access.** `ScenarioEngine.current()` is the only way to reach the engine. It
returns null between scenarios. Nodes don't cache their own reference.

**Event Queue Management**

| Method | Behavior |
|--------|----------|
| `queue_event(event)` | Append to queue end, start processing if idle |
| `inject_event(event)` | Insert right after the resolving event (and anything it already injected); queues normally when no drain is running |
| `shutdown()` | Tear down before freeing (see Lifecycle) |

### 4.2 EffectEvent Base Class

**Location:** `Source/Behavior/Effects/EffectEvents/effect_event.gd`

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

func is_amplifiable() -> bool  # false when amount is a price/duration/counter/face value
```

Handlers fill actor / effect_source / activator_die / die_value with
`EffectHandler._stamp(event, context)`, so every event carries the full context
modifiers match on. Event-specific data goes in typed fields on the subclass.

**Key Subclasses**

| Event | Location | Responsibility |
|-------|----------|----------------|
| `DamageEvent` | `AttributeChange/damage_event.gd` | Deals damage to shields then health; spawns particles |
| `ShieldEvent` | `AttributeChange/shield_event.gd` | Adds shield buffer; clamps at max_shields |
| `HealEvent` | `AttributeChange/heal_event.gd` | Restores HP up to max_health |
| `TileActivationEvent` | `TileControl/tile_activation_event.gd` | Triggers a tile's effect chain with an activator die |
| `PassDieToTileEvent` | `TileControl/pass_die_to_tile_event.gd` | Feed: hands the die to the next tile if it will take it, otherwise to the target |
| `FeedHologramEvent` | `TileControl/feed_hologram_event.gd` | Spawns a holographic die at a tile and Feeds it on |

**Tile Grid Integration**

- Tiles reach the engine through `ScenarioEngine.current()`
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

**Lockout.** Every lockout, from any source, goes through
`AddLockoutModifierEvent`, which skips a tile whose
`TileResource.can_be_locked_out` is off (the Engine Charger, so it can never
soft-lock the run) or that's already locked, so locks never stack. Random
lockouts target with `TARGET_RANDOM_LOCKABLE_TILE`, which draws only tiles
where `Tile.accepts_lockout()` holds. A locked tile's info panel gets a line from
`LockoutModifier.get_info_text()`, the same way an Amplifier adds its own.
A 1, 2 or 3 (`LockoutModifier.unlocks(face)`) opens a lock and goes to a
random enemy; anything else bounces back to the hand. The padlock
(`lockout_modifier_visual.gd`) slams on with sparks, a ring and a LOCKED
callout, rattles on each bounce, and pops off on unlock: `on_unregistered`
calls its `release()` instead of freeing it outright.

### 4.4 Tile Activation Flow

**Step-by-step when player drops a die on a tile:**

1. Player's `DiceQueue` receives die → enqueues to `dice_manager.queue`
2. `Tile._on_die_accepted()` called. It stamps `die.aimed_at` with the
   current target; effects that read the targeting computer ask
   `TargetingComputer.target_for(die)`, which keeps that ship while it's alive
   and in the fight and falls back to the current target otherwise.
   `DiceQueue.add()` clears the aim, so it lives only until the die lands
   somewhere new.
3. `Events.die_placed_on_tile.emit(die, tile)` (tutorial)
4. Tile enqueues to ScenarioEngine:

```gdscript
var event: TileActivationEvent = TileActivationEvent.new()
event.tile = self
event.activator_die = die
ScenarioEngine.current().queue_event(event)
```

5. ScenarioEngine processes:
   - `on_before_event()` → Modifiers adjust tile behavior if needed
   - Resolve → `clears_activation_criteria()`; a refused die goes back to the
     player's hand. Otherwise a use is spent, `Events.tile_activated(tile)`
     fires, and the tile's effect chain runs with `context.feed_depth` set
   - `on_after_event()` → Follow-up modifiers (status, etc.)

A die that reaches a tile through a Feed takes a different route on refusal:
`PassDieToTileEvent` checks the criteria first and sends a refused die to the
target, never back to the hand (see 6.2).

### 4.5 Statuses

**Location:** `Source/Behavior/Modifiers/Statuses/`

A status is a `StatusModifier`: an ordinary `Modifier` that sits on one ship
(`affected_node`, an enemy or the player), counts `stacks`, and removes
itself when they run out, when an enemy ship leaves (`Events.enemy_left`) or,
on the player, when the fight ends (`Events.combat_finished`). Stacks are the
only number a status has; each status decides what one means.

| Status | On an enemy | On the player | A stack is |
|---|---|---|---|
| `BurnStatus` | `on_status_tick()` | the same | damage per round; loses one per tick |
| `ScrambledStatus` | `EnemyDiceManager.die_arriving` | before `TileActivationEvent` (priority 6), dice from the hand only | one die flipped to its opposite face |
| `JammedStatus` | before `EnemyActionEvent` (priority 35) | before `TileActivationEvent`: canceled for a `JammedTileEvent`, which sends the die to the target | the next die that would act does nothing; dice that would idle (or that the tile refuses) don't spend a stack |
| `ExposedStatus` | before `DamageEvent` (priority 25), tile hits | the same, enemy hits | +stacks on each single-target hit; spends 1 |

- **The player's side.** A status that hooks dice reads `is_on_player()`:
  where an enemy spends dice on its table, the player places them on tiles.
  Only the grid's own tiles count (`JammedStatus.is_ship_system()`: not the
  map's jump tiles or the Engine Charger). A lock (priority 5) stops an
  activation before Scrambled or Jammed see it. Burn and Exposed work the
  same either side.
- **Applying:** `ATTRIBUTE_CHANGE/APPLY_STATUS` names the status in
  `string_param` and takes `running_amount` stacks. `ApplyStatusEvent` merges
  into an existing status (`merge()`, additive by default) or registers a new
  one. Its amount is amplifiable, so an Amplifier adds stacks, except a status
  a tile puts on its own ship (Blowtorch's Burn): a cost never grows. An enemy
  putting one on the player starts the fight, like a hit.
- **Moving:** `ATTRIBUTE_CHANGE/TRANSFER_STATUSES` moves every status on the
  actor onto the first target (`TransferStatusesEvent`), rebuilt for its new
  host and merged into what it has. Countermeasures uses it one way, an
  enemy's Purge Vents the other. A vent with nothing on its ship is
  `BLOCKED` (`EnemyActionResource.outcome_of(action, ship)`), and the
  `SELF_HAS_STATUS` condition keeps it off a table until there's something
  to vent.
- **Reading:** `AMOUNT_MODIFIER/SET_TO_TARGET_STATUS`,
  `CONDITIONAL/IF_TARGET_HAS_STATUS`, and `ATTRIBUTE_CHANGE/CLEAR_STATUS`.
  `ScenarioEngine.find_status()` / `statuses_on()` look them up.
- **Ids:** `StatusCatalog` maps the authored id to its class. A content test
  checks every authored id against it.
- **Ticking:** once per round, from `EnemyTurn.play()` (see 4.6):
  `tick_statuses()` for the enemies before any ship acts, and
  `tick_statuses(true)` for the player once every ship has, before
  `enemy_turn_over` starts the player's turn.
  Nothing ticks off a signal: `EnemyManager` connects to `player_turn_over`
  first and would queue every action before a status got a look in.
- **Scrambled flips on arrival**, not on use: `EnemyDiceManager.add()` emits
  `die_arriving` before the die joins the queue, so the targeting computer's
  intent highlight sees the final face. A ship re-adding a die it already held
  (Charge Bore) isn't an arrival.
- **Badges:** each status shows a `StatusBadge` (icon + stack count) on its
  ship's `%StatusBar`: beside an enemy's health ring, above the player's
  (two to a row, clear of the Outrigger's wider panel). Clicking one shows its rule in the info panel:
  `rule_term()` picks the keyword, the "(you)" one where the player's side
  differs (`Keywords.PLAYER_SUFFIX`). The hull panel lists the player's
  statuses too. Art is in `Assets/Textures/Statuses/` (11×11 badge, 24×24
  info).
- **Threat:** an enemy action putting a status on the player (or venting
  onto them) reads `DANGEROUS`. `AutoPilotThreat.status_cost()` prices it in
  hull for the bot, and `AutoPilotForecast.of()` plays the player's own
  Scrambled (flipped face) and Jammed (only the hand-off) into a placement.
- **Debugging:** the dev console's `status <id> [stacks] [me]` applies one to
  the targeted enemy, or to the player.

**Feedback:** `play_applied_feedback()` runs when a dose lands (ship flash, or
the cockpit vignette for the player, ring, `+N NAME` callout);
`announce_triggered()` flashes the ship and calls out the name whenever a
status does its job (see 4.7). `announce_triggered_at()` draws it on a tile
instead, for a player status that acts there.

**Adding a status:** subclass `StatusModifier` (set `status_id`,
`display_name`, `color`, `icon`, `info_icon`, `priority`), add it to
`StatusCatalog`, give it a keyword in `Keywords`, and decide what it does on
the player (a "(you)" keyword if that reads differently).

### 4.6 Enemy Turn Flow

1. `Events.player_turn_over` triggers `EnemyManager.run_enemy_turn()`, which
   runs `EnemyTurn.play()` (`EnemyManager/enemy_turn.gd`; `EnemyTurn` also
   rolls and binds the tables). It waits for dice still in flight, then ticks
   the enemies' statuses and waits for the queue to drain, so a ship that
   burns to death never takes its turn
2. For each enemy with dice, left to right, one ship at a time (its queue
   drains before the next starts):
   - targeting_computer shows intent UI (`Events.enemy_received_die` updates dice view)
   - Tween die to front of enemy ship (weighted by face), a short hold
   - Popup action indicator texture
   - Emit `Events.enemy_used_die(enemy, die_value)` (pulses the matching intent)
   - `await action.effect_chain.play(context, engine)`
   - A `WaitEvent` settle beat (`EnemyActionEvent.SETTLE_SECONDS`) once the
     action's injected effects have landed
   - A relay (`FEED_ALLY` / `SPAWN_HOLOGRAM_FOR_ALLY`, see 8.4) puts the die
     in its bound ally's hold with a `FeedAllyEvent.Trail` (`feed_depth`, the
     ships already in the chain) and holds a hand-off beat. The ally spends
     it on its own table when its turn comes; the event it builds then
     carries the trail as `feed_depth` / `relay_visited`
3. Ships handed a die after their own turn get another pass
   (`Enemy.run_relayed_dice()`, no turn bookkeeping), round and round until
   no ship `has_dice_to_spend()` (kept dice don't count; `MAX_PASSES` 8)
4. The player's statuses tick (`tick_statuses(true)`) and resolve
5. Then `Events.enemy_turn_over`

### 4.7 Modifier Feedback (procs)

A modifier calls `announce_triggered()` from a hook **only when it changed
something** (an amount, a cancel, a repetition). That emits
`Events.modifier_triggered(mod)` and calls `on_modifier_triggered()` on the
modifier's visual, if it has one.

| Listener | Reacts when | Does |
|---|---|---|
| `Tile` | `mod.source == self` | `play_trigger_feedback()`: bump, flash, ring, sparks, sound, callout of `get_trigger_text()` in `get_trigger_color()` |
| `EnvironmentMonitor` | `mod` is `BackgroundModifierManager.get_active_modifier()` | the same pop as a tile: squash on the hinge, flare, ring, sparks, sound, callout of `get_trigger_text()` ("x2", "NO SHIELDS") in the rule's colour. Fires even while the monitor is still blinking unread |
| `StatusModifier` (override) | always | flashes the host ship, callout of the status name |

Set `source` when registering a modifier on a tile's behalf (see
`AddAmplifierModifierEvent`). `TileEventTriggeredEvent` gives reactive tiles
the same pop when their chain queues at least one event.

Cosmetic flourishes live in `Systems/Graphics/Juice/juice.gd` (`Juice.bump`,
`wiggle`, `ring`, `sparkle`, `callout`, `zap`, `stream`, `grid_ripple`,
`screen_ripple`, `die_flare`). Bump a sprite, not a node whose scale a
movement tween owns.

**Authored flourishes.** The same primitives are effects a chain can use:
`AUDIO_VISUAL` `SHOCKWAVE`, `SPARK_BURST`, `CALLOUT`, `BUMP`, `ZAP`,
`GRID_RIPPLE`, `SCREEN_RIPPLE`, `STREAM`, `DIE_FLARE`, `LASER`, `MISSILE`, `ION_BOLT`, all one `JuiceHandler`
building a `JuiceEvent`. They read authored fields only (`CALLOUT`'s
`{amount}` and `{die}` tokens are the exception), aren't amplifiable, and play at the
targets or, with none, at the source. `SPARK_BURST`, `STREAM` and `CALLOUT` take a
`juice_flags` bitmask (Rise; Outward, Engine, Hull Hub, Engine Hub; see
`JuiceEvent.Flag`) rather than a string. `ZAP`, `STREAM`, `LASER`,
`MISSILE` and `ION_BOLT` hold the chain until they land; the rest don't.
`LASER`/`MISSILE`/`ION_BOLT` are one `JuiceProjectile` (style enum, colour,
length; an ion bolt aims at `Juice.shield_anchor()`, the player's shield
counter) drawn through
`JuicePixelated` and re-aimed at its target node each frame;
`Juice.projectile()` is the entry point, so an enemy shot that isn't a die
can reuse it. A `LASER` is a travelling blaster bolt (a 9 px streak, 460
px/s): its flight time comes from the launch distance, clamped to 0.09-0.26 s,
and is locked at launch, so `impact_seconds()` lands the damage as it hits. A
LASER's `amount` is its flight time in ms, like MISSILE and ION_BOLT. Enemy dice
shots at the player (`AttackTweenEvent`) strike `Player.get_hull_anchor()`, the
hull readout on whichever cockpit's health bar, re-read every frame; a die an
enemy carries to its own action (`EnemyActionEvent`) is moved by
`tween_method` re-reading the ship's position, so it follows a ship that slides
mid-flight. `Juice.anchor_of()` / `body_of()` decide where an
effect on a node is drawn and what gets squashed (`Player` routes both to its
health bar; `Juice.engine_anchor()` is the engine gauge's centre). A dying
enemy's ship graphics move into a `JuicePixelated` (`pixelate()`) so the kill
sequence and its explosion render on the 320x180 grid. `SCREEN_RIPPLE` honours the screenshake setting. Where every
sound should go is in `SOUND_EFFECTS.md`.

---

## Data-Driven Content System

### 5.1 Resources ( `.tres` files)

**Content hierarchy:**

| Resource | Location Pattern | Purpose |
|----------|------------------|---------|
| `TileResource` | `Source/Content/Tiles/TileResources/*.tres` | Defines tile behavior, textures, uses per turn, activation criteria, effect chains |
| `BackgroundHazardResource` | `Source/Resources/BackgroundResources/BackgroundHazards/*.tres` | A timed environmental event that belongs to a background (solar flare, ion storm, asteroid impact, fate rift): timing plus an `EffectChain` |
| `EnemyResource` | Embedded in enemy instances | Base stats, graphics scene, dice queue position, action options weight list |
| `EffectChain` | `TileResource.effect_chain`, `event_responses`, enemy actions, hazards | Ordered list of `EffectData` entries dispatched through `EffectRegistry` |
| `ActivationResource` | In TileResource.activation_checks | Criteria checks: requires a die / takes no die, specific values, in combat, a ship targeted, engine charged / not charged, can afford N charge, overcharged, Fleet of N or fewer |

### 5.2 Tile Resource Fields

```gdscript
class_name TileResource extends Resource

@export var tile_name: String
@export_multiline var activation_description: String
@export_multiline var description: String            # May use keyword tokens, e.g. (feed_right)
@export var rarity: Rarity                           # COMMON / UNCOMMON / RARE — weights rewards and shop stock

@export var textures: SpriteFrames                   # Frame N is shown while N uses remain (frame 0 when unlimited)
@export var uses_per_turn: int                       # -1 = unlimited; refilled every player turn
@export var activation_checks: Array[ActivationResource]
@export var effect_chain: EffectChain
@export var event_responses: Dictionary[TileEvent, EffectChain]
@export var dragging_allowed: bool = true
@export var max_dice_in_queue: int = -1
```

Uses are a **per-turn budget**. Bigger payoffs are meant to carry a cost other
than uses (engine charge, hull, a die, neighbours' uses), not a once-per-fight
limit.

### 5.3 Keywords

`Source/Systems/keywords.gd` (`Keywords`) holds game terms written into
descriptions as tokens: `(feed_right)`, `(feed_left)`, `(feed_up)`,
`(feed_down)`, `(feed_random)`, `(fed)`, and one per status — `(burn)`,
`(scrambled)`/`(scramble)`, `(jammed)`/`(jam)`, `(exposed)`/`(expose)` — plus
`(hologram)`. `Utils.format_text()`
renders each token as a styled label. The info panel asks for hoverable labels
(`format_text(text, true)`), which wrap each in a `[url]` tag. `InfoShower`
listens for `meta_hover_started` on its labels and pops up
`Keywords.definition()` beside the cursor, so no rules are on screen until the
player asks. `definition()` also serves the status badges. Add a keyword by
adding its definition and its token spellings to the two tables in that file.

### 5.4 Effect Chains

`Source/Behavior/Effects/EffectChain/effect_chain.gd` holds an array of
`EffectData` entries. `play(context, engine)` looks up each entry's handler in
`EffectRegistry` (built from `EffectCatalog`) and awaits it; handlers inject
events, which resolve through the engine's modifier pipeline.

---

## Save System

### Autosave Slot

**Autoload:** `SaveManager` (`Autoloads/save_manager.gd`)

There's a single autosave slot, serialized to JSON at `user://save_game.json`
(`SAVE_VERSION = 2`; v1 saves still load, and their missing fields fall back
to the old behaviour). `GameStateManager` keeps a `GameSaveResource` current and
writes it at checkpoints. `SaveManager` deletes the save on `player_destroyed`
(so quitting during the death sequence can't resume it), `game_over` and
`victory`. A fresh run works on a `duplicate()` of `run_start.tres`, never the
cached resource itself.

**Goal: a Continue rebuilds the run exactly.** A fight is never saved
mid-fight. Quitting mid-fight replays it from the last checkpoint, and because
every gameplay RNG stream is saved or reseeded, the replay rolls the same
enemies, intents and dice.

### Checkpoints

| When | `scenario_progress` | A Continue… |
|------|---------------------|-------------|
| Arrival (`start_scenario`), taken synchronously before any ship's arrival effects | empty | rebuilds the scenario from its seed, the same as arriving |
| After a won fight (not the jump gate, which checkpoints on the next sector's arrival) | captured, `cleared = true` | reopens the original scenario with no enemies or salvage; untaken offers come back |
| A reward or shop item taken while out of combat | captured | reopens the scenario as it stood |
| A pickup during a fight | no write | it's saved by the after-combat checkpoint |

`scenario_progress` (see `GameStateManager._capture_scenario_progress()`) holds:
- the scenario id and seed, and the cleared flag;
- ships by `starting_enemies` index (state resource path, HP, shields,
  squad_losses, turns_alive; a missing index means the ship is gone);
- untaken reward offers item by item, and the shop's unsold stock and prices;
- the dice in hand, and tile `uses_remaining`;
- the per-scenario RNG states.

Checkpoints are never taken mid-fight, so a hazard's countdown isn't saved: a
Continue replays the fight, countdown and all, from the top.

Restored ships skip `effects_on_enter`: those already ran and their results
are in the save. The shop reopens from the save instead.

**Dice across a jump.** Only the dice *count* (`num_of_dice`) is run-level
state; arriving rerolls the hand anyway, so faces aren't worth saving. Dice
left on an enemy at a jump lower the count the moment the jump starts, but
nothing is written until the destination's arrival checkpoint (mid-scenario
checkpoints refuse to run while in transit). Quitting mid-jump therefore
reloads the pre-jump checkpoint — the fight being fled, with every die still
owned — and arriving commits the loss. A mid-scenario restore spawns the
saved hand, then tops it up to `num_of_dice`, so a die that was on a tile or
in flight when the save was taken is never lost to it.

**Run-level state** is saved at every checkpoint:
- player stats and the tile layout, including each tile's `effect_data`;
- the map list, index and Fate state (`Map.get_fate_state()`);
- `RunStats`, counting money still in flight as earned;
- the RUN RNG state. RNG states are stored as strings, because JSON rounds
  int64.

### Determinism

`RNGManager` reseeds DICE, ENEMY_AI, TARGETING, REWARDS and BACKGROUND from the
scenario seed mixed with the map slot. Shared ScenarioResources (shops, Fate,
empty) would otherwise share one seed. BACKGROUND is included because a
background can carry a gameplay rule. Shop prices draw from REWARDS, not RUN.

| Resource | Location | Responsibility |
|----------|----------|----------------|
| `GameSaveResource` | `Resources/SaveResources/game_save_resource.gd` | Serializable run state |
| `run_start.tres` | `Resources/SaveResources/` | New-run template (duplicated per run) |

`RNGManager.next_run_seed` queues the seed the next new run starts from, and
`current_run_seed` records the one in use, so any run can be replayed.

---

## Codex

The main menu's CODEX button opens `CodexPopup`
(`Systems/UI/Codex/`): a Tiles tab and an Enemies tab, each a paged 6×4 grid.
An entry the player has found is in colour and can be picked to read about it
in the pane alongside. The rest are redrawn in the palette's greys by
`codex_locked.gdshader` and read "???".

- **What's listed** (`CodexCatalog`): every tile offered as a reward or in a
  ship's starting kit, plus any held-out tile already found, grouped by the
  colour folder of its art; every `EnemyResource` with `in_codex`, by name.
  The position in the list is the entry's number.
- **What's found** (`CollectionManager`, `user://collection.json`): a tile
  once it is on the grid at a checkpoint (`Events.game_saved`), so the
  starting kit, rewards and shop buys all count. An enemy on
  `Events.ship_encountered` and `Events.enemy_destroyed`, which also keep its
  met and destroyed tallies. A Continue that rebuilds a fight doesn't count
  its ships again.
- **Only the player's own runs count.** The Scenario Lab and the AutoPilot
  point `SaveManager.save_path` elsewhere, and `CollectionManager.is_recording()`
  checks for that. Tests use a scratch file (`die_fighter_test.gd`).
- An enemy's page lists its actions once each, with the range its options
  roll (`CodexCatalog.enemy_action_lines`), before run depth scales them.
- An enemy's page shows its full ship art, not the targeting-computer
  silhouette the grid uses: `CodexShipPortrait` instances the
  `ship_graphics_scene` live in a 48x48 SubViewport (engines and moving parts
  included) at the largest whole-number scale that fits; the two ships wider
  than that (Arc Dynamo, the Sector Warden) shrink with linear filtering.

## Tutorial

`TutorialManager` (in main.tscn) narrates the opening ambush, then hands the
run back mid-sector. It's progress, not an option: `Globals.tutorial_completed`
(options file, `[Progress]`, untouched by Defaults; an old `show_tutorial=false`
counts as completed) and `Globals.tutorial_requested` (one new game only: the
main menu sets it, `TutorialManager._ready` clears it, so a Continue, lab or
AutoPilot run is never narrated). Until it's completed, Play skips ship select
and starts the tutorial on the Die Fighter; after that ship select shows a
TUTORIAL button under the ship with `supports_tutorial`.

**Hard-seeded.** The manager sits above GameStateManager in the tree, so its
`_ready` sets `RNGManager.next_run_seed = run_seed` (21) before the run starts.
The map, encounters and backgrounds are the same for every new player (and
the rest of that run too, since the RUN bucket keeps that seed). Content
changes shift what the seed rolls: re-check the jump step's promises after
editing encounter or background pools. Independently of the tutorial, every
sector-1 slot within one jump of `GameSaveResource.arrival_index` draws a
background with no rule and no hazard (`GameStateManager.is_rule_free_slot`),
and an encounter waits for `ScenarioResource.earliest_sector()` (a ship with an
ally-bound action, `Binding.ALLY`, can't appear before sector 2). The
`opening_setup` step then forces the hand (4/2/1) and the raider's intent table,
because both are generated during scene setup, before any ordinary step runs.

**The opening shot.** Every fresh run (tutorial or not) opens with the
ambusher firing once, before the first turn, with one of the player's own
dice; the cannon hands it on to its target as it always does, so it drops
back into the hand. `OpeningStrike` keeps all of its own books, and
GameStateManager only holds one. `owe()` starts the run up to
`OpeningStrike.DAMAGE` (4) over the save's hull, so the shot lands it on
`run_start.tres`'s 24. `arm()` (once the opening ships spawn) gives the first
aggressive ship the die to fly in holding, and the hand is dealt one fewer
while `holds_die()`; with no ship to fire it takes the extra hull back
instead. `play()` (from `Player._announce_first_turn`) fires
`attack_player.tres` for the owed amount. Until the shot lands,
checkpoints save the hull minus `hull_owed()`, so a Continue never replays
the shot or keeps the extra. The action is `load()`ed, not preloaded:
GameStateManager holds an OpeningStrike, and a preload there puts the
enemy-action scripts into their own preload cycle. Continues, gauntlets and
lab runs aren't fresh, so they skip it.
Later steps force the turn-two hand and the salvage (`forced_dice`,
`forced_enemy_actions`, `forced_rewards`). `_finish_tutorial` clears all three
statics.

**Steps** are `TutorialStep` resources played in order. Each opens on one
`TutorialSignals` value and closes on another, and may call one
`TutorialFunctions` entry (lock dice, run the enemy turn, enable the map
arrow...). Both enums are stored as ints in the .tres files, so append only.
- A step that closes on something the player already did (pressed End Turn
  while reading, claimed the reward, opened the map) shows its text and then
  closes itself (`_already_satisfied`), rather than waiting for an event that
  has passed.
- Steps waiting on the player (`_PLAYER_DRIVEN`) never time out. Timing out
  the End Turn prompt, for example, would run the enemy turn without End Turn
  and soft-lock the game. Steps waiting on the game keep
  `default_step_timeout` (or `max_wait_time`) as a backstop, with a warning.
- `test_tutorial.gd` checks every step's text for unknown icon tokens, that
  every close signal is wired, and that main.tscn plays every step file.

**Layout.** The cards sit on the left (`text_position` x around 100) and, for
the opening fight only, the manager reserves screen x 0-180 from the enemy
formation (`popup_screen_span`), so the ambusher stands off to the right. The
enemy highlight masks in `Assets/Textures/TutorialManager/Highlights/` are
drawn for that spot. The reservation is given back on `Events.jump`, so the
next fight's ships fly straight to their usual places. The map's jump arrows
are hidden (`Map.set_jump_arrows_visible`) until the jump step shows the right
one; the left one returns when the tutorial finishes.

---

## AutoPilot (QA harness)

The game playing itself, to find crashes, softlocks and balance problems
faster than playtesting can. `tools/autoplay.sh` launches it; the script's
header lists the options.

**Speed without skipping anything.** Headless runs use `--fixed-fps 60`:
every frame simulates 1/60 s however fast the machine gets through it. Every
tween, timer and await still happens, in order, just compressed, so ordering
bugs between animations and the engine still show up. A run takes seconds.
`TimeDirector.use_frame_clock()` times hitstops and slow-mo by physics frames,
since the wall clock no longer matches game time. `--watch` plays one run in a
window at normal speed.

**Acting like a player.** `AutoPilotMove.list_legal()` lists what a player
could do now: drop a die from the hand on a tile that would take it
(`Tile.activation_refusal()`, the pure half of `clears_activation_criteria()`),
retarget, switch the map/systems tab, take a salvage choice
(`Reward.can_take()`), buy from the shop (`Shop.price_of()`, if affordable),
repair or sell at a repair station, drag a grid tile to another cell out of
a fight (`MOVE_TILE`, a swap if the cell is taken), or press End Turn
(`Player.can_end_turn()`). `perform()` goes through the same entry points as
input. A drop emits the die's `drag_ended`, as letting go of the mouse does;
a claim or a purchase emits the item's over the cell the move names
(`AutoPilotMove.cell`: a tile's cell, the twin it upgrades, or the sealed
cell a Grid Slot opens; the first that fits if it names none), or over the
hand (anything else). The AutoPilot is patient: it waits for
the engine to go idle, for its turn, for a jump from the moment it's decided
(`Player.is_jump_committed()`) until it lands, for the hand to be dealt
(`Player.is_dealing_hand()`), for salvage to show
(`Reward.is_on_its_way()`), for arriving ships to land
(`EnemyManager.arrival_in_progress`: a shop opens, or a toll is taken, only
then) and for the shop's stock to pop onto the shelves
(`Shop.is_revealing()`). An open shop is `Shop.is_open()`: shown and not
closing (on a jump or when the shopkeeper is drawn into a fight, the stock
pops off last-first, the panel folds, and only then does the shopkeeper slide
back; nothing sells meanwhile). At each turn start, arrival and won fight it
spends one frame looking at the board before moving, which is when a replay
takes its picture. Headless runs look too, so both keep the same timing.

**No tutorial.** The tutorial would narrate, lock dice and seed the run
itself. When autoloads are ready the main scene has already entered the tree
but none of it is ready, so the AutoPilot walks the tree in its own `_ready()`
and sets `TutorialManager.auto_start = false` before the tutorial decides
(a `node_added` hook would come too late). A run whose seed isn't the one
asked for is flagged (`run_seed_overridden`).

**Policies** (`AutoPilotPolicy`) pick among the legal moves, or return null
to wait for the board to change, drawing any randomness from the AutoPilot's
own stream, seeded from the run seed. Drawing from a gameplay bucket would
shift every roll after it. `random` plays wherever a die is accepted.

**The smart bot** (`HeuristicPolicy`, `--policy smart`) plays like a player
who knows the basics. It's greedy, with no lookahead: the point is a fixed,
believable standard to measure the random bot against, not strong play.
- **Scoring.** Every die-on-tile is worth what the tile does, less what the
  die costs the ship it's handed to, in points of hull. It tries each living
  ship as the target, and retargets first when another makes the trade
  better.
- **`AutoPilotForecast`** reads what a tile would do off its effect chain,
  without running it. Steps that only read the board (most targeting and
  amount modifiers) go to the real handlers. Everything else is tallied:
  damage by target, shields, heal, charge, statuses, dice coming back, where
  the die ends up (following Feeds) and tricks. Random targets are spread
  over the candidates, so a forecast never draws from a gameplay bucket.
  Reads see the face the die arrived with; the hand-off sees it after any
  change, as the queued events would. A Feed's target is asked whether it
  takes the die with the forecast's own ship as the target (a policy aims
  before it plays), so relays still feed between fights.
- **`AutoPilotThreat`** prices a face: an attack's damage, a share of anything
  else, and a steep toll for a die kept or flown off with. It follows relays,
  Scrambled and Jammed. A hidden ("?") face costs a flat average, so the bot
  never reads what a player can't. That matters out of combat too: a shop is
  a ship, and it shoots the dice it's handed.
- **The rest of the tally.** A kill earns a bonus plus the dice the ship held.
  Shields count in full up to the coming enemy turn's expected hit. Out of a
  fight, charge counts up to a full drive, and it only picks a fight with
  pirates, and only while healthy.
- **The map.** Charged and out of a fight, it always jumps: a die handed out
  with no ship to take it comes home, so the hand never empties and a jump is
  the only way on. It picks the face that lands on the best stop the map
  shows: enemy, elite by hull, unknown, shop by credits, never a tile Fate
  takes next. A small push forward is offset by a cost for each stop it
  skips. Below its style's hull share it flees a fight, but never in a
  gauntlet (`set_may_flee()`).
- **Building the grid** (`AutoPilotBuild`). The board is worth the sum of
  what each tile does with a die, read with the tiles where they stand, so
  a relay counts what it feeds and adjacency tiles count their neighbours.
  Other layouts are tried by swapping them into `TileGrid.tile_locations`
  (and sealed cells into its open set) for one synchronous valuation and
  straight back; only tiles whose chain reads the grid are revalued. A tile
  taken goes in the cell where it adds most, or onto its twin when the
  upgrade is worth more (plus the cell it saves). A Grid Slot opens the
  sealed cell that pays best for the shelf's tiles or the grid's own. Out of
  a fight it drags tiles about (a move or a swap, or two copies merged) while
  a drag gains at least `AutoPilotBuild.MIN_GAIN`.
- **Salvage and shops.** A tile is valued by what it adds in its best cell,
  never off the grid (a relay there has nothing to feed). A Grid Slot is
  worth a tile's room shared over the free cells left; on a full grid in a
  shop, plus the best tile it makes room for. A die is worth less once the
  dice owned outgrow the grid's uses per turn; credits at a flat rate. It
  buys what clears its price.
- **Repair stations.** It repairs below a hull share set by its style, a
  little higher with the sector's gate a few stops off. It sells a tile
  whose credits beat what it adds to the board, or that pays for a repair it
  wants and can't afford, keeping at least three tiles.
- **Two things the legal move list can't see.** A tile showing a Lockout, and
  a placement that bounced back (same die, tile, face, uses and hand).
- **Styles** (`HeuristicPolicy.persona()`) reweigh the same tally:
  `aggressive`, `turtle` (flees sooner, values shields and hull), and
  `synergy` (statuses, dice back, Feeds and tricks).

`autoplay.sh --policy random,smart` plays every seed, or gauntlet cell, with
each policy. The report then adds a Policies table, a gauntlet matrix per
policy, a skill-gap matrix (each policy's clear rate minus random's on the
same seeds) and encounters by policy. A wide gap means a fight rewards good
play; a narrow gap at a low clear rate means good play doesn't save it.

**Isolation.** One run per process. Saves go to the output directory, keyed
by process id. It quits without `QuitManager`, so `times_run` is left alone,
and it unhooks `OptionsSettings` from `Events.save_options_config`, so nothing
in a bot run can write the player's options file. Headless runs free `McpInteractionServer`, so parallel
runs don't fight over port 9090.

**Transcripts** (`<out>/seed_<N>_<policy>.jsonl`): a header, a snapshot at
every player turn (`AutoPilotSnapshot`), every move, arrivals, won fights and
the result (`victory`, `defeat`, `turn_limit`, `stalled`, `looping`, plus
error and violation counts). They hold gameplay state only, never positions
or frame counts, so a seed and policy should always write the same file;
`--determinism` checks, skipping `memory` entries. Money in a snapshot counts
payout coins still in flight (`AutoPilotSnapshot.credits()`), because how
long a coin floats is cosmetic randomness. Each run also keeps the engine's
play-by-play (`seed_<N>_<policy>.debug.txt`, `DebugLogger.start()`) and
console output (`.log`).

**What fails a run.** Besides a stall, a loop or a crash:
- **Errors.** `AutoPilotErrorLog` (an `OS.add_logger()` Logger) catches every
  engine and script error. Each goes in the transcript with its innermost
  GDScript frame, the turn and the move it followed. Object ids are masked so
  replays still match.
- **Invariant violations** (`AutoPilotInvariants`), checked at the moments
  they should hold:
  - At turn boundaries: no overlapping player or enemy turns, no player turn
    mid-jump, and no fight turn starting with an empty hand.
  - At every turn start and settled arrival:
    - Real dice held never exceed `num_of_dice`, and after arriving they
      aren't fewer.
    - The count never drops below 1.
    - Hull, shields, charge and money stay in range.
    - No limited tile reads -1 (unlimited) uses.
  - The counts are taken independently of Player's own bookkeeping, so a bug
    there can't hide itself.
- **Hangs.** `autoplay.sh --time-limit` (default 300 s) kills a run stuck
  inside one frame, which the AutoPilot's own stall check can't catch.

**Memory** is recorded at each arrival (nodes, orphans, objects). A count
more than a limit above the first arrival's gets a `leaks` warning on its
`memory` entry. That's a warning, not a failure: node counts wobble by one
or two between runs of a seed.

A batch ends with a summary: outcomes, violations by check, memory warnings,
and errors grouped by site, each with example seeds to replay.

**Telemetry** (`AutoPilotTelemetry`) tallies balance data off the engine's
`event_resolved` feed, so new content is counted without it learning about
it. Amounts are what resolved, after modifiers (damage before shields; a
change a rule cancels, like Fate's Tithe eating charge, doesn't count):
- **Tiles**, per run in the result: activations, damage, shields, heal,
  charge, status stacks.
- **Enemies**, per run in the result: actions used, damage to the player,
  destroyed, escaped. Damage is credited to "Ship: Action", the action the
  ship was spending; the player's own side hurting them (hazards, the
  redline) is "environment".
- **Visits**, a `visit` entry as each scenario is left: fought (any fight's
  first turn, so a fight fled into counts), result (won, fled, passed, died,
  run_over), turns, hull lost, credits gained, dice lost, salvage offers
  (counted as their choices show; a payout of only credits isn't one),
  claims, buys, damage taken by source.
- **The result** adds the final build, the dice and credits left, and the
  final blow (`killed_by`).

**The report.** `tools/autoplay_report.py <batch>` (standard library only;
`autoplay.sh` runs it after every batch) writes `report.html` beside the
transcripts and prints the headlines. It covers outcomes, encounters ranked
by how often a visit ended the run, final blows, damage by source, enemies,
tiles (per-activation output, and mean fights won by the runs that used
each, a crude lift), and pickups. With the random bot, encounter and enemy
numbers compare well with each other, but tile lift is mostly luck;
gauntlets and the smart bot are what make it meaningful.

**Tile balance.** `--policy smart-randpick` (any style plus `-randpick`,
`HeuristicPolicy.random_picks`) fights like smart but takes salvage at
random, and at a shop buys at random with walking away as one more equal
choice, so whether a run took a tile is a coin flip. Transcripts log every
salvage offer and each stop's shop stock (`offer`, with credits and grid
room) and each arrival's sector and build. `tools/tile_balance.py <batch>`
reads them:
- **Progress** is the furthest map stop, 14 to a sector, a win counting 42.
  The yes/no measure is the next boss: whether a run offered a tile in a
  sector went on to beat that sector's boss.
- **Effect**: at a tile's first takeable offer in a run (room on the grid,
  credits for it), progress gained from that stop and next-boss rate of runs
  that took it minus runs that passed. Only the first chance counts, since a
  repeat offer means the run lasted. "Passed" means taking something else
  (a tile, a die, credits, nothing), so the typical tile sits above zero.
  Compare tiles with each other and with the median.
- **Naive** numbers (runs whose final build had it) sit beside it, to show the
  bias toward tiles picked up late.
- **Usage**: activations per turn on the grid, output per turn and per
  activation, and the share of runs holding it 3+ turns that got nothing from
  it (passive tiles judged by output; boosts, feeds and holograms aren't
  tallied).

**Gauntlets.** `autoplay.sh --gauntlet <spec>` plays every scenario × loadout
in a JSON spec (`tools/gauntlets/`; the format is in
`AutoPilotGauntlet`'s header) on the same seeds, `--seed` up, so a column of
the matrix against another compares loadouts on the same draws. Each run is
one cell:
- The AutoPilot hands `GameStateManager` a save holding only the loadout
  (`Globals.pending_load_save`, the Continue path). With no scenarios in it,
  an ordinary sector is generated around the loadout from the run seed.
  Unset loadout fields come from the flown ship's kit (`--ship=ID`), and a
  loadout tile in a cell that ship lacks is refused.
- From `Events.load_game_save`, which comes before the opening scenario
  loads and before the map is drawn, the chosen scenario takes the starting
  slot and keeps that slot's seed (`place_scenario()`).
- The bot holds its ground: it never drops a die on the map's controls while
  in combat.
- The run ends when the fight is decided: `cleared`, `defeat`, or `fled` /
  `passed` if it was left first. Transcripts are named
  `seed_<N>_<policy>__<scenario>__<loadout>`, and the header records the cell.
The report leads with the matrix: the share of runs that cleared each fight,
the hull those runs lost, and the turns taken.

**Replays.** `autoplay.sh --replay <transcript>` plays a run again in a
window, and `--replay <batch>` does the same for the runs that batch flagged,
worst first. Flagged means no result, stalled, looping, errors or
violations, as `tools/autoplay_replay.py flagged` ranks them.
- **Speed.** `--fixed-fps 60` as in a batch, so the run is the same one, with
  vsync off so it goes as fast as it draws (`--real-time` to watch). The
  transcript header holds everything needed to play the run again: seed,
  policy, and for a gauntlet its spec, scenario, loadout and sector. Extra
  AutoPilot args (`-- --max-turns=...`) have to be given again.
- **Pictures.** `AutoPilotCamera` (`--screenshots=DIR`, windowed runs only)
  takes the board before the first move of each turn, arrival and won fight,
  every error and violation (up to 12), and the end. A capture waits for the
  frame to draw but never holds the bot up, so it can't change the run.
- **Checking.** The replay's transcript is compared with the original:
  REPRODUCED, or DIVERGED with the first entry that differs. A run that
  doesn't reproduce is itself a determinism bug. `shots/index.html` puts each
  screenshot beside what the transcript says happened until the next one,
  and the batch report links any replays made from it.
- **Stopping early.** `--stop-at-turn N` stops as player turn N starts and
  leaves the game open to look around or play on by hand. Replays otherwise
  free `McpInteractionServer` (`--no-mcp`), so a replay can't fight a game
  already on port 9090.

---

## Scenario Lab (dev builds)

A harness for inspecting every scenario by hand, start to finish. The
`ScenarioLab` autoload owns the session and the coverage record;
`ScenarioLabPanel` (in `main.tscn`'s UI layer) is the in-game side, on the dev
console page under the console box. Release builds get neither, unless the export preset has the
`dev_console` feature (`DevConsole.is_available()`).

- **Getting in.** Open the dev console page (the console key) in any run;
  the panel is there with the tile palette. Both start folded away to their
  **SHOW LAB** / **SHOW TILES** buttons and stay as left while the game scene
  reloads (static `collapsed` flags). In an ordinary run the inspector works
  on whatever scenario is live; the navigator starts a lab run, resuming at
  the scenario last tested. There's no main menu entry.
- **A lab run** is a fresh run on the flown ship's starter kit
  (`ShipCatalog.starting_save()`; `Globals.selected_ship`, or the Die
  Fighter), whose
  generated sector gets the chosen scenario in its start slot from
  `Events.load_game_save`, as a gauntlet's does. **<** / **>** step through
  the list, **RESTART** replays the session's run seed (queued through
  `RNGManager.next_run_seed`), **NEW SEED** rerolls it, and **LIST** shows
  every scenario by kind with its coverage. Every scenario under
  `ScenarioResources/Scenarios/` is listed except `test`; a new one shows up
  on its own.
- **Saves.** A lab run saves to `user://scenario_lab_save.json` (via
  `SaveManager.save_path`), so it can't overwrite, or be continued as, the
  real run. The session ends when the menu opens (`MainMenu._ready()`) or a
  game starts without a lab launch pending.
- **Inspector.** Each ship's scenario state, line and exits. A transition's
  event button emits `Events.scenario_event` as play would (every ship hears
  it); a weighted transition lists its outcomes to force on that ship alone
  (`Enemy.force_scenario_state()`). The checklist under it lists every state
  the scenario can reach, and clicking one puts the ship whose branch it is
  into it, which is how to reach a branch a fresh start can't (Tollkeeper and
  Pickpocket take credits on arrival: `add_money` in the console, then click
  the demand state again).
- **Coverage.** `ScenarioGraph` walks every state reachable from the
  scenario's starting ships, through each weighted outcome too, and notes
  whether any of them is hostile. A scenario is fully seen once every state
  has been seen in a lab run, plus its fight ending (won or settled, not
  jumped away from) where it has one. The record is per scenario in
  `user://scenario_lab_coverage.json`, keyed like saved ship states
  (`Enemy.state_key()`); **RESET COVERAGE** in the list clears it.

---

## Player Ships

A run flies one `ShipResource` (`Source/Content/Ships/<id>.tres`), picked on
the main menu's ship-select popup (`Source/Systems/UI/ShipSelect/`) and read
back from the save's `ship_id` on Continue. `ShipCatalog.all()/find(id)` lists
them (loaded at use, never preloaded: a starting kit drags in the effect
catalog). `Globals.selected_ship` is set before the game scene loads, since
`TileGrid` shapes itself from `Globals.current_ship()` in `_ready()`; it falls
back to `die_fighter`.

| Field | Used by |
|---|---|
| `grid_cells` / `grid_size`, `grid_spacing`, `grid_offset`, `hole_column_width` | `TileGrid`: which cells exist (holes allowed), where they're drawn. A column with no cells is drawn `hole_column_width` px wide (-1: full width) |
| `starting_save` | `GameStateManager`: a new run's hull, dice and tiles (stamped with `ship_id`) |
| `behavior_scene` | Instanced as `TileGrid/ShipBehavior` (`TileGrid.ship_behavior`): the ship's own rules and cockpit restyle, hooked to `Events` |
| `hand_may_be_kept` | `Player`: End Turn lights with dice in hand during a fight |
| `supports_tutorial` | `TutorialManager`: the tutorial is written for the default grid |
| `cockpit_scene` | `CockpitMount` (main.tscn, `Graphics/Cockpit`): mounts the ship's `Cockpit` scene, or the default `cockpit_ambience.tscn` |
| `cockpit_palette` | `Cockpit`: recolours the default shell (when the cockpit has no `walls_texture`) and the instruments' frames (`cockpit_surface` sprites) once at load |
| `cutscene_frames`, `cutscene_exhaust_points`, `preview_texture`, `theme_color` | Opening cutscene, ship-select card |

| Ship | Grid | Engine | Behaviour |
|---|---|---|---|
| Die Fighter | 5x3, starting on the middle 3x3 (the outer columns sealed, see Grid Slots) | Engine Charger tile | none |
| Outrigger | two 3x3 pods, x 0-2 and 4-6 (column 3 a 16 px hole) | `OutriggerSail`: dice in hand at End Turn charge the drive by face (to the gate), then go to the target. `SailCatchEvent` per die, `SailSettleEvent` holds the queue until they land | `Outrigger/`: sail, `SailGauge` (mast in the gap; takes the `engine_charger` juice group), `OutriggerPanel` (runtime restyle of the systems panel, frees the charger tile) |
| Carousel | 5x3 minus (2,1): 12-cell ring + hub slots (1,1), (3,1) | The Reactor: the charger tile moved to (2,1), re-dressed with `reactor.tres`; charges, then Feeds up to the ignition slot (2,0). `ReactorIgnitionModifier` points that Feed at the ignition tile | `CarouselBehavior`: turns the ring at `player_turn_refresh` (fight turns after the first) via `TileGrid.relocate_tiles()`, winds it home on `combat_finished`/`jump`; `CarouselTrackLights` |

**Cockpits.** A `Cockpit` (`Source/Systems/Graphics/Cockpit/cockpit.gd`) is
the root of each ship's cockpit scene: the shell (`walls_texture`, drawn by
the shared `CockpitWalls` sprite, which `CockpitWalls.find()` reaches by
group), ambient nodes, a `CockpitDamage` with that shell's breaks, and
`HudSlots` markers. Each marker's name is a group the hull gauge, targeting
computer or status bar joins (`Cockpit.HUD_GROUPS`). The instruments are moved
onto them in the Cockpit's `_ready`, which runs before anything under Systems
is ready, because Graphics comes first in the scene.

| Ship | Cockpit | Instruments |
|---|---|---|
| Die Fighter | `cockpit_ambience.tscn`: the navy canopy, dash LEDs and CRT, hanging dice | hull left, target right |
| Outrigger | `Outrigger/Cockpit/`: gold solar-sail hem across the top, `SailTelltales` (ribbons on the bolt rope, a sun glint), blue pods, teak deck | swapped: target to port, hull to starboard |
| Carousel | `Carousel/Cockpit/`: a gyroscopic viewport, a segmented ring with `ChaseLights` (race on `CarouselBehavior.ring_turned`), gimbal ring and bearing hubs, a `HangingDice` gyroscope | pulled in between the struts |

**Grid Slots.** A ship's layout can start partly sealed: its starting kit's
`GameSaveResource.unlocked_cells` lists the open cells (empty opens them all,
which is also what a save from before Grid Slots means). A sealed cell is kept
out of `TileGrid._cells`, so to placement, adjacency, pushes and Feeds it is a
hole; it is drawn as a hull plate (`locked_cell.png`) over the panel art by
`SealedCellPlates`, a child of the grid that only draws (the plates, the
target brackets, hover, the blow-off) and is told when the sealed set changes. A
`GridSlot` (`Source/Systems/Game/GridSlot/`) is a draggable item: the last
choice of a salvage offer (`RewardResource.grid_slot_probability`, and always
when the grid is full) or a shop shelf (`Shop.GRID_SLOT_PRICE`). Carrying one
lights every sealed cell; dropped on one, `GridSlot.install()` opens it at once
(so the checkpoint the pick triggers saves it) and flies in while the plate
blows off. Salvage and the shop decide whether a drop counts, and hand the
item over, through `OfferIntake` (`refusal()`, `take()`), so tiles, dice and
slots follow the same rules from either. The open cells are saved with each
checkpoint. Loading opens any
cell a saved tile sits on, so a loadout written for the whole grid still loads.

**Tile upgrades.** A `TileResource` may name an `upgraded_version`: a "+"
`TileResource` beside it (`<name>_plus.tres`, `is_upgrade`, never offered).
Salvage and shops offer tiles the player already owns, and a copy let go on an
un-upgraded twin merges into it (`TileGrid.receive_tile` for offers,
`_drop_tile_on_grid_pos` for two copies on the grid): the copy goes and the
twin calls `Tile.upgrade()`, which swaps its resource (uses refill,
`effect_data` stays) and emits `Events.tile_upgraded`. It works on a full grid.
Carrying a copy lights its twin. A tile's info panel previews its upgrade
only while a merge is on the table (`Tile._copy_to_merge_with()`: a copy on
offer, or a second copy on the grid outside a fight).
An upgraded tile sets `tile.gdshader`'s `upgraded` (bright bands chase round
the shared 22x24 silhouette's border) and carries `UpgradeSparks` particles in
its family colour (`ColorSymbolBadge.color_of_tile()`). That look, and the
burst on upgrading, live in `TileUpgradeLook`; Tile keeps the rules.
Likewise the use lights: `TileUseLights` shows `uses_remaining` on the sprite,
popping white sparks off a light that goes out and switching refilled lights
on one at a time as `Juice.gather()` motes fall into each. The count itself
changes at once; only the lights trail it.

`TileGrid.relocate_tiles(moves)` moves many tiles at once (all leave before any
arrive, so a closed loop can shift) and emits no push or manual-move events.
`TileGrid.mirror_of(pos)` is the same row, `x -> grid_width - 1 - x`
(`TARGET_MIRRORED_TILE`, the Crosslink).

---

## Run Progression

A run is `demo_sector_count` sectors long (3 by default). Each sector is
generated by `GameStateManager._randomize_sector_scenarios()` and laid out as:

```
[fate] ... [shops / elites / combat / event mix] ... [boss's jump gate]
```

**Repair stations** (`repair_stations_per_sector`, 1-2) are swapped in by
`place_repair_stations()` after the sector is otherwise built. They replace
combats or events beyond a die's reach of the arrival, never shops, elites,
the arrival or the gate. Placement uses a side generator seeded from the RUN
stream's *state* without drawing from it, so every existing seeded map
(the tutorial's seed 21, AutoPilot transcripts) changes only in the replaced
slots. A new kind of stop added this way stays seed-compatible.

The station itself (`RepairStation`) is a panel like `Shop`, opened and
closed by its scenario ship's state effects (`OPEN_/CLOSE_REPAIR_STATION`),
closed on `Events.jump` and when any ship leaves. It listens to the grid only
while open: `TileGrid.tile_lifted` previews a sale price and
`tile_dropped_off_grid` inside the sell zone sells. The economy is exports on
the node; pure queries (`repair_refusal()`, `sale_refusal()`,
`repair_cost()`, `sell_price()`) let the AutoPilot list legal moves. Shop
prices live in `Shop.PRICE_RANGES` and sales pay half of `Shop.base_price()`.

**Elites** (`elite_scenarios`, `elites_per_sector`) are shuffled in with the
rest and use the purple elite icon. Their ships drop salvage with a raised
`RewardResource.minimum_rarity`.

The **jump gate** is the last tile and is guarded by the sector's boss, so the
boss has to be beaten to leave. Gate scenarios are flagged
`sector_gate_scenario`: `clear_current_scenario_slot()` never empties them, and
Fate stops one tile short of the last index, so the gate is never corrupted.
Winning the fight turns the slot into `Map.open_gate_scenario` (`GATE_open`).

| Step | Where |
|------|-------|
| Boss beaten → ring appears | `JumpGate` on `combat_finished` (or on `start_scenario` at a gate with nothing hostile) |
| Player leaves | `JumpEvent`: forward from the last tile while `JumpGate.is_open()` → `GameStateManager.go_through_gate()`; guarded → "GATE LOCKED" |
| Generate the next sector | `_randomize_sector_scenarios()` (safe to call repeatedly — it resets its own state) |
| Repoint the map | `Map.load_sector()` |
| Play the transition | `JumpManager.jump_through_gate()`: ring passage → white flash → gold hyperspace (`BackgroundManager.set_jump_tint`, `cut_to_hyperspace`) with the sector title |
| Run ends | Last gate: `JumpManager.leave_through_final_gate()` → `Events.victory` → `GameState.VICTORY`, save deleted, summary shown |

A scenario with a `boss_title` plays the `BossIntroCard` on arrival while its
ships are hostile.

The map leads right on its own: the sector's gate sits on the timeline a
slot past its own (`Map.gate_map_icon`, 20x20), mirroring the Black Hole at
the left. It wears `jump_gate_portal.gdshader` (a swirling portal, an
orbiting glint) and two `MapGateAura`s, a breathing halo behind and motes
whirlpooling into it in front. The caption's small `jump_gate.png` wears the
same shader. While the gate is open the portal brightens and the aura
quickens, the caption reads "Jump right!" and the right arrow tile pulses.
Nothing in the sky prompts the player.

**Fate's tiles.** A tile Fate takes becomes `Map.fate_scenario` or one of
`Map.fate_variants` (Fate Rift, Hollows, Maw), picked by `Map._corrupt()`
from a hash of the RUN stream's state and the tile, so no draw is spent.
`Map.is_fate_scenario()` is how anything asks whether a tile is Fate's.
`GameStateManager.fate_scenarios` is not read by anything.

**Difficulty** is two numbers, deliberately separate:

| Multiplier | Applied at | Default per sector |
|---|---|---|
| `get_difficulty_multiplier()` — enemy health & shields | `Enemy._update_health_from_resource()` | +0.35 |
| `get_damage_multiplier()` — enemy intent amounts | `EnemyActionOptionResource.get_action()` | +0.20 |

Damage scales slower than health on purpose: tankier enemies lengthen a fight,
harder-hitting ones can invalidate a defensive build outright.

The **boss is indexed by sector** rather than picked at random
(`gate_boss_scenarios[sector]`, clamped), so the one encounter a player is
guaranteed to meet each sector is also the clearest place to show escalation.
Sector 1 arrives at the authored `starting_scenario`; later sectors arrive at a
random question scenario not already placed in that sector.

---

## Background Layouts and Star Parallax

**Layouts.** A background's planets and stars live in
`set_piece_compositions` (`SetPieceComposition`,
`Resources/BackgroundResources/set_piece_composition.gd`), not
`static_objects`, which stays for pieces that must sit exactly where authored
(the pulsar, the black hole, Fate's weather). On arrival `BackgroundManager`
seeds a private `RandomNumberGenerator` from one `BACKGROUND` draw, picks a
composition by `weight`, then `place()` rolls: a mirror (positions flip and
each node's `scale.x` flips, so the light swaps sides with the layout), a
shared group offset (`offset_jitter`), each piece's own `position_jitter`, a
`size_jitter` (the `CelestialBody` rect resized to an even whole-pixel
diameter, `pixel_scale` to match), one sun height for the whole group
(`light_tilt_jitter`, added to `sun_direction.z`) and each body's face. The
private stream means a scenario seed always gives the same layout, however
many stars or pieces are drawn around it. `test_background_set_pieces.gd`
keeps every layout's worst case out of the column the ships fight in
(x 112-208) and in the top band (centre y at most 64).

**Star parallax.** Each star gets a depth (0.3-1.0): dimmer and slower when
far, and smeared into a whole-pixel streak when fast. How fast a depth-1 star
streams is `_star_stream_speed()`:

| Background | At rest | Jumping (speed above cruise) |
|---|---|---|
| Anything anchors the view: set pieces of any kind (planets, stars, pulsar, black hole, the ion storm, Fate's storm) or scrolling objects | Still: the ship is holding station, and the debris does the drifting | Streams at `(global_speed - cruise) x star_parallax_rate x depth`, settling to still as the outro slows |
| Open space: nothing in `static_objects`, no scrolling objects, an empty (or no) composition, e.g. the star field's open layout | Drifts at `global_speed x star_parallax_rate x depth` | The same formula, so it just speeds up |

`BackgroundResource.anchors_the_view(composition)` decides which row applies.
Cruise is `global_speed` as authored (16); `play_jump_outro()` tweens back to
it. The nebula's own churn and the scrolling objects are unchanged.

---

## Background Hazards

A `BackgroundResource` carries at most one of two things: a permanent rule
(`global_modifier`, a `BackgroundModifierResource`) or a timed hazard
(`hazard`, a `BackgroundHazardResource`): a recurring environmental event with a
first-trigger delay, a repeat interval, and an `EffectChain`. The hazard is
the place's — the Solar Corona's star flares, the Ion Storm Front's clouds
discharge — so it can't be stacked onto unrelated scenery, and the region's art
does part of the telegraphing.

Each hazard has a `timing`. `YOUR_TURN_STARTS` hazards (Solar Flare, Asteroid
Impact) go off as the player's turn starts, after the hand is rolled.
`YOUR_TURN_ENDS` hazards (Ion Storm, Fate Rift) go off on
`Events.enemy_turn_starting`, which `EnemyTurn.play()` emits once
the dice the player spent have landed and before statuses tick or any ship
acts; it then awaits the engine, so the hazard resolves before a ship reads a
die. Dice hazards have to live there: at turn start the hand has only just
been rolled, so re-rolling or flipping it changes nothing. At turn end they
re-roll or flip the dice the player handed over (`ChangeHeldDiceEvent`),
which changes which intents fire, and `enemy_held_dice_changed` moves the
targeting computer's highlight to match. The dice go one at a time, each
ringed in the hazard's colour (the DICE_CONTROL step's `color`) and landing
before the next turns over, so the player can follow which die became what.

`HazardManager` arms on `start_combat` from whatever background is on screen,
disarms on `combat_finished` / `load_scenario` / `jump`, counts down in player
turns and queues a `HazardEvent` onto the live scenario engine, so hazard damage
passes the same modifier pipeline as everything else. A hazard is imminent at
`HazardManager.URGENT_AT` (1) turn left.

The countdown is not decoration — it's the feature's justification. An
unannounced board-wide flare is a dice roll; one the player watched approach
for two turns while deciding whether to spend on shields is a decision. Same
rule the enemy intent telegraph follows. Three things carry it:

- **`EnvironmentMonitor`** swings up on arrival in any region with a rule or
  a hazard, fight or not, and stays until the jump out; nothing shows in
  hyperspace. A hazard shows its icon alone outside a fight, and with the
  turns left beside it once `hazard_armed` starts the countdown. Every tick
  down flashes the unit and pops the digit; at one turn left
  the digit goes red and the lamp keeps blinking even once read; when it fires
  the monitor pops like a tile with the hazard's name as the callout. Clicking
  it explains the hazard and its interval. Each fresh rule or hazard also
  spawns a `RegionAlert` card (unless `Globals.show_region_alerts`, Options >
  Game > Region Alerts, is off). On arrival it is the first beat of the
  `ArrivalIntro`: once the monitor has swung up, the card unfolds out of its
  screen into the empty sky, the cockpit dims slightly, and it holds ~2 s (a
  click anywhere or its Close button skips it; the first time the player ever
  reads a given rule or hazard, recorded by `CollectionManager.record_region`
  as `rule:<file>` / `hazard:<file>`, it has no timer and waits for Close; a hazard's card adds when it next hits, the same
  `EnvironmentMonitor.hazard_timing_text()` line the monitor's info panel shows,
  and holds 1.3 s longer) before folding back in, which kicks the monitor
  and counts as read. A card from a region the player has since left fades or
  lands without effect.
- **`ArrivalIntro`** (`ScenarioManager/arrival_intro.gd`) plays an arrival's
  beats one at a time before `EnemyManager.start_enemy_fly_in` lets the ships
  in: the region card (`Beat.REGION_RULE`), then the `BossIntroCard` band
  (`Beat.BOSS`). Systems `add()` their beat while `start_scenario` is being
  answered; with none, the ships come straight in. A beat is given up on
  after `max_beat_seconds` or when its node is freed, and a jump lets the
  ships go, so nothing can strand them off-screen.
- **`HazardTelegraph`** (`BackgroundObjects/hazard_telegraph.gd`) is the base
  for background art that reacts: `_urgency_changed()` when it becomes
  imminent or calms, `_fired()` when it goes off. The flare star throbs hot
  and its limb erupts, the ion storm strikes more often, the meteor shower
  thickens and sends one rock at the cockpit, the rift tear quickens. The tear
  (`FateRiftTear` + `fate_rift_tear.gdshader`) breathes on its own (rest, open,
  hold, close, durations picked fresh each breath); the build-up tears it wide
  and holds it, the strike rips it past full with a blaze and sparks.
- **The strike gets a build-up.** `HazardManager` emits `hazard_triggered`
  (the monitor pops) and queues a `HazardEvent`. When the engine reaches it,
  it emits `hazard_winding_up(hazard, seconds)` and waits
  `HazardEvent.WIND_UP_SECONDS` (1.6, over animation speed): the `Vignette`
  pulses in the hazard's colour, faster toward the hit, `HazardWarning`
  slams the name across the screen to a quickening thud, and each
  `HazardTelegraph` gets `_winding_up()`. Then `hazard_struck`: telegraphs
  `_fired()`, a screen flash and colour flood, the large camera shake, and
  the hazard's own chain (its damage, sound, glitch).

Encounters built around a hazard point at a one-background pool
(`RandomBackgroundResources/<background>_only.tres`); the general hazard
backgrounds are also in `all_basic_backgrounds.tres`. Authored hazards live in
`Source/Resources/BackgroundResources/BackgroundHazards/`.

---

## Data-Driven Effect System

### 6.1 Components

| Component | Location | Description |
|-----------|----------|-------------|
| `EffectCatalog` | `Source/Behavior/Effects/effect_catalog.gd` | **The single source of truth for effect types.** One row per effect: label, handler class, and the EffectData fields that effect actually reads. The registry, the inspector dropdown and field visibility are all derived from it |
| `EffectContext` | `Source/Behavior/Effects/effect_context.gd` | "Who and what" for effect execution: actor, effect_source, activator_die, targets, repetitions, running_amount, feed_depth |
| `EffectEnums` | `Source/Behavior/Effects/effect_enums.gd` | Owns the category/subtype **ordinals only** — authored `.tres` files store `subtype` as a raw int, so values are append-only |
| `EffectRegistry` | `Autoloads/effect_registry.gd` | Builds its Category/Subtype → handler table from `EffectCatalog`, and runs `EffectCatalog.validate()` at startup |
| `EffectEvents/*` | `Source/Behavior/Effects/EffectEvents/` | Event subclasses per subtype (55+ concrete event types) |

**Adding an effect:** append the enum value, write the handler, add the catalog
row. `EffectCatalog.validate()` fails loudly at startup if those three ever
disagree — previously they could drift silently, and did: six effects existed in
code but were unreachable from the inspector.

A row may set `reserved = true` to hold an ordinal that is deliberately not
implemented. Reserved rows get no handler and are not offered in the dropdown,
so they cannot be authored by mistake, while the ordinals below them stay put.

**Effect Categories**

| Category | Subtypes |
|----------|----------|
| TARGETING | TARGET_ENEMIES, TARGET_PLAYER, TARGET_RANDOM_SHIP, TARGET_RANDOM_OTHER_ENEMY, TARGET_TILE_WITH_OFFSET, TARGET_RANDOM_ADJACENT_TILE, TARGET_BOUND_ALLY, TARGET_BOUND_HOSTILE_SHIP, etc. |
| ATTRIBUTE_CHANGE | DAMAGE, HEAL, SHIELD, CHANGE_ENGINE_CHARGE, STEAL_MONEY (actor takes credits; coins fly from the money counter to it), SIPHON_ENGINE_CHARGE (`SiphonEngineChargeEvent`: drains in up to 3 pulses, each dropping the gauge then streaming motes from it to the actor; one `engine_charge_drained`), ION_DAMAGE (`IonDamageEvent`, a `DamageEvent` with `reaches_hull()` false: `Health.take_ion_damage` strips 2x from shields, the rest is lost), APPLY_STATUS / CLEAR_STATUS / TRANSFER_STATUSES (see 4.5) |
| AMOUNT_MODIFIER | MULTIPLY (a fraction rounds up, away from zero, so every "half of" rounds up), ADD_ADJACENT_TILES, ADD_EMPTY_ADJACENT_CELLS, SET_TO_ENGINE_CHARGE, SET_TO_FEED_DEPTH, SET_TO_ACTIVATIONS_THIS_TURN, SET_TO_DICE_OWNED, SET_TO_DICE_IN_HAND, SET_TO_TARGET_DICE_HELD, SET_RANDOM (`range_min`–`range_max`) |
| DICE_CONTROL | REROLL_ACTIVATOR, FLIP_1S_AND_6S, SPAWN_HOLOGRAPHIC_DIE, KEEP_DIE_WITH_ACTOR, KEEP_DIE_WITH_TILE, MERGE_HELD_DIE, RECEIVE_DIE_FROM_TARGET, FEED_ALLY, SPAWN_HOLOGRAM_FOR_ALLY, REROLL_TARGETS_DICE, FLIP_TARGETS_ONES_AND_SIXES |
| AUDIO_VISUAL | SPAWN_HIT_PARTICLES, ANIMATE_DIE_TO_TILE, PLAY_SOUND, HITSTOP, ZOOM_PUNCH, FLASH_TARGET, SHOCKWAVE, ZAP, STREAM, SCREEN_RIPPLE, etc. (see 4.7) |
| TILE_CONTROL | ACTIVATE_SELF, PUSH_TILE_IN_DIRECTION, PUSH_TARGETED_TILES, PASS_DIE_TO_TILE, FEED_HOLOGRAM, ADD_AMPLIFIER_STATUS |
| SCENARIO_CONTROL | OPEN_SHOP, CLOSE_SHOP, JUMP, FLEE, MOVE_SHIP, ESCAPE_WITH_DICE, LAUNCH_SHIP |
| CONDITIONAL | IF_ACTIVATOR_ODD, IF_ENEMY_TARGETED, IF_ENGINE_CHARGED, IF_TARGET_HOLDS_MATCHING_DIE, IF_FED, IF_SOURCE_HOLDS_DIE, IF_DICE_OWNED_IN_RANGE |
| REPETITION | ADD_REPETITIONS |
| UTILITY | DESTROY_SOURCE, PRINT_DEBUG |

> **Subtype numbering is load-bearing.** `.tres` files store `category` and
> `subtype` as raw ints, so a new value inserted mid-enum silently rewires every
> authored effect below it — with no error anywhere. Always append.

> **Runaway chains.** `ScenarioEngine.process_event_queue()` aborts after
> `_MAX_EVENTS_PER_RUN` (2000) events in one drain and logs the likely cause.
> Without it, two tiles activating each other hard-freezes the game silently.
> Relevant to anything using `ACTIVATE_TARGETED_TILES` or `PASS_DIE_TO_TILE`.

> **Chains and the settle.** `queue_event()` marks a chain start; `inject_event()`
> doesn't. Before popping a chain start, `process_event_queue()` waits the longer
> of the settle the last chain owes (`CHAIN_SETTLE_SECONDS`, 0.2 s over animation
> speed, owed only by chains in `_settles_after()`: tile activations and
> responses, enemy actions, overloads, hazards, arrival effects, root
> `DamageEvent`s) and any `hold_next_chain(seconds)` still running. A queued
> `WaitEvent` stands in for the settle. A ship's death holds the next chain while
> its dice hang at the wreck and cross over (`Dice.hand_off_after_death()`,
> `Draggable.held_by_code` keeps holders from arranging them meanwhile). All of it
> is game time (hitstop freezes it, AutoPilot's fixed fps fast-forwards it), and
> an engine outside the tree never waits.

> **Rules that cap or freeze.** `Modifier.get_tile_use_cap(tile)` lets a rule cap
> tile uses; `Tile.max_uses_per_turn()` takes the lowest cap in play (Dead
> Systems' `OncePerTurnModifier`: every ship system once a turn, engines and map
> arrows immune, refunds blocked). `Modifier.get_rule_info_text(tile)` adds an
> info line from a rule that doesn't own the tile. `EffectEvent.changes_die_values()`
> is the one gate for face changes; Flash Freeze's `DiceFreezeModifier` cancels
> every such event (Scrambled asks `DiceFreezeModifier.active_on()`), calling
> FROZEN off the environment monitor. `EnemyActionSelector` only offers an action
> that vents its own statuses (`EnemyActionResource.vents_own_statuses()`) to a
> ship that has one.

**Flow when EffectChain executes:**

1. Caller builds `EffectContext` (actor, source, die, targets)
2. Iterates through `EffectData` nodes
3. For each, lookup handler in `EffectRegistry`
4. Handler instantiates appropriate `EffectEvent` subclass
5. Event enqueued to ScenarioEngine → modifiers → resolution

### 6.2 Feed and Machine Tiles

A **relay** does its own small effect and then **Feeds** the die: it passes the
die to a neighbouring tile, which activates with it. That lets the player wire
the 3×5 grid into a machine that one die runs through.

- **The Feed rule.** `PASS_DIE_TO_TILE` asks the next tile whether it will take
  the die (`clears_activation_criteria`) *before* passing it. An empty cell, the
  board edge, or a refusal sends the die to the targeted ship through
  `GiveDieToTargetEvent`, the same as any other tile's hand-off. A relay alone
  is therefore an ordinary attack tile; being wired in is how it earns more,
  never a way to get the die back.
- **Feed depth.** `EffectContext.feed_depth` counts how many Feeds carried the
  die to the current tile (0 when the player placed it). `PassDieToTileEvent`
  hands the next `TileActivationEvent` one more than it received. Read it with
  `IF_FED` or `SET_TO_FEED_DEPTH`.
- **Holograms.** `FEED_HOLOGRAM` spawns a holographic die at the tile and Feeds
  it through the same event, so it follows the same rules; an enemy receiving
  it destroys it. It is queued on its tile and taken back out, as a placed die
  is, because `Dice.reroll_with_tween()` reads `host_queue`.
- **Held dice.** A tile can hold a die (`KEEP_DIE_WITH_TILE`); `MERGE_HELD_DIE`
  folds its value into the next die, capped at 6. Anything still held returns
  to the hand on `player_turn_over` and `combat_finished`.
- **Activity.** `Events.tile_activated` fires whenever a tile commits to an
  activation. `TileGrid.activations_this_turn` counts them
  (`SET_TO_ACTIVATIONS_THIS_TURN`), a tile's orthogonal neighbours receive
  `ON_ADJACENT_TILE_ACTIVATED`, and all eight around it receive
  `ON_SURROUNDING_TILE_ACTIVATED`.
- **Die values stay capped at 6.** Nothing overflows.

### 6.3 The Fleet: dice the player owns

Dice persist across jumps (see 8.1). The player's **Fleet** is every die they
own, wherever it is right now, plus the holograms they hold:
`Player.dice_owned()` = `num_of_dice` + holograms in hand or on a tile. A die
handed to an enemy still counts until the player jumps away from it, or
the ship escapes with it (`ESCAPE_WITH_DICE` → `Player.lose_dice_to()`,
the same stranding a jump uses).

"Fleet" is an internal name only. Tile text says "dice in play" with no
keyword, and leaves the player to learn what counts.

| Piece | Reads |
|---|---|
| `SET_TO_DICE_OWNED` | the Fleet |
| `SET_TO_DICE_IN_HAND` | dice still in hand (the activator has already left it) |
| `SET_TO_TARGET_DICE_HELD` | dice the first target is holding |
| `IF_DICE_OWNED_IN_RANGE` | Fleet between `range_min` and `range_max` |
| `DICE_OWNED_AT_MOST` (activation) | Fleet ≤ `threshold`, refusing with "TOO MANY DICE" |
| `RECEIVE_DIE_FROM_TARGET` | moves the target's newest die to the actor (rerolled if the actor is the player) |

Volley tiles (Swarm Battery, Phantom Squadron) set their repetition count
from the Fleet in `repetition_conditions`, behind an always-true
`IF_DICE_OWNED_IN_RANGE 0–99`. A conditional's branches are evaluated before
the events they queue resolve, so a chain can't count holograms it is in the
middle of spawning; compute the count once, up front.

> **Loop rule for authoring.** There is no loop counter. A tile with unlimited
> uses may only Feed **right**; anything that Feeds up, down, left or randomly
> must have limited uses. Every loop on the grid then passes through a limited
> tile and runs dry when that tile refuses. The engine's event ceiling is the
> backstop if a loop is ever authored without one.

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
├── Graphics (Node2D, z_index=-2)
│   ├── Camera2D (zoom=6x, 320×180→1920×1080)
│   │   └── Shakeable (Shakeable component)
│   ├── Cockpit Walls
│   ├── DiceAreaHighlight (shader pulse)
│   ├── CockpitAmbience (lights, vents, hanging dice)
│   │   └── CockpitDamage (hull damage overlays; Destruction plays the death)
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
│   ├── EnemyManager (enemies array, z_index=9: above the main viewer so tractor
│   │                 beams run over the tile grid; drops to -5 while jumping away)
│   ├── RewardManager (z_index=14: offers stay above ships, their HUDs and speech)
│   ├── Shop
│   ├── RepairStation
│   ├── ScenarioManager
│   ├── JumpManager
│   ├── TutorialManager
│   ├── GameStateManager
│   └── GameAnimationPlayer (fade animations)
├── PauseLayer (CanvasLayer 100, follows the camera)
│   └── PauseMenu
└── CursorLayer (CanvasLayer 128)
    └── MouseCursor
```

Screen layers in draw order: world (0), `UI` (1, which holds the glitch
shader), Juice overlays (90), `PauseLayer` (100), `CursorLayer` (128).
Anything that should draw over a screen-reading effect has to sit on a later
layer than that effect, not just at a higher z_index.
`test_screen_layers.gd` pins this order.

### 7.2 UI Interaction Patterns

**Drag & Drop (Dice/Grid)**

- Uses `Draggable` component on Dice and Tile
- `draggable.drag_ended.connect(drop_handler)`
- `draggable.set_home(pos, announce_arrival)` moves where it floats back to;
  only with `announce_arrival` does `reached_new_home` fire when it settles
  (a tile landing in a new grid cell thumps, one placed by code doesn't)
- Click placement (`Draggable.placement_mode`, the Dice Placement option):
  one click picks up, the next drops through the same `_end_drag()`, so every
  drop rule applies. The drop point comes from the click event, not the OS
  mouse. `put_back()` cancels by dropping at `home_position`, which every
  drop handler reads as "no move"

**Click-to-Show (Targeting)**

- Click enemy → `Events.enemy_received_die` → update intent dice textures
- Click action indicator → show action info

**Tab Switching**

- MainViewer toggles between SYSTEMS and MAP views
- `Events.show_systems.emit()` / `Events.show_map.emit()`

---

### 7.3 Cockpit Damage

`CockpitDamage` (`Graphics/Cockpit/CockpitDamage/`) shows the player's hull
on the cockpit. Each child `CockpitDamageSite` is one full-screen overlay
(a canopy crack or a split frame seam) with `emit_points` for its particles.
Sites open in child order as hull falls, evenly spread over the hull below
`intact_from` (`sites_open_at()`; 75%, so a new run's 60/80 shows nothing), and close in reverse on a heal. A hit or heal animates
(debris in, green sparks out); a hull set directly (load, new run) snaps. A
hull hit of at least `big_hit_fraction` of max billows smoke from torn seams,
and open seams keep leaking a thin trail. The smoke is `smoke_puff-Sheet.png`
(three puffs, one picked per particle) growing as it rises. A plume's size
scales smoothly with `billow_intensity()`, which blends the size of the hit
(`big_hit_fraction` to `huge_hit_fraction`) with how dire the hull is
(`dire_at()`, building from `dire_from` of the bar lost). The lingering trail
also thickens as things get dire. All the knobs are exports on CockpitDamage.

A new crack holds for `crack_hold_time`, then fades over `crack_fade_time`
to a ghost at `crack_ghost_alpha`. The torn seams and their smoke carry the
lasting "hull is low" signal, and the glass marks the moment of a big hit. A crack
knocks glass loose: `CockpitGlassShards` simulates the shards (CPUParticles2D
can't collide) as they tumble, land, bounce once, glint and fade. They land
on the first opaque pixel below them of the `Cockpit Walls` texture, or of any
Sprite2D in the `cockpit_surface` group (the hull gauge and targeting
computer backgrounds, which stand in front of the dash). A panel moving away
drops whatever was resting on it. To make another sprite catch glass, add it
to that group.

The art is `Assets/Textures/UI/Cockpit/Damage/cockpit_damage.aseprite`, one
layer per site, exported with
`aseprite -b cockpit_damage.aseprite --split-layers --save-as "{layer}.png"`.
To add a site, add a layer, export, add a `CockpitDamageSite` child in
`cockpit_damage.tscn` at the point in the order it should open, and set its
`kind` and `emit_points`.
The smoke puffs and glass shards are `smoke_puff.aseprite` and
`glass_shard.aseprite` beside it, one frame per variant, exported with
`aseprite -b <name>.aseprite --sheet <name>-Sheet.png --sheet-type horizontal`.

On death, the killing blow's cracks open straight to their ghosts and any
still fading are dimmed. During the rupture, `CockpitDestruction` brings each
crack back in its opening order (`crack_return_at()`, gaps shrinking), each
with a `glass_crack` and a spill of shards. Then the shell blows apart and the
shards are blown away with it. It also ruptures every site, cuts the `Cockpit Walls`
texture into fragments and throws them, and the player's panels, clear,
then emits `game_over`. By then the fight has already stopped:
`player_destroyed` shut the engine down, so an enemy turn in progress ends
without starting another player turn, while ships, shots in flight and the
background carry on.

### 7.4 Options, Display and Input

**Options.** `OptionsSettings` registers every option in `_register_*_options()`
functions (one per area), and `OptionsMenu._build_pages()` builds every tab
from `OptionsPage` row helpers (`check`, `choice`, `slider`, `button`,
`custom`, `note`, `next_column`, `enable_when`). A row writes through
`set_option()` and re-reads through `refresh()`, so the menu shows live
values after Defaults or a change made elsewhere. `OptionsFrame` draws the
panel to fit however many tabs there are. To add an option: one `register()`
call, one row, and its label and hint keys in `translations.csv`.

**Pixel-perfect fullscreen.** The game is a 1920x1080 canvas
(`ScreenFrame.SIZE`: Globals.SCREEN_SIZE through the 6x cameras). Godot can't
scale it by k/6 (content_scale_factor clamps below 1; integer stretch counts
multiples of 1920x1080), so `PixelPerfectScaler` switches the window to
canvas_items stretching with a base of six window sizes and factor k: the
canvas scales by exactly k/6 and renders at native resolution. The window then
shows extra canvas around the frame: a mask layer (127) blacks it out,
CanvasLayers in the `frame_ui` group (main.tscn's UI layer) are offset onto
the frame, and anything keeping itself on screen (dropdowns, damage numbers,
`JuicePixelated`) measures against `ScreenFrame.canvas_rect()` /
`rect_in_viewport()`, not the viewport. It applies only in fullscreen and
rechecks on size and mode changes (macOS reports fullscreen a few frames
after the resize).

**Comfort.** `Globals.screenshake_intensity` scales every shake, zoom punch and
ripple (`Shakeable` shakes take a strength). Reduce Flashing goes through
`Juice.soften_flash(strength)` for sprite flashes and
`Juice.screen_wash_alpha(alpha)` for full-screen washes: new flash code
should use one of them. `TimeDirector.hitstop_enabled` gates hitstop.
`BackgroundFocus` (Display/) mutes with a -80 dB Amplify on Master (never the
Mute All flag) and opens the pause menu on focus loss, only in a live run.

**Accessibility visuals.** `ColorSymbolBadge` (Content/Tiles/) reads a tile's
colour family from its art folder (`<Colour>Tiles`) and draws its glyph:
`attach_to_tile_sprite()` from `Tile`, `attach_to_rect()` for TextureRects
(codex, info panel). `FontSwap` (Display/) swaps the `base_font` of the
wrappers `m3x6_ui.tres` / `m5x7_ui.tres` between the pixel fonts and the
readable font; text must use the wrappers, never the .ttf files
(`test_font_swap.gd` checks). CJK/Cyrillic fonts should go in as fallbacks on
the wrappers, fitted with `tools/fit_readable_font.py`. Atkinson is imported
as MSDF at `msdf_size` 192 (64 stair-stepped under nearest filtering at 6x),
and while readable `FontSwap` sets each wrapper's `baseline_offset` so
capitals centre where the pixel fonts' do.

**Held things and the cursor.** `Draggable.held` / `holding()` say what's in
hand (drag or click placement), and are the only record of it: the cursor,
the map's panning and hover all ask `holding()`. A press calls
`Draggable.begin_drag()`, which code can call too to put something straight
in the hand (the tile palette). Code taking a held thing over by setting its
`state` lets go of the hold in the setter, so the lift and wiggle never
outlive it. `MouseCursor` shows a fist while something is
held, with an "i" badge while a click-placed tile is still over its lift spot
(`is_over_info_spot()`, the click that puts it back and opens its info). The
first three click pick-ups each launch show a one-line hint.

**Targeting computer attitude.** `AttitudeDisplay` (under TargetingComputer)
shows the target's attitude as a 5x6 face and tints the bezel and portrait
frame (two white masks) red / grey / green; it blinks when the targeted ship
changes its mind. Enemy health bars no longer carry a face, and their backing
has a soft `CEF0F1` outline. `HullInfoArt` draws the hull info panel's picture
from the live hull (ring share + 3x6 digits); `ShieldInfoArt` does the same
for the shield panel, drawing the live shield count in those digits, tinted
blue, on `shield_info_base.png`.

**Controllers and rebinding** (Systems/Input/). `VirtualCursor` turns stick
and d-pad into a pointer (in frame units, clamped to the frame, real time),
warps the OS mouse and feeds real mouse events to `Input`, so clicks, drags,
hover and physics picking all work unchanged. `InputBindings` lists the
rebindable actions, serializes their events (one option per action,
"Controls/bind_<action>", defaults from project.godot) and resolves clashes
by swapping. `BindingSlots` is the Controls tab row.

## Core Classes Reference

### 8.1 Player (`Systems/Game/Player/player.gd`)

```gdscript
@export var num_of_dice: int          # Dice count → determines max_engine_charge
@export var engine_charge: int        # Max: max(1, (6*(num-1)) - floor(1.7078 * sqrt(num)))
var dice_manager: DiceQueue           # Queue node with drag management

func spawn_dice(num_to_spawn, value=0, holographic=false) -> void
func dice_owned() -> int              # The Fleet: num_of_dice + holograms held
func reroll_dice() -> void            # Tween each die with sound SFX
func end_turn() -> void               # Emit player_turn_over when queue empty
func can_end_turn() -> bool           # Whether End Turn (button or hotkey) would take a press
func commit_to_jump(die) -> void      # JumpEvent: the player is leaving; lock the hand and End Turn
```

**Turn Logic**

- `Events.load_scenario` → seed RNG
- `Events.jump` → the dice ride the jump. Dice in hand, held by a tile, or on
  the tile that fired the jump come home and are locked until arrival. Dice
  an enemy holds are **stranded**: pulled out of every queue and the `Dice`
  group, reparented to the ship so they ride it off screen, and subtracted
  from `num_of_dice` (a "LOST" / "-N DICE" callout says so). Holograms fizzle.
  Dice with no `host_queue` (shop stock, salvage) go with the scenario. A
  shrinking dice count stops a full drive at the new gate rather than
  redlining it.
- `Events.start_scenario` → arriving keeps the carried dice and rerolls them,
  spawning only to reach `num_of_dice` (first scenario, Continue from an
  arrival, a die bought since); a mid-scenario Continue rebuilds the saved
  hand instead
- Ships alive when a fight ends hand their dice to the player (not to each
  other), and a sector advance waits two frames for them before jumping
- `Events.player_turn_refresh` / `player_turn_start` → refill tile uses, reroll dice, enable dragging
- `Events.first_turn_start` → a fight's opening turn, which has no
  `player_turn_start` (that beat follows an enemy turn). Player emits it once
  per fight: after the hand is dealt for a fight that opens with the scenario,
  or on `start_combat` for one that breaks out mid-scenario. Tiles treat it as
  `ON_TURN_START`, so Pilot Light, Skeleton Crew and Static Bloom go off on
  turn one. `first_turn_start` waits for `Events.enemies_arrived` (emitted by
  `EnemyManager.start_enemy_fly_in()` once every ship has landed and
  `TargetingComputer.ensure_target()` has run), so combat-start effects never
  fire at ships still flying in. Nothing else listens: hazard countdowns, enemy intents and
  temporary modifiers already ran for that turn. `start_combat` alone isn't
  enough, because fleeing one fight into another never leaves IN_COMBAT
- `Events.tile_activation_complete` (from tile grid) → check empty queue, enable end-turn button

**When End Turn works.** Only while it's the player's turn to end. It stays
off from the press until their next turn starts, while a fight's ships fly in
(before `first_turn_start`), and from `commit_to_jump()` until arrival.
JumpEvent calls that the moment a jump is decided, before `Map.jump()` pans
the map, so no enemy turn can start in a scenario being torn down. The hotkey
follows the button (`can_end_turn()`). An enemy turn hands the turn back
(`_start_player_turn()`) only if no fight started and no jump was committed
since End Turn (`_turn_generation`): a fight can break out partway through an
enemy turn run out of combat, and it opens with its own first turn. End Turn
is also re-checked as every turn starts: a turn can open with the hand
already spent (the last die on a tile that holds it, like a Welder), with no
activation to come that would light it.

**The spare die.** The player always has a die to play. At each turn start,
and once a fight ends, `_ensure_a_die_to_play()` checks for a die in hand or
in a tile's queue (judged by queue membership, after beams land and the
chain finishes, since a die in flight still points at the queue it left). If
there's none, the player gets one with a "SPARE DIE" callout
(`CALLOUT_SPARE_DIE`): a real die if `num_of_dice` exceeds the real dice still
held anywhere (a Cutpurse fled with the rest; the count never drops below
one), otherwise a hologram (ships hold them all). A hologram doesn't count as
owned and fizzles at the jump, so it can't be banked, and it's enough to shoot
the holder down and get the dice back.

### 8.2 Tile (`Source/Content/Tiles/tile.gd`)

```gdscript
@export var uses_remaining: int                  # Decrements on activation; refilled each player turn
var effect_data: Dictionary[String, int]         # Tile-specific state (turns_since_last_active, etc.)

func clears_activation_criteria(die: Dice) -> bool   # Checks uses, then every ActivationResource
func handle_tile_event(tile, event_type, immediate = false) -> void  # Queues the matching event_responses chain (immediate: right after the current event)
func reset_uses_remaining() -> void                  # On start_scenario and player_turn_refresh
func get_held_die(except: Dice = null) -> Dice       # A die this tile is holding, if any
func release_held_dice() -> void                     # Held dice back to the hand (turn over / combat finished)
var on_offer: bool                                   # Shop stock or salvage: takes no dice, ignores events
```

**Tiles on offer.** The shop and salvage create tiles with `on_offer = true`
until `TileGrid.receive_tile()` installs one. Until then it takes no dice
(its `CanAcceptDice` is disabled) and `handle_tile_event()` ignores the game,
so an unbought tile can't be played for free and its passives don't work
from the shelf.

**Activation Check Resource**

- `ActivationResource` checks the die and the game state before a use is spent
- Examples: specific values, requires a die / takes no die, in combat, enough engine charge

### 8.3 TileGrid (`Source/Systems/Game/TileGrid/tile_grid.gd`)

```gdscript
var grid_width: int = 5
var grid_height: int = 3
var grid_spacing: int = 24
var tile_locations: Dictionary[Vector2i, Tile]  # Coordinate → Tile mapping
var activations_this_turn: int                  # Tile activations this player turn

func receive_tile(tile, drop_position) -> void     # Drop from outside grid into cell
func move_tile(tile, new_pos) -> void              # Swap or move to new cell
func push_tile(tile, direction) -> void            # Cardinal push (Asteroids style)
func can_push_tile(tile, direction) -> bool        # Whether that push would move anything
func find_available_grid_pos() -> Vector2i         # First empty cell, top row first
func is_grid_pos_valid(pos) -> bool                # An open cell of the ship (not a hole, not sealed)
func get_cells() -> Array[Vector2i]                # Every open cell
func set_open_cells(open) -> void                  # Seals the rest of the layout (empty: all open)
func get_locked_cells() / is_cell_locked(pos) / locked_cell_at(global_pos)  # Sealed cells
func unlock_cell(pos, plate_delay = 0.0) -> bool   # A Grid Slot opens a sealed cell
var plates: SealedCellPlates                      # Draws sealed cells; plates.show_targets(shown) while a slot is carried
func merge_target_at(tile, global_pos) -> Tile     # The un-upgraded twin a copy dropped there upgrades
func relocate_tiles(moves) -> void                 # Many tiles at once (the Carousel's ring)
func mirror_of(pos) -> Vector2i                    # Same row, mirrored across the grid
func remove_tile(tile) -> void                     # A tile leaving for good (sold): releases dice, forgets the cell, frees it
# signals: tile_lifted(tile), tile_dropped_off_grid(tile, position), cell_unlocked(cell)
```

### 8.4 Enemy (`Source/Content/Enemies/enemy.gd`)

```gdscript
@export var enemy_resource: EnemyResource          # Base stats, graphics, action options
@export var scenario_state: ScenarioShipState      # Runtime state (faction, attitude)
var turn_actions: Array[EnemyActionResource]       # 6 pre-chosen actions per turn
var last_damaged_by: Node                          # Who landed the latest hit (see Ship vs ship)

func generate_turn_actions(situation) -> void      # Roll 6 slots (call EnemyManager's instead)
func threat_of_face(face: int) -> Threat           # What a die does here, following any relay
func run_turn() -> void                            # Use all dice in queue sequentially
func get_status_bar() -> StatusBar                 # Where status badges go (beside the health ring)
```

**Action Selection**

`EnemyManager` rolls every ship together, in roster order: on spawn (once
the whole roster is in), on `player_turn_start`, and for a table that holds
something unsafe when `combat_finished` hides intents again. Rolling is
`EnemyActionSelector` (RNG bucket `ENEMY_AI`), reading an
`EnemyActionSituation` built per ship: its allies and the ships its faction
preys on (`FactionRelations`), its hull, its attitude, and whether intents
are visible (`GameStateManager.enemy_intents_visible()`, read off the roster
because `state` is stale while a new scenario's ships roll).

- 6 action slots per enemy per turn
- Action options with weights (likelihood)
- `force_include` forces specific actions (used by tutorials, and to guarantee
  exactly one of a signature verb appears — weight 0 plus `force_include` means
  "one and only one")
- Weighted random fill remaining slots
- **Kept faces:** a `fills_kept_faces` option is never rolled into an ordinary
  slot. `KeepDieWithActorEvent` records the die in `Enemy.kept_dice`
  (cleared when the ship next acts), `EnemyActionSituation.kept_faces` reads
  the ones still held, and the selector rolls and places the rest of the
  table around those faces before inserting one copy on each. Dice a ship
  was merely handed don't count. The Siege Mortar's Siege Shot exists only
  this way: it's always the payoff of a die left in Charge Bore.
- **Gates read off the chain**, like threat: an action that flees or jumps
  (`is_safe_while_hidden()`) is never rolled while intents read "?", so a ship
  can't leave on a die the player couldn't read. An action that binds a ship
  (`get_binding()`) needs one to exist. A gated `force_include` is skipped;
  a pool with nothing left fills with Do Nothing.
- **Authored on the option:** `conditions` (`EnemyActionCondition`: ally
  exists or is hurt, prey exists, own hull below a share, attitude; each can
  be inverted) must all hold, and `situational_weights`
  (`EnemyActionWeightRule`) scale the weight while a condition holds.
- **Which face each action lands on** is `EnemyResource.face_bias` (a pool
  can override it with `EnemyTurnActionList.override_face_bias`); the
  default, 0.5, leans every enemy gently toward high faces. At 0 the
  rolled actions are shuffled as they always were, draw for draw. Otherwise
  each sorts onto faces 1–6 by `randf() + face_bias × rank`, where rank is
  its place in the table by `placement_strength()`: the threat tier (or the
  option's `strength_tier_override`), then the rolled amount. Positive puts
  the strong actions on high faces, negative on low; it tilts the odds
  rather than fixing them.
- **Variety cap:** `EnemyActionSituation.max_action_kinds` (from
  `GameStateManager.get_action_kinds_cap()`, i.e. `action_kinds_per_sector`,
  `[2, 3, 0]` by default; 0 is no cap) limits how many different actions one
  table mixes. `EnemyActionVariety.limit()` runs on the available options
  before the fill: a kind is an action's `name`, blank faces (Do Nothing) and
  kept-face payoffs don't count, and the tutorial's forced slots keep their
  kinds. The kinds kept are drawn each turn without replacement, weighted by
  how many slots each would fill (one per `force_include`, plus its share of
  the weighted fill), and options of the other kinds are dropped whole,
  `force_include` ones too. When nothing needs trimming it draws nothing, so
  an uncapped roll is unchanged draw for draw. `reroll_slot_without_relays()`
  only brings in a new kind while the table has room for one
  (`within_table()`). Boss-faction ships (`EnemyActionSituation.is_boss()`)
  get `boss_bonus_action_kinds` (1) more wherever a cap applies; no cap stays
  no cap.

**Bound targets.** An action that acts on another ship picks it when the slot
is rolled, not when the die is spent: `EnemyTargetBinder` sets
`EnemyActionResource.bound_target` once every table is in, and
`TARGET_BOUND_ALLY` / `TARGET_BOUND_HOSTILE_SHIP` read it. The description's
`(target)` token names the ship, and while an enemy is targeted (in a fight)
the targeting computer draws a `BoundIntentArrow` to each ship its slots are
bound to: a dotted arc over the ships, green to an ally and red to prey,
landing on the bound ship with a pixel arrowhead. A badge near the top of the
arc shows each thing the arc carries (the die faces that buy it, the intent
icon, the amount); slots with the same icon and amount share one. A slot the
ship holds the die for, or is playing now (`TargetingComputer.is_slot_live`),
lights its face, and the dots march toward the target; otherwise the arc sits
dim and still. Badges sit short of the arc's middle, toward its left end,
since every ship carries its hull badges on its upper left. Bindings never move and the action is
never rerolled once the player can see it: if the bound ship leaves, the
slot can't happen any more (see Action outcome below).

**Action outcome.** `EnemyActionResource.get_outcome()` (null-safe
`outcome_of()`) asks whether spending a die on an action would change
anything *right now*: `ACTS`, `IDLE` (never does anything: Do Nothing, an
empty slot, a chain of only visuals and a hand-off) or `BLOCKED` (means to
but can't: a step aimed at a bound ship that's dead or gone, a heal on an
undamaged bound ship, `LAUNCH_SHIP` with the hangar full). Unlike Threat,
which is static and read off the chain once, the outcome reads the board
every time. `EnemyActionEvent.settle_action()` swaps a `BLOCKED` action for a
copy of Do Nothing (the "..." callout, the die handed back) and pops the "?"
icon (`IntentIndicator/blocked_info.png`) instead of the action's own.

**Relays.** Relay (`FEED_ALLY`) hands the die on, and Holo Loader
(`SPAWN_HOLOGRAM_FOR_ALLY`) conjures a hologram whose face is its intent
amount; either way the bound ally spends it at once. Loops are ruled out at
selection: each (ship, face) is a node, a relay slot is its one edge to the
(ally, face) the die lands as, and the binder only binds a relay where
walking forward can't come back to it. When no ally qualifies, that one
slot is rerolled with relays excluded, so the graph stays loop-free by
construction with no retries. `relay_visited` on the events is the backstop
(Scrambled can flip a die in flight). Hologram faces aren't scaled by the run's
damage multiplier.

**Ship vs ship.** `DamageEvent` records `last_damaged_by` and emits
`ship_attacked_ship` when one enemy hits another; `ScenarioManager` turns
pirate fire on a civilian into `ScenarioEvent.PIRATE_ATTACKED_CIVILIAN`. A
ship killed by another ship (`was_killed_by_ship()`) drops no reward, plays
no kill-confirm, pays no faction bounty and doesn't count toward RunStats.

**Stealing and escaping.** The Cutpurse's Pilfer keeps the die
(`KEEP_DIE_WITH_ACTOR`) and is also its `fills_kept_faces` option, so a
stolen die lands on Pilfer again every turn and never comes home while the
ship lives; killed, it gives its dice away as any ship does. From its fourth
round (`COMBAT_ROUNDS`) the kept-face option is Getaway instead:
`EscapeWithDiceEvent` strands every die it holds, the one being spent
included, drops the player's `num_of_dice` by the real ones, emits
`enemy_left` and flies the ship off the top of the screen. It reads as
DANGEROUS and, like Flee, is never rolled while hidden.

**Launched ships.** `LAUNCH_SHIP` calls `EnemyManager.launch_ship()`: a new
`Enemy` of `EffectData.ship_resource` goes into the roster right after its
launcher (formation order), shares the launcher's scenario state, rolls a
table at once and slides out of the hull to its slot. It has no
`reward_resource` (`Enemy._on_death` skips the payout) and `spawn_index` -1,
so saves leave it out. `has_room_to_launch()` caps the board at
`max_ships_in_combat`; the Carrier's Launch option is also gated on
`ALLIES_AT_MOST`.

**Overload.** A ship with `EnemyResource.overload_threshold` > 0 checks the
face total of the dice it holds (`held_heat()`) at the start of its turn. At or
over its current `overload_threshold`, `run_turn()` queues an `OverloadEvent`
instead of its actions: every die vents home, `overload_chain` plays, and the
threshold grows by `overload_threshold_growth`. An `OverloadGauge` under the
ship shows held/threshold.

**Hulls (ships made of parts).** `ScenarioResource.hull` (a
`ShipHullResource`) gives a scenario one big untargetable body, and starting
ships flagged `mounted` are its parts at `mount_offset`. Parts are ordinary
Enemies, pinned out of the formation and never bobbing on their own.
`HullMounts` (`EnemyManager/hull_mounts.gd`, owned by `EnemyManager`) builds
the hull, seats the parts on the `ShipHull` every frame, flies it in first,
moves it with them on a jump, scars each lost part's socket (`ShipHull.scar`),
breaks it up with the last (`break_up`), and holds and releases the formation
space the hull and its parts take.

**Which pool a turn draws from** is set by `EnemyResource.pool_selection`:

| Mode | Index |
|---|---|
| `TURN_CYCLE` (default) | `turns_alive % pool_count` — rhythms like charge/fire |
| `HEALTH_THRESHOLD` | health bar mapped onto the pools; full HP → first, near death → last |
| `SQUAD_LOSSES` | how many of its own faction have died this fight |
| `COMBAT_ROUNDS` | rounds elapsed since it arrived, fed or not — a real timer |

None of these cost anything from the perfect-information pillar: the six
resolved slots are still shown in full before the player commits a die. Only
the *table they were drawn from* changes.

---

## Signal Bus (Events.gd)

### 9.1 Combat Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `start_scenario` | Begin new scenario | Player (spawn dice), EnemyManager, TileGrid, Tutorial |
| `player_turn_refresh` | Just before `player_turn_start` | Tiles refill uses, TileGrid resets its activation count |
| `player_turn_start` | Player begins turn | Dice reroll, enable dragging, update UI |
| `player_turn_over` | Dice queue empty | Start enemy turn |
| `enemy_turn_over` | All enemies out of dice | Loop to player turn |
| `start_combat` | Enter combat state | Disable map switch, update UI colors, targeting computer reveals intents |
| `combat_finished` | Combat ends (all enemies gone) | Re-enable grid dragging, unlock engine charge, EnemyManager rerolls survivors' unsafe tables |
| `jump` | Hyperspace jump begins | Carry the player's dice, strand the ones enemies hold, reset player state |
| `sector_advanced` | A new sector has been generated (zero-based index) | RunStats |
| `player_destroyed` | Player hull hit zero | GameStateManager (GAME_OVER, shuts the ScenarioEngine down), Player (locks the hand, End Turn), SaveManager (deletes save), CockpitDestruction (plays the death, then emits `game_over`) |
| `game_over` | The cockpit has finished coming apart | GameOver screen, TimeDirector, DebugLogger |
| `victory` | Final sector's jump gate cleared | GameOver screen, SaveManager (deletes save), GameStateManager |
| `hazard_armed` / `hazard_countdown_changed` | Background hazard armed for a fight (null: stopped) / ticked | EnvironmentMonitor, HazardTelegraph |
| `hazard_triggered` | Hazard fired | EnvironmentMonitor, HazardTelegraph, camera shake |
| `enemy_turn_starting` | Enemy turn about to run: spent dice have landed, nobody has acted | HazardManager (turn-end hazards) |
| `enemy_held_dice_changed` | A die an enemy holds changed face | TargetingComputer intent highlight |

### 9.2 Player Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `die_added` | Dice spawned/rerolled/dropped | Update dice queue layout, engine charge (out of combat) |
| `DiceQueue.die_received(die)` (per queue, not the bus) | Fires in `add()` just before `die_added` | Hand and `EnemyDiceManager` call `Dice.reset_visual_state()`, the one place a die's rotation/scale is reset when it changes hands |
| `set_money` | Money changed | Update UI display |
| `player_health_hit` | HP damage taken | SFX + large shake + glitch (if critical) |
| `player_shields_hit` | Shield damage taken | SFX + small shake |
| `player_shields_broken` | Shields hit zero (protected → exposed) | Large shake + long cyan vignette |
| `player_fatal_damage` | Hull reaches 0, before death is declared | Tiles (`ON_PLAYER_FATAL_DAMAGE`, which can save the player) |
| `engine_charge_changed` | Engine charge changed | Update engine bar, map unlock indicators |

### 9.3 Tile Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `tile_manually_moved` | Player drops tile at new cell | Tile activation event |
| `tile_pushed` | Grid push mechanic | Tile activation event |
| `die_placed_on_tile` | Die accepted on tile | Tutorial logging |
| `tile_activation_complete` | Tile effect chain finished | Check end of turn (dice queue empty) |
| `player_turn_over` | End turn pressed | Tiles release held dice |
| `tile_activated` | A tile committed to an activation (use spent) | TileGrid activation count, neighbours' `ON_ADJACENT_TILE_ACTIVATED` / `ON_SURROUNDING_TILE_ACTIVATED` (injected, so each hop of a relay chain gets its own response) |

Tiles also respond to `TileEvent.EventType` hooks via `event_responses`:
`ON_TURN_START`, `ON_TILE_PUSHED`, `ON_TILE_MANUALLY_MOVED`,
`ON_ENEMY_TURN_OVER`, `ON_PLAYER_HEALTH_HIT`, `ON_ENGINE_CHARGE_DRAINED`,
`ON_ADJACENT_TILE_ACTIVATED`, `ON_SURROUNDING_TILE_ACTIVATED`, `ON_PLAYER_FATAL_DAMAGE`. Most of these enable
tiles that take **no dice at all** and pay out reactively — they cost a grid
cell instead of a die. `TileEvent.EventType` is stored as a raw int, so append
new values; `ON_PLAYER_FATAL_DAMAGE` is pinned at `= 100` to leave room.

### 9.4 Enemy Signals

| Signal | When Emitted | Listeners |
|--------|--------------|-----------|
| `enemy_received_die` | Enemy gains die in turn | Update targeting intent dice UI |
| `enemy_used_die` | Die used for action | Pulse intent indicator |
| `enemy_left` | Enemy removed (death/flee) | Remove from array, faction check (bindings to it stay put and become `BLOCKED`) |
| `ship_scenario_state_changed` | A ship moved to another scenario state (an event, or the Scenario Lab forcing one) | GameStateManager rechecks combat; ScenarioLab records coverage |
| `ship_attacked_ship` | One enemy damaged another | ScenarioManager (`PIRATE_ATTACKED_CIVILIAN`) |
| `enemy_flew_in` | New enemy enters screen | Re-enable bobbing animation |
| `enemies_arrived` | Whole opening fly-in done and a target is set | Player releases `first_turn_start` (Pilot Light etc.) |
| `ship_encountered` | A scenario's starting ships spawned (not on a Continue that rebuilds them), or a ship launched mid-fight | CollectionManager (codex) |
| `enemy_destroyed` | A ship died, to anyone (`enemy_left` also fires for one that fled) | CollectionManager (codex) |

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
│  EffectChain → EffectContext → EffectRegistry → EffectHandler      │
│             → EffectEvent subclasses → ScenarioEngine.inject_event()│
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
│    ├── debug_log_format.gd     # DebugLogger's line wording
│    ├── screenshotter.gd
│    ├── quit_manager.gd
│    ├── effect_registry.gd
│    ├── content_registry.gd
│    ├── rng_manager.gd
│    ├── save_manager.gd
│    └── mcp_interaction_server.gd
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
│   │   ├── EnemyActions/enemy_action_selector.gd  # Rolls a ship's six slots, with gates
│   │   ├── EnemyActions/enemy_action_situation.gd # The board as one roll sees it
│   │   ├── EnemyActions/enemy_target_binder.gd    # Binds slots to ships; keeps relays loop-free
│   │   ├── EnemyActions/enemy_action_condition.gd # Authored gates / weight rules (+ _weight_rule.gd)
│   │   └── ... action/resource files ...
│   │
│   └── ScenarioResources/
│       └── scenario_resource.gd                   # Per-scenario data
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
│   │   ├── EnemyManager/enemy_formation.gd     # Derives ship placement from roster + free screen space
│   │   ├── TargetingComputer/targeting_computer.gd  # Intent display
│   │   ├── MainViewer/main_viewer.gd           # Systems/Map tabs
│   │   ├── ScenarioManager/scenario_manager.gd # Faction events
│   │   ├── ScenarioManager/faction_relations.gd # Who fights alongside / preys on whom
│   │   ├── ScenarioEngine/                     # Combat processor
│   │   │   ├── scenario_engine.gd              # Core engine
│   │   │   └── effect_event.gd                 # Event base class
│   │   ├── EngineCharger/engine_charger.gd     # Engine charge UI
│   │   ├── Dice/dice.gd                        # Die behavior & RNG
│   │   └── RewardManager/reward_manager.gd     # Tile unlocks
│   │
│   ├── keywords.gd                            # Keyword tokens + hover definitions
│   ├── utils.gd                               # format_text (colours, die icons, keywords)
│   │
│   ├── UI/                                    # Interface nodes
│   │   ├── InfoShower/info_shower.gd           # Hover info display
│   │   ├── PauseMenu/pause_menu.gd             # Pause/Quit UI
│   │   ├── Mainmenu/main_menu.gd               # Title screen
│   │   └── ... other UI files ...
│   │
│   │   ├── JumpManager/jump_manager.gd          # Hyperspace transition
│   │   ├── HazardManager/hazard_manager.gd      # Background hazard countdown
│   │   ├── RunStats/run_stats.gd                # End-of-run tally
│   │
│   ├── TutorialManager/tutorial_manager.gd     # Tutorial state machine
│   ├── GameStateManager/game_state_manager.gd  # State transitions, sectors
│   └── Background/
│       ├── background_manager.gd               # Parallax layers
│       └── BackgroundObjects/hazard_telegraph.gd  # Base for art that reacts to a hazard
│
└── Behavior/Effects/                          # Data-driven effect system
    ├── EffectEvents/                          # Event subclasses (55+)
    │   ├── AttributeChange/damage_event.gd
    │   ├── TileControl/tile_activation_event.gd
    │   ├── TileControl/pass_die_to_tile_event.gd   # Feed
    │   ├── TileControl/feed_hologram_event.gd
    │   └── ...
    ├── EffectChain/effect_chain.gd       # Chain runner
    └── effect_context.gd                      # Context for effect execution
```
