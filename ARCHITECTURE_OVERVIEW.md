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
| `RNGManager` | `Autoloads/rng_manager.gd` | Owns all RNG "buckets" (`RUN`, `DICE`, `ENEMY_AI`, `TARGETING`, `REWARDS`, `BACKGROUND`, `COSMETIC`, `EVASION`); keeps gameplay randomness reproducible from a seed, cosmetic free-running; re-seeds on `Events.load_scenario` |
| `SaveManager` | `Autoloads/save_manager.gd` | Single autosave slot to `user://save_game.json` (JSON, `SAVE_VERSION = 2`); deletes save on `player_destroyed`, `game_over` and `victory`; `GameStateManager` keeps a `GameSaveResource` current and calls `write_save()` at checkpoints |
| `CollectionManager` | `Autoloads/collection_manager.gd` | What the player has found across every run, for the codex: tiles they've owned, enemies met/destroyed and region rules/hazards read. Kept in `user://collection.json`, outside the run save (see Codex below) |
| `OptionsSettings` | `Autoloads/options_settings.gd` | Registry of player options (see 7.4): each registered once with its default and how to read and apply its live value, keyed "Section/name" as saved in `user://options_settings.cfg`. Loads and applies them at boot, saves on `Events.save_options_config`, resets them for the menu's Defaults. Owns `PixelPerfectScaler` and `BackgroundFocus`. Also holds the `times_run` counter. Window options (size, monitor, vsync, pixel perfect) aren't registered on the web (`controls_window()`) |
| `Localization` | `Autoloads/localization.gd`, tools in `Systems/Localization/` | The game's language: the locales offered (`get_available_locales()`: every `LOCALE_NAMES` entry, never the pseudo-locale), `is_translated()` (≥90% of English's messages; drives the Options "(English text)" mark and the first-launch pick), registering each language's UI translation at startup, `set_locale()` at runtime (`Events.locale_changed`; `allow_pseudo` for the debug pseudo-locale `en_XA`), and the debug `OverflowWatcher`, made on demand by `watch_overflow()`. See 7.5 |
| `MCPInteractionServer` | `Autoloads/mcp_interaction_server.gd` (the Godot MCP tool also writes a gitignored copy to the repo root on each run) | TCP server on port 9090 for external MCP interaction; runs `PROCESS_MODE_ALWAYS`. Editor-launched runs only: in any exported build (debug or release) it frees itself without opening the port |
| `AutoPilot` | `Autoloads/auto_pilot.gd`, helpers in `Systems/AutoPilot/` | Plays runs by itself for QA and balance testing (see AutoPilot below). Editor binaries with `-- --autoplay` only; otherwise it frees itself |

**Core Game Systems** (Scene-organized with singleton references)

| System | Scene/Node | File | Responsibility |
|--------|-----------|------|----------------|
| `GameStateManager` | `Systems/GameStateManager` | `GameStateManager/game_state_manager.gd` | State machine: OUT_OF_COMBAT → IN_COMBAT → GAME_OVER / VICTORY; has its child `SectorGenerator` (`Game/SectorGenerator/sector_generator.gd`, which holds the encounter lists) deal each sector, elites and a boss-guarded gate included; advances to the next sector through the open gate (`go_through_gate()`), owns the run's difficulty multipliers |
| `Player` | `Systems/Player` | `Systems/Game/Player/player.gd` | Player ship with health/shields/dice queue; manages turn flow: spawn dice, reroll, end turn |
| `TileGrid` | `Systems/Player/MainViewer/TileGrid` | `Systems/Game/TileGrid/tile_grid.gd` | The ship's grid (3x5 by default; see Player Ships), tile placement/snap logic, push mechanics, per-turn tile activation count |
| `EnemyManager` | `Systems/EnemyManager` | `Systems/Game/EnemyManager/enemy_manager.gd` | Spawns/enemy management; runs enemy turns sequentially via dice queue; places ships along the spawning path via `EnemyFormation`, spacing each by its footprint (hull plus side-hung health bar; on a board too crowded for that, every bar tucks above its hull) and splitting the wing across free space either side of a reservation such as salvage, which also turns each ship's speech box toward its clearer side; waits for in-flight tractor beams (`TractorBeam.wait_for_landings`) before an enemy turn starts |
| `Map` | `Systems/Player/MainViewer/Map` | `Systems/Game/Map/map.gd` | Hyperspace map with waypoint selection, fate corruption zones (rules in `FateState`, `Map/fate_state.gd`), sector gate jumps |
| `ScenarioManager` | `Systems/ScenarioManager` | `Systems/Game/ScenarioManager/scenario_manager.gd` | Per-scenario event dispatch; faction tracking (PIRATE/CIVILIAN/BOSS); combat resolution logic |
| `TargetingComputer` | `Systems/Player/TargetingComputer` | `Systems/Game/TargetingComputer/targeting_computer.gd` | Enemy intent display: shows die → action mapping for currently targeted enemy. `target_for(die)` answers who a dropped die should hit. The reticle is placed every frame from its ship's live position (so it rides a slide), and a real target change resets every running intent pulse. The targeted ship's speech folds into the portrait's comms badge (`EnemyDialogueManager.stow_point`) and a click unfolds it again (`replay_last_line()`); the badge shows only while a line is tucked away |
| `JumpManager` | `Systems/JumpManager` | `Systems/Game/JumpManager/jump_manager.gd` | Plays the hyperspace transition (intro → load scenario → outro → start). Public `jump_to_scenario()`, used both by map jumps and sector advances |
| `JumpGate` | `Graphics/JumpGate` | `Systems/Game/JumpGate/jump_gate.gd` | The ring at a beaten sector gate: warps in clear of salvage, `is_open()` gates the way out, plays the passage, owns the white flash and the sector title |
| `HazardManager` | `Systems/HazardManager` | `Systems/Game/HazardManager/hazard_manager.gd` | Runs the current background's `BackgroundHazardResource` for the length of each fight: arms on `start_combat`, counts down at each turn start (or, for `YOUR_TURN_ENDS` hazards, each `enemy_turn_starting`), queues its chain onto the engine, broadcasts the countdown |
| `RunStats` | `Systems/RunStats` | `Systems/Game/RunStats/run_stats.gd` | Tallies sectors reached / encounters cleared / ships destroyed / credits earned for the end-of-run summary |
| `FactionStanding` | `Systems/FactionStanding` | `Systems/Game/FactionStanding/faction_standing.gd` | Keeps the run's `FactionLedger` (how each faction regards the player, deeds done, kills) current from `ship_deeds_done` and `enemy_left`, and hands it to each checkpoint. See Faction Memory |
| `FateLedger` | `Systems/FateLedger` | `Systems/Game/Fate/fate_ledger.gd` | The run's memory for Fate: Fate's Die and carvings waiting for a choice, every ship the player destroyed, the ships they saved or spared, and deeds. Saved as `GameSaveResource.fate_state`. See Fate's Die and the Reckoning |
| `ReckoningDirector` | `Systems/ReckoningDirector` | `Systems/Game/Reckoning/reckoning_director.gd` | Runs the secret fight while its scenario is loaded: Fate's throws, the queue of the run played backwards, allies, "You", the escape on the engine charger, and how the fight ends (RECKONING_ENDINGS.md) |

**UI Systems**

| System | Scene/Node | Responsibility |
|--------|-----------|----------------|
| `InfoShower` | `UI/InfoShower` | Click-to-show info panel (title, activation, description) with tween animation. An `InfoResource` with `upgrade_*` fields shows the thing and its upgrade side by side, an arrow between. `side_label_text` is an aside column right of the art (in the side-by-side layout it goes under the current description). Keywords in it are hoverable and pop up their rule. While open it consumes Esc (`PauseMenu` action) to close itself, so the pause menu doesn't open |
| `OverheadConsole` | `Systems/Player/OverheadConsole` | A display hanging from the canopy ceiling in the top-left. It waits out of sight and drops down while any readout holds it there (`request_down(reason, wanted)`): the `MoneyIndicator` credit readout in its case (from the run's first credits, or the first payout coin taking off, for the rest of the run; a loaded save holds it down if `run_stats.credits_earned` or the balance is above 0) and the `EnvironmentMonitor` flap under it (a region rule or hazard). Coins aim at `MoneyIndicator.coin_target()`, its resting place, so they meet it even while it's still dropping |
| `PlayerHealthBar` | `Systems/Player/PlayerHealthBar` | HP/shields UI with reveal animations |
| `EngineCharger` | `Systems/Game/EngineCharger` | Engine charge bar (recharges when not in combat) |
| `PauseMenu` | `PauseLayer/PauseMenu` | Pause state toggle, save/quit, option screen |
| `GameOver` | `UI/GameOver` | Game over **and** victory sequence, with the run summary line |
| `MainMenu` | Root scene (`main_menu.tscn`) | Start game, options, wishlist link |
| `MenuCaravan` | `UI/MainMenu/MenuCaravan` | The menu's backdrop: Caravan ships (`CaravanShipKind`s, borrowing combat sprites) flying an editable `Path2D` past and behind the planet, sized per route point (`point_depths`). Drawn into a 320x180 viewport; each whole-pixel width is its own sprite from `PixelArtShrinker`. Ships can be taken off the route and flown by hand (`take_off_route`, `add_ship`, `pixel_on`), and `add_overlay` draws over them |
| `CaravanStraggler` | `UI/MainMenu/MenuCaravan` (child of `MenuCaravan`) | Every 50–100 s a mid-sized Caravan ship breaks down and drifts out of the column; an Undertow Gaff shoots its lights out, hooks it and tows it off the bottom of the screen. One coroutine (`play()`) with its own timers |
| `FateBehind` | `main_menu.tscn` (ColorRect, `fate_behind.gdshader`) | The rim of Fate over the bottom of the menu: black horizon, swirling purple rim, dithered glow behind the title |
| `TutorialManager` | `Systems/TutorialManager` | Seeded first-run tutorial: step popups over the opening fight, and a ghost cursor acting out a step's drag or click |

**Background & Visuals**

| System | Scene/Node | Responsibility |
|--------|-----------|----------------|
| `BackgroundManager` | `Graphics/BackgroundManager` | Parallax layer manager: black holes, nebulae, stars, shader planets and suns (`CelestialBody`) laid out from a picked `SetPieceComposition`, scrolling objects (debris, asteroids, ice, scrap, fate shards, embers, ion motes); see Background Layouts and Star Parallax |
| `Vignette` | `Graphics/Vignette` | Flash overlay for camera shake/impact emphasis |
| `Juice` | `Systems/Graphics/Juice/juice.gd` (static helpers) | Bumps, wiggles, rings, sparkles and callouts; see 4.7 |
| `JumpFx` | `Systems/Graphics/JumpFx/jump_fx.gd` (static helpers) | The jump drive: charge motes, flare, stretch, streak, ring and sparks, and the jump-in that reverses it. Shared by the opening cutscene and departing enemies (`Enemy.jump_away`, see 8.4) |
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

**Caps.** A clamping modifier that cuts an amount calls
`event.cap_amount(capped, self)` rather than assigning `amount`. That records
`EffectEvent.capped_from` (the amount before the first cap; later caps don't
overwrite it) and `capped_by`, so popups can show the cut ("12→3"):
`uncapped_for_popup(shown)` / `uncapped_gain_text()` give the leading figure
and `cap_color()` is the capping modifier's `get_trigger_color()`.
`AmountCapModifier` (Doldrums) answers that from its rule resource's `color`.
`DamageNumber` draws the arrow in pixels (`_CapArrow`), so no font needs a →
glyph. Ion damage and the player's own heals and shields show no cut.

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
- **Ids:** a status is a `StatusResource` (a `KeywordResource` with
  `modifier_script`, `color`, `icon` and `info_icon`) in the keywords folder;
  its file name is the id. `StatusCatalog` finds them through
  `Keywords.keyword()` and builds the modifier with
  `StatusResource.create_modifier()`, which sets `StatusModifier.definition`
  (whence `status_id`, `color`, `icon` and `info_icon`, read-only getters). A
  status built bare (a test's) has no definition and shows nothing. A
  content test checks every authored id against the catalog.
- **Rule numbers** are constants the hook uses (`BurnStatus.LOST_PER_TICK`,
  `JammedStatus.SPENT_PER_DIE`, `WeakenedStatus.MIN_HIT`, ...), returned by
  the script's static `rule_values()`. `StatusResource._text_tokens()`
  passes them to `TextTokens` (7.5), so the rule's `{spent}` is the number
  the code spends.
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
- **Badges:** each status shows a `StatusBadge` (icon + stack count, its
  "{n} stack/stacks" a `tr_n()` plural, 7.5) on its
  ship's `%StatusBar`: beside an enemy's health ring, above the player's
  (two to a row, clear of the Outrigger's wider panel). Clicking one shows its rule in the info panel:
  `rule_term()` returns the keyword id, `<id>_you` (`Keywords.PLAYER_SUFFIX`)
  where the player's side differs. The hull panel lists the player's
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
instead, for a player status that acts there. On the player either one also
flashes the status's badge (`StatusBadge.play_alert()`: two bright swells).
A player status that *causes* something (Burn's tick, Jammed, Scrambled)
awaits `play_player_alert()` in its hook instead, which holds the event for a
beat: badge flashes, the name pops (off the tile, or off the badge), then the
effect lands. Burn on the player therefore burns down as its tick hit comes
up (`on_before_event`, priority 0), not in the tick, so the badge shows the
stacks about to burn until the damage lands. Statuses that only resize a hit
already in flight (Exposed, Weakened, Phased) flash without holding it, since
a pause between a shot's impact and its number would read as lag. The beat
is skipped on an engine outside the tree (unit tests).

**Adding a status:** subclass `StatusModifier` (`priority` and the hook;
tuning numbers as constants returned by a static `rule_values()`), and add a
`StatusResource` whose file name is the id, naming the script and holding
the name (`title`, which `display_name()` reads), rule (numbers as
`{placeholders}`), tokens, colour and icons. Decide what it does on the
player (`player_rule` if that reads differently). Nothing to register.

### 4.5.1 Evasion

**Location:** `Source/Behavior/Modifiers/EvasionModifier/evasion_modifier.gd`

A charged drive makes the player harder to hit. Each enemy hit on the player
has `EvasionModifier.chance_percent()` chance to miss: 3% per point of engine
charge, up to 50%. Charge past the gate (redline) adds nothing.
`ScenarioManager._load_scenario` puts one on every fresh engine, so it is a
standing rule rather than something a tile grants, and there is no badge.

- **The roll:** priority 2, behind Phased (1, a sure miss that shouldn't
  waste a roll) and ahead of the death save (5). Only a `DamageEvent` with an
  `Enemy` actor, a positive amount and the player among its targets is
  rolled for. A miss takes the player out of the targets, like Phased, so
  shields, death saves and `player_attacked` never see it. At 0% nothing is
  drawn. Rolls come from their own `RNGManager.Bucket.EVASION`, seeded per
  scenario and checkpointed, so a replay dodges the same hits and a miss never
  shifts the enemies' own rolls.
- **Feedback:** a big `EVADED!` callout (`CALLOUT_EVADED`) over the health
  bar and the Engine Charger tile (`EvasionModifier.engine_display()`: the
  Outrigger's thrust gauge stands in), plus a purple vignette pulse.
- **Display:** `get_rule_side_text()` puts the sum (`INFO_ENGINE_EVASION`,
  "Engine charge x 3% = Evasion, up to 50%") and the live chance
  (`INFO_ENGINE_EVASION_NOW`, or `_NOW_BONUS` while tiles have added some)
  in the side column of the Engine Charger's info panel, so its description
  stays one centred block. The panel's picture is the live gauge
  (`EngineChargeInfoArt`, via `Tile.info_picture`). The Outrigger has no
  charger tile, so its pilots don't see the number. `(evasion)` is a keyword
  that only says what evasion does; the sum lives on the tile.
- **Tiles:** `ATTRIBUTE_CHANGE/ADD_EVASION` (`AddEvasionEvent`) adds
  percentage points (`bonus`) until `enemy_turn_over` or `combat_finished`,
  still held to the cap; not amplifiable. The `EVASION_BELOW_CAP` activation
  check refuses a die at the cap. A miss emits `Events.player_evaded(attacker)`,
  which tiles hear as `ON_PLAYER_EVADED` with the attacker as the starting
  target. Juke Thrusters, Afterimage, Slipstream Vane and Feint Cannon build
  on it.
- **AutoPilot:** the forecast and threat model ignore evasion for now, so the
  bot neither values Juke Thrusters nor discounts incoming hits by the chance.

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
| `EnvironmentMonitor` | `mod` is `BackgroundModifierManager.get_active_modifier()` | the same pop as a tile: squash on the hinge, flare, ring, sparks, the rule's `trigger_sfx` (else the monitor's chime), callout of the rule resource's `display_callout()` ("x2", "NO SHIELDS") in the rule's colour. Fires even while the monitor is still blinking unread |
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
`GRAPPLE` (Seize) is its own `GrappleHandler`/`GrappleEvent`: the die sets
off toward the player's hand and a `JuiceGrapple` claw on a tether catches it
45% of the way, and the bite plays slowed (`TimeDirector.slow_mo`) while the
die struggles in the grip, tugging for the hand three times, before it's
reeled back in front of the ship. The claw is grey palette metal with a gear
hub and purple circuit lights (cable pulses, knuckles, the gear's core), so it
reads against the white die. The claw moves the die
itself in its own `_process` rather than by Tween, because tweens step after
every node's `_process` and the redraw it queued is already flushed, so a
claw drawn from a tweened die trails it by a frame (on the fast reel it
showed on the wrong side of the die). The event waits out
`JuiceGrapple.duration()` on a pausable timer, not the claw's signal, so a
claw freed with its ship can't strand the chain.
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
sequence and its explosion render on the 320x180 grid. `SCREEN_RIPPLE` honours the screenshake setting.
A `CALLOUT`'s words are `EffectData.callout`, content text (7.5): `JuiceHandler`
translates them, then fills the tokens. `string_param` is never shown. Where every
sound should go is in `SOUND_EFFECTS.md`.

---

## Data-Driven Content System

### 5.1 Resources ( `.tres` files)

**Content hierarchy:**

| Resource | Location Pattern | Purpose |
|----------|------------------|---------|
| `TileResource` | `Source/Content/Tiles/TileResources/*.tres` | Defines tile behavior, textures, uses per turn, activation criteria, effect chains |
| `BackgroundHazardResource` | `Source/Content/BackgroundResources/BackgroundHazards/*.tres` | A timed environmental event that belongs to a background (solar flare, ion storm, asteroid impact, fate rift): timing plus an `EffectChain` |
| `EnemyResource` | Embedded in enemy instances | Base stats, graphics scene, dice queue position, action options weight list |
| `EffectChain` | `TileResource.effect_chain`, `event_responses`, enemy actions, hazards | Ordered list of `EffectData` entries dispatched through `EffectRegistry` |
| `KeywordResource` | `Source/Content/Keywords/KeywordResources/<id>.tres` | A game term: title, rule, optional player-side rule and its `KeywordToken` spellings (5.3). A status is a `StatusResource`, a keyword that also names its script, colour and icons (4.5) |
| `ActivationResource` | In TileResource.activation_checks | Criteria checks: requires a die / takes no die, specific values, in combat, a ship targeted, engine charged / not charged, can afford N charge, overcharged, Fleet of N or fewer, evasion below its cap |

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

The three text fields are content text (7.5): display code reads
`display_name()`, `display_activation_description()` and
`display_description()`, never the fields. The descriptions write their
numbers as `{placeholders}` bound to the steps that hold them
(`EffectData.text_token`), which the accessors fill through `TextTokens`
(7.5); `_text_tokens()` adds the tile's own `{countdown}`.

Uses are a **per-turn budget**. Bigger payoffs are meant to carry a cost other
than uses (engine charge, hull, a die, neighbours' uses), not a once-per-fight
limit.

### 5.3 Keywords

`Keywords` (`Source/Systems/keywords.gd`) serves the game's terms, read lazily
from `KeywordResource`s in `Source/Content/Keywords/KeywordResources/`. The
file name is the id (`feed`, `burn`, `hologram`), and every lookup goes by
id, never by English. A keyword has a `title`, a `rule`, an optional
`player_rule` (served as `<id>_you`, `Keywords.PLAYER_SUFFIX`, for a status
that works differently on the player) and its `tokens`: embedded
`KeywordToken`s, one per spelling written into descriptions (`(feed_right)`,
`(burn)`, `(jammed_you)`), each with a `label`, an optional palette `color`
and `player_side`. All of the text is content text (7.5), keyed by position
(`KEYWORD.FEED.TOKENS_0.LABEL`). `display_rule()` / `display_player_rule()`
fill the rule's `{placeholders}` through `TextTokens.fill(text, self)` from
the keyword's `_text_tokens()`; a `StatusResource` (4.5), the keyword that
is a status, returns its script's `rule_values()`, so a rule never types a
number the code applies (a test fails on a digit outside yellow die faces).
`Keywords.keyword(id)` returns the resource itself.
`Utils.format_text()` renders each token as a styled label. The info panel
asks for hoverable labels (`format_text(text, true)`), which wrap each in a
`[url]` tag whose meta is the id. `InfoShower` listens for
`meta_hover_started` on its labels and pops up `Keywords.definition(id)`,
titled `Keywords.title(id)`, beside the cursor, so no rules are on screen
until the player asks. `definition()` also serves the status badges. Add a
keyword by adding a file (CONTENT_BUILD_GUIDE §9).

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
- untaken reward offers item by item, and the shop's unsold stock and prices
  (plus its reroll count, which sets the next reroll's price);
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
- the `FactionLedger` (`faction_standing`): standing, deeds and kills per
  faction. A deed done after a checkpoint is lost with the rest of the
  replayed fight and recorded again when it replays;
- the escort riding with the player, if any (`escort_state`, see Escorts);
- the RUN RNG state. RNG states are stored as strings, because JSON rounds
  int64.

### Determinism

`RNGManager` reseeds DICE, ENEMY_AI, TARGETING, REWARDS, BACKGROUND and EVASION
from the scenario seed mixed with the map slot. Shared ScenarioResources (shops, Fate,
empty) would otherwise share one seed. BACKGROUND is included because a
background can carry a gameplay rule. Shop prices draw from REWARDS, not RUN.

| Resource | Location | Responsibility |
|----------|----------|----------------|
| `GameSaveResource` | `Resources/SaveResources/game_save_resource.gd` | Serializable run state |
| `run_start.tres` | `Resources/SaveResources/` | New-run template (duplicated per run) |

`RNGManager.next_run_seed` queues the seed the next new run starts from, and
`current_run_seed` records the one in use, so any run can be replayed.

---

## Tile Unlocks

A new player is offered only the **Basic** tiles: every offered tile in no
`TileFamilyResource` (61 at launch). The rest are in eight families under
`Source/Content/Tiles/TileFamilies/`, unlocked one per new sector reached
(sector 2 and 3 of every run) in the order `tile_unlock_order.tres` lists
them. Reordering that list is the whole of changing the order; a player keeps
what they have and gets the first family in the list they lack.

| Piece | Job |
|---|---|
| `TileFamilyResource` | Name and description keys, accent colour, `tiles`. Its filename is its saved id. |
| `TileUnlocks` (static) | `filter_pool()` for `RewardManager.get_possible_tile_rewards()` (rewards, shop, AutoPilot all read it), `unlock_for(claim)`, `tiles_opened_by(family)`. |
| `CollectionManager` | Keeps unlocked family ids in `collection.json`, each with the claim that earned it. |
| `JumpManager._unlock_tile_family()` | In `jump_through_gate()`, after the sector title: unlocks, queues one of the new tiles in `Reward.forced_rewards`, shows `TileUnlockPopup` and waits for Close before the next sector loads. |

- **A tile sits in one family**, since the card shows every tile its family
  lists. One that leans on two mechanics (Echo Relay, Fuse Payload) is in the
  later family; reordering the list can break that, so check those when you
  move a family. `test_tile_families.gd` fails on a tile in two families.
- **Once per sector.** The claim is `run seed:sector index`, so a Continue
  that replays a gate jump shows the same family again rather than a second
  one. The run seed rides in the save's `rng_states` (`RUN_SEED`) for this.
- **Only the player's own runs are gated** (`CollectionManager.is_recording()`).
  The Scenario Lab and the AutoPilot see every tile and unlock nothing, so
  balance batches don't depend on the machine's profile.
- New tiles join offers straight away, including the sector just entered.
- Dev console: `families`, `families unlock <id|next|all>`, `families reset`,
  `families show <id>`. The options menu's Unlock All unlocks every family;
  Erase Progress locks them again.

---

## Ship Unlocks

A ship with `starts_locked` (the Outrigger) is earned once, in any run, and
kept for good. Until then its ship-select card is greyed out with its
`unlock_hint`, a rumour of how to earn it, and can't be launched.

| Piece | Job |
|---|---|
| `ShipUnlocks` (static, `Systems/Game/ShipUnlocks/`) | `is_pickable(ship)` (not `coming_soon`, not locked; `ShipCard` reads it), `is_locked(ship)`, `unlock(id)`, `scenarios_for_sector(i)`, `die_earns(ship, die)`, `earned_by_die(die)`, `counted_by_face(face)` |
| `ShipUnlockDirector` (`Systems/Game/ShipUnlocks/`, `Systems` in `main.tscn`) | Earns the ships the run's die earns (`unlock_face` at least `unlock_face_count` times) on `Events.game_over` / `Events.victory`, once, and 1.4 s later shows each card on a `CanvasLayer` of its own (layer 90, `follow_viewport_enabled`, above `UI` where `GameOver` is), processing while paused. Calls out `unlock_carve_hint` under the die (`FateDieDisplay.die_position()`) after each carving of a counted face. Shows a card in an unrecorded run without earning, for the Scenario Lab |
| `CollectionManager` | Keeps earned ship ids in `collection.json` (`ships`). `record_ship()` records only in the player's own runs (`is_recording()`); Unlock All and the dev tools pass `force` |
| `SectorGenerator.generate()` | Deals each locked ship's `unlock_scenario` onto an ordinary stop ahead of the arrival in its `unlock_sector`, after the reckonings, from a generator of its own (`place_consequences()`), so a run with nothing to earn deals its usual map. Player's own runs only: the Scenario Lab and AutoPilot fly every ship and never meet these |
| `EscortKeeper` | Earns an escort's `unlocks_ship` when it's delivered and shows `ShipUnlockPopup` once it has gone (not while the AutoPilot plays) |
| `ShipUnlockPopup` (`Systems/UI/ShipUnlockPopup/`) | World-space card like `TileUnlockPopup`: the hull lands in a flash with a glitch, a ring and a spark burst; light rays (`_Rays`, drawn on the 320x180 grid through `JuicePixelated`) turn behind it while sparks stream off; name, pitch and hint come up; Close pops in about a second later. `closed` when it's dismissed. `open(ship, die)` for a ship the die earned opens on the die instead: its faces pop in, the earning faces flare and fly into the hull trailing motes, and the face sits over the hull under `unlock_card_header` |
| `Map.hold_jumps(holder)` / `release_jumps(holder)` | No jump while anything holds the ship (`can_jump()` false, refused as "NOT YET", `jump_refusal()`). The gate path in `JumpEvent` checks `can_jump()` too |

Encounters ask about ships through `FactionCondition` (`FLYING_SHIP`,
`SHIP_EARNED` via `ShipUnlocks.counts_as_earned()`), in standing branches and
`standing_requirements`: `EVENT_Shipwright` is in the random sector 2 mix but
only dealt once the Outrigger is earned, and its greeting branches three
ways (first run, repeat, flying the Outrigger).

Locking a ship never strands a run: `ShipCatalog` still lists it, so a save
flying it, the AutoPilot's `--ship` and the Scenario Lab still fly it.

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

**No save until it's done.** A tutorial can't resume: its fights are scripted,
and a Continue would replay them unscripted. While it runs
(`Globals.tutorial_holds_saves`), GameStateManager's checkpoints update the save
in memory but don't write it; `FINISH_TUTORIAL` emits
`Events.tutorial_finished`, which writes the latest one. Quitting partway
leaves no save, so the next Play starts the tutorial over.

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
lab runs aren't fresh, so they skip it. In the tutorial,
`GameStateManager.play_opening_strike` waits while
`Globals.tutorial_holds_opening_strike` is set, until
`Events.opening_strike_released`: the step with `releases_opening_strike`
(the first card) sends it 0.4s after its text has all come in.
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
one; the left one returns when the tutorial finishes. The targeting computer's
target arrows are held back too (`Globals.tutorial_holds_target_arrows`, read
by `TargetingComputer.refresh_shift_buttons`). The last step opens on
`ENEMIES_ARRIVED` in the two-ship fight after the jump (every distance the
seeded hand can jump lands in one) and has `reveal_target_arrows`: the manager
puts the step's highlight up on its own, releases the arrows, waits for the
computer's `shift_buttons_live` (4s deadline), then shows the card under the
same highlight and fades it out when the card closes.
The card's label has its own `line_separation` (-2, not the theme's -4) so
the 10px inline icons clear the lines around them, and it doesn't overhang
the panel, so a card grows with its text: four lines is about the most a card
at the top of the screen holds before reaching the systems panel. Put a space
before an icon token so it doesn't touch the word before it. A card's
`tutorial_text` is content text (7.5).

**Ghost cursor.** A step that asks for a drag or a click shows it: a
translucent copy of the game's pointer (the arrow and fist from
`MouseCursors`, tinted the cards' action-word yellow at 70%, z 20 over the dim
and cards) acts it out on the live board, on a loop, until the player does
it. `TutorialStep.ghost_demos` lists `GhostDemo`s, a DRAG (at → to) or a
CLICK (at), in `Systems/TutorialManager/GhostCursor/`. Each end is a
`GhostTarget` that names a thing, never a pixel: a node path from the scene
root, the first draggable die, a grid tile by its `TileResource` (or its
upgrade), the first open grid cell, a salvage tile, the map's jump arrow, the
map's view plus an offset (a pan, `Map.pan_area()`) or a ship other than the
target. Targets resolve every frame, so bobbing dice and moving ships are
followed, and a target that's absent, hidden, spent or locked out drops its
demo from the loop until it's back. A drag carries a see-through copy of the
die or tile. The manager starts the demos 0.6 s after the card's text is in
(`all_text_displayed`) and stops them when the step closes or at
`FINISH_TUTORIAL`. The cursor hides while the mouse is down or anything is
held, and starts over 1.2 s after. `test_ghost_cursor.gd` checks that every
drag or click step has a demo and every node path exists in main.tscn.

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
reroll its shelves (`REROLL`, while `Shop.reroll_refusal()` allows),
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
  buys what clears its price. With nothing left worth buying it rerolls
  when a fresh shelf is expected to pay: every tile the shop could stock
  (minus what's on the shelves) valued as a purchase at its rarity's
  average price, and the expected best of four weighted draws
  (`HeuristicPolicy.expected_best_of()`) set against the reroll's price in
  spare credits, half rate. It never rerolls into a reserve of 20 credits
  plus what repairing up to its repair line would cost. The `-randpick`
  styles never reroll.
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
| `hand_may_be_kept` | `Player`: End Turn lights with dice in hand during a fight (no ship sets it now; End Turn also lights when no die in hand has a tile to go to, which only a ship without an Engine Charger tile can hit) |
| `signature_tiles` | `RewardManager.get_possible_tile_rewards()` (salvage and the shop): offered only while this ship is flown, on top of the shared pool; they stay `offered_as_reward = false` and each has an upgrade. `CodexCatalog` lists them like offered tiles |
| `supports_tutorial` | `TutorialManager`: the tutorial is written for the default grid |
| `coming_soon` | Ship select: greyed out, "Coming soon…", never pickable (no ship sets it now) |
| `starts_locked`, `unlock_hint`, `unlock_scenario`, `unlock_sector`, `unlock_face`, `unlock_face_count`, `unlock_card_header`, `unlock_carve_hint` | Ship Unlocks (below): not pickable until earned; the card shows the hint; earned by an encounter dealt into that sector, or by the faces left on Fate's Die at the run's end |
| `cockpit_scene` | `CockpitMount` (main.tscn, `Graphics/Cockpit`): mounts the ship's `Cockpit` scene, or the default `cockpit_ambience.tscn` |
| `cockpit_palette` | `Cockpit`: recolours the default shell (when the cockpit has no `walls_texture`) and the instruments' frames (`cockpit_surface` sprites) once at load |
| `cutscene_frames`, `cutscene_exhaust_points`, `preview_texture`, `theme_color` | Opening cutscene, ship-select card |

| Ship | Grid | Engine | Behaviour |
|---|---|---|---|
| Die Fighter | 5x3, starting on the middle 3x3 (the outer columns sealed, see Grid Slots) | Engine Charger tile | none |
| Outrigger | two 3x3 pods, x 0-2 (port) and 4-6 (starboard), column 3 a 16 px hole | `OutriggerSync`: in a fight every die that activates a tile (`Events.tile_activated_by_die`, placed or Fed, holograms too) adds its face to that tile's pod's thrust; at `player_turn_over` the drive charges by the lower pod's thrust, to the gate (`SyncChargeEvent`, then a `ChangeEngineChargeEvent`), and level pods (equal, above 0) emit `Events.pods_level` (tiles: `ON_PODS_LEVEL`). Thrust resets at `player_turn_refresh`, `start_combat` and `combat_finished`. Ship readings `pod_lead`, `pod_level` | `Outrigger/`: `OutriggerSync`, `SyncGauge` (two thrust columns in the gap, a "+N" tag, the x/10 badge; takes the `engine_charger` juice group), `OutriggerPanel` (runtime restyle of the systems panel, frees the charger tile). Kit: Sunlance (1,1), Crosslink (2,1), Solar Shroud (4,1); signature tiles Sunlance, Solar Shroud, Yaw Cannon, Gyro Stabilizer |
| Carousel | 5x3 minus (2,1): 12-cell ring + hub slots (1,1), (3,1) | The Reactor: the charger tile moved to (2,1), re-dressed with `reactor.tres`; charges, then Feeds up to the ignition slot (2,0). `ReactorIgnitionModifier` points that Feed at the ignition tile | `CarouselBehavior`: turns the ring at `player_turn_refresh` (fight turns after the first) via `TileGrid.relocate_tiles()`, and mid-turn as the ship's mechanism (`advance_mechanism()`, the Ratchet's `ADVANCE_SHIP_MECHANISM`; ridden, so it counts ring steps), winds it home on `combat_finished`/`jump`; `CarouselTrackLights`. Kit: Apex Cannon (1,0), Ratchet (1,1), Keel Plating (3,2); signature tiles Apex Cannon, Keel Plating, Ratchet, Gearbox, Flywheel, Slingshot |

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
| Outrigger | `Outrigger/Cockpit/`: an X-Wing-style canopy in gunmetal and orange: pillars leaning out to the roof, a dash hood behind the panel, twin throttles, both engine nacelles outside the side glass | swapped: target to port, hull to starboard |
| Carousel | `Carousel/Cockpit/`: a TIE-style octagonal viewport set in a ball, charcoal and maroon: corner struts fading into glass mullions, plating in rings round the window, `ChaseLights` on the frame trim (race on `CarouselBehavior.ring_turned`), a `HangingDice` gyroscope | pulled in between the struts |

**Grid Slots.** A ship's layout can start partly sealed: its starting kit's
`GameSaveResource.unlocked_cells` lists the open cells (empty opens them all,
which is also what a save from before Grid Slots means). A sealed cell is kept
out of `TileGrid._cells`, so to placement, adjacency, pushes and Feeds it is a
hole; it is drawn as a hull plate (`locked_cell.png`) over the panel art by
`SealedCellPlates`, a child of the grid that only draws (the plates, the
target brackets, hover, the blow-off) and is told when the sealed set changes. A
`GridSlot` (`Source/Systems/Game/GridSlot/`) is a draggable item: the last
choice of a salvage offer (`RewardResource.grid_slot_probability`, and always
when the grid is full) or the shop's fifth shelf, which holds it or the
extra die (`Shop.GRID_SLOT_CHANCE`, `Shop.GRID_SLOT_PRICE`). Carrying one
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
offer, or a second copy on the grid outside a fight). The preview fills
`InfoResource`'s `upgrade_*` fields, and `InfoShower` then lays the two out
side by side: the tile on the left, the "+" on the right (its art through
`tile.gdshader` with `upgraded` on), and `INFO_TILE_UPGRADE` over an arrow
between them.
An upgraded tile sets `tile.gdshader`'s `upgraded` (bright bands chase round
the shared 22x24 silhouette's border) and carries `UpgradeSparks` particles in
its family colour (`ColorSymbolBadge.color_of_tile()`). That look, and the
burst on upgrading, live in `TileUpgradeLook`; Tile keeps the rules.
Likewise the use lights: `TileUseLights` shows `uses_remaining` on the sprite,
popping white sparks off a light that goes out and switching refilled lights
on one at a time as `Juice.gather()` motes fall into each. The count itself
changes at once; only the lights trail it. And the held dice: every die on a
tile sits in its `dice_queue`, and `TileHeldDice` (`tile_held_dice.gd`) says
which of them the tile is holding, for a pair (`hold_die()`) or past the turn
(`hold_over()`). The doc comment at the top of that file explains the three
ways a die can be on a tile.

`TileGrid.relocate_tiles(moves)` moves many tiles at once (all leave before any
arrive, so a closed loop can shift) and emits no push or manual-move events.
`TileGrid.mirror_of(pos)` is the same row, `x -> grid_width - 1 - x`
(`TARGET_MIRRORED_TILE`, the Crosslink).

**Ship rules tiles can reach.** Tiles never name a ship. A ship's behavior
scene can expose numbers its rules keep, in `ShipRules.READINGS_GROUP`
(`has_ship_reading(key)`, `ship_reading(key, context)`), read by
`AMOUNT_MODIFIER / SET_TO_SHIP_READING`, and a moving part, in
`ShipRules.MECHANISMS_GROUP` (an awaitable `advance_mechanism(steps)`),
driven by `TILE_CONTROL / ADVANCE_SHIP_MECHANISM`, whose event holds the
queue until the move lands. On another ship a reading is 0 and a step does
nothing, so tiles built on them are that ship's signature tiles.

---

## Run Progression

A run is `demo_sector_count` sectors long (3 by default). Each sector is
dealt by `SectorGenerator.generate()` (a child of GameStateManager in `main.tscn`, holding the encounter lists) and laid out as:

```
[fate] ... [shops / elites / combat / event mix] ... [boss's jump gate]
```

**Each sector is a layer of the fleet** (LORE.md §3): the Tail, the Belly,
the Spine. A scenario's `sectors` flags name the layers it belongs to, and
`ScenarioResource.allowed_in_sector()` filters the combat, event and elite
lists to the sector's layer (and to ships it is ready for, `earliest_sector()`)
before anything is drawn. A later sector's arrival is one of its own events.
The rosters, and the story each encounter tells, are in
`FACTION_SCENARIOS.md`.

Every pick in a sector goes through `SectorGenerator._pick_one()`, which
always spends exactly one RUN draw. `RNGManager.pick_random()` spends none on
a single option (`randi_range` of one value doesn't roll), and a layer's short
lists do run down to one inside a sector; the skipped draw shifted every later
roll of the tutorial's seed. For two or more options the two picks agree, so
seeded maps stay as they were. For the same reason the 30% event roll is drawn
even when no event is left, and each layer must hold at least
`elites_per_sector.y` elites (`test_each_layer_holds_enough_to_fill_its_sector`).

**Added stops** (`added_stops`, 6, of which `added_events`, 3, are always
events; the rest are events at the mix's 30%) are inserted by
`SectorGenerator.add_stops()` once the RUN stream has dealt the rest of the
sector, from a side generator like the stations below, anywhere past a die's
reach of the arrival and before the gate. They lengthen a sector without
touching `sector_size`, which would move every seeded map (the tutorial's
seed 21 included). An added stop prefers encounters the sector wasn't dealt
(judged before any pinned stop, so a pin changes only its own slot); an
event with none left becomes a fight.

**Fate's tile** is the sector's first slot: `generate()` prepends an empty
slot last, without a draw, so every stop keeps its place relative to the
arrival, and `FateState.reset()` (a fresh sector only; a save restores) has
Fate take tile 0 and start its zone there. One Fate encounter waits against
the black hole from the start, inside the purple: a place to fly into Fate on
purpose (Hunger). A sector is `sector_size` + `added_stops` + arrival + gate +
this tile: 12 + 6 + 3 = 21.

**Repair stations** (`repair_stations_per_sector`, 1-2) are swapped in by
`SectorGenerator.place_repair_stations()` after the sector is otherwise built. They replace
fights beyond a die's reach of the arrival, never events (where Fate's Die is
carved, and the pilgrim who hands it over is one), shops, elites,
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
| Generate the next sector | `SectorGenerator.generate()` (safe to call repeatedly — it replaces the save's sector) |
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
`Map.fate_variants` (Fate Rift, Hollows, Maw, Shroud, Brood), picked by `FateState.corrupt()`
from a hash of the RUN stream's state and the tile, so no draw is spent.
`Map.is_fate_scenario()` is how anything asks whether a tile is Fate's.

**Fate's rules are `FateState`** (`Map/fate_state.gd`, `Map.fate_state`): a
plain object over the sector's scenario list (the same array as
`Map.scenario_list`). It holds `fate_index`, `scenarios_in_danger` and
`stray_danger_indices`; answers `is_in_danger()` and `danger_runs()`; and
makes the changes: `advance()` on a jump, `clear_slot()`, `open_gate()`,
`reset()` for a new sector, and `to_dict()`/`restore()` for the save. Map
keeps the exports (forwarded on set) and draws it all. Its only RUN draws
are in `pick_danger_range()` and `pick_stray_danger()`.

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

## Faction Memory

The fleet remembers what the player does to each faction for the rest of the
run (LORE.md §1, §9). Ordinary fights move nothing: what counts is authored on
the outcomes of encounters. Run state, saved at every checkpoint.

| Piece | Where | Role |
|---|---|---|
| `FactionIdentity.id` | `Content/Factions/*.tres` | The stable key a faction is remembered and saved by (`caravan`, `rearguard`, ...) |
| `FactionLedger` | `Systems/Game/FactionStanding/faction_ledger.gd` | Plain data: standing per faction (held within ±`STANDING_LIMIT`), deed counts, kills. `regard()` reads standing in bands (HATED ≤ −6 < DISLIKED ≤ −2 < NEUTRAL < 2 ≤ LIKED < 6 ≤ TRUSTED); `price_multiplier()` is what that faction's traders charge |
| `FactionStanding` | `Systems/Game/FactionStanding/faction_standing.gd`, `Globals.faction_standing` | Owns the run's ledger. `ledger_now()` is the read path for resources and statics, and gives an empty ledger outside a run |
| `FactionDeed` | `Content/Factions/faction_deed.gd` | On `ScenarioShipState.deeds`: a standing change, a deed name, and whose standing (default: the ship's own faction) |
| `FactionCondition` | `Content/Factions/faction_condition.gd` | A question about the ledger (regard at least/at most, deed done/not done, kills). Read by branches and encounter requirements |

**Writing.** `Enemy.trigger_state_effects()` emits `Events.ship_deeds_done`
where the state's `effects_on_enter` would play, so a deed is recorded once:
on a transition, or when an opening state's ship lands, and never for a ship
a Continue restores (`_skip_next_enter_effects`). `FactionStanding` applies
each deed and emits `faction_standing_changed`. Player kills are counted per
faction by RunStats' rule (dead, not finished off by another ship).

**Reading.**
- *State graph.* `ScenarioShipStateBase` now has `resolve(ship_faction)` and
  `next_states()`. A `ScenarioShipStateStandingBranch` resolves to the first
  option whose conditions hold, else `otherwise`, drawing no RNG. It can stand
  wherever a state can: a transition's target, or a ship's `starting_state`
  (now typed `ScenarioShipStateBase`; read it through
  `EnemyStateRewardResource.opening_state()`). Every walker of the graph (save
  restore's `_find_state`, `ScenarioGraph`, the content tests) goes through
  `next_states()`, so a branch's options are found like any other state. A
  restore looks the saved state up from the authored root, so a ship comes
  back in the state it was in even if the standing would now open it
  differently.
- *Encounters.* `ScenarioResource.standing_requirements` filters every list
  in `allowed_in_sector()`. `SectorGenerator.consequence_scenarios` are
  placed by `place_consequences()` after the repair stations, from a side
  generator seeded off the RUN state like `place_repair_stations()`: a run
  that has earned nothing deals the map its seed always did. Unlike stations
  they may sit anywhere ahead of the arrival: beyond a jump of it, a sector
  left no ordinary stop for them in most layouts.
- *Prices.* `Shop.standing_price()` and `RepairStation.repair_cost()` /
  `sell_price()` scale by the keeper's faction's `price_multiplier()`, after
  the REWARDS roll, so the roll itself doesn't move.

**The ship's own events.** `PLAYER_ATTACKED_SELF` and `HULL_CRITICAL`
(`ScenarioEvent` 11 and 12) are delivered by the Enemy to itself, never on
`Events.scenario_event`. HULL_CRITICAL fires on `health_damaged` when the ship
survives at or below its state's `critical_hull_fraction`. After any state
change made while the engine is draining, `_settling_into_state` ignores
PLAYER_ATTACKED_SELF until `finished_processing_queue`, so the rest of the
volley that made a crew surrender doesn't count as executing it. A state with
`holds_fire` silences every slot of the ship's table (`silence_face`) on entry,
on every roll, and on restore.

## Fate's Die and the Reckoning

The secret boss of `LORE.md` §5-8; the fight and its endings as redone are
`RECKONING_ENDINGS.md`. Three gates: the player knows the secret from an
earlier run, has carved every face of Fate's Die, and turns back at the last
gate. The run deals three hands, and the fight is where the player picks one:
kills set Become Fate, saved ships set Save Others, dice set Save Yourself.

| Piece | Job |
|---|---|
| `FateDie` (`Systems/Game/Fate/`) | Pure state: six faces (`Face` enum, saved by id), `carve()` into the first blank (-1 once full), `carve_over(slot)`, `roll(rng)`. |
| `FateFaceResource` + `FateFaceCatalog` (`Content/FateDie/`) | One `.tres` per face in `Faces/`, named by its id: name, colour, 7x7 glyph (the faction badges, Ruin's own), what carves it, and the `reckoning_chain` it plays when Fate throws it. `defiant_chain`/`defiant_text` replace them for a run that refused every tithe. Translatable (`FATE_FACE.<id>.*`); numbers in the text bind to the chain (`TextTokens`). |
| `FateLedger` | The run's die (`has_die` once the pilgrim hands it over; nothing carves before), `pending` carvings, `kills` (`Events.enemy_destroyed`, not ship-on-ship, not mounted parts, not inside the Reckoning; each with its `encounter` index and whether it died on the civilian side), `allies` (`REMEMBER_SHIP`, with `encounter`), the run's missed opportunities (civilians killed, the betrayal deeds of RECKONING_ENDINGS §5.1, an escort lost), `deeds` (`RECORD_DEED`), `in_reckoning`/`reckoning_seed`, and `knew_secret` (read from the collection when a run starts and saved with it, so learning the secret at the end of a run doesn't open that run's own way back). A save from before encounters were kept falls back to the old order. Hunger: arriving at one of Fate's tiles carves it, once a sector, before the arrival checkpoint (connected ahead of GameStateManager). |
| Effects (SCENARIO_CONTROL, appended) | `CARVE_FATE_FACE` (`string_param` = face id), `GIVE_FATE_DIE`, `RECORD_DEED`, `REMEMBER_SHIP` (the actor), and the Reckoning's `ADD_ESCAPE_VELOCITY` (now engine charge), `SUMMON_ALLY_TILE`, `FATE_SEIZES_DIE`, plus the redo's `CALL_ALLY` (Mercy: `CallAllyEvent`) and `HURRY_NEXT_WAVE` (Hunger: `HurryNextWaveEvent`) and `WITHDRAW_OFFERS` (calls off the floating salvage: Wreck Salvage's price for firing on the guard). `ADVANCE_HORIZON` is retired (`RetiredEffectHandler`: kept so the enum's values never shift). Each resolves through its event into the ledger or the director; outside the Reckoning the Reckoning's do nothing. |
| `FateDieDisplay` (`Graphics/FateDieDisplay`) | The die on a chain from the canopy, drawn from `FateDieArt` (bone die + glyph, composed at run time and cached). Pendulum like `HangingDice`; tumbles and flares on a carving (`fate_face_carved`) or a throw (`fate_die_rolled`), rattles while a carving waits. A carving's moment (spin, flare, a 4 s callout with the carved count) is queued until no ship is talking (`EnemyDialogueManager.is_speaking()`, at most 12 s), so it never lands on the line that carved it. Click: `info_for(ledger)`, whose six faces are `InfoResource` hotspots (`add_hotspot()`, drawn by `InfoShower` in the keyword popup): a carved face's name and what carves it, a blank face every face and what carves it. What a face does in the Reckoning is deliberately never shown. `break_loose()` / `restore()` for "You" taking it (below); `is_hanging()`, `rest_position()`. Creates its `FateSelfPresentation` in `_ready`. |
| `FateCarveChoice` (`Systems/FateCarveChoice`) | The full-die card, opened when a carving is pending and the player is out of combat and not jumping. Picking a face calls `resolve_pending(slot)`; Let It Pass is `resolve_pending(-1)`. Not recording (AutoPilot, Lab): `auto_choice()` carves over the most common face. |
| `LastWords` (`Systems/Game/LastWords`) | A gate boss's last words. On `enemy_destroyed`, once a started fight (`start_combat`) has no hostile left and the dying ship is one the scenario started with (not a launched fighter), recording runs only: holds its death (`Enemy.hold_death()`), so on the Bastion the hull breaks up around whichever part fell last. Words: `FateRevelation.lines()` at the last gate, else `ScenarioResource.last_words` (a `StoryBeatResource`; its `repeat_line` once `CollectionManager.has_read_story_beat()`). Nothing to say, nothing held. After the fight ends (it may already have) and 1.6 s, opens a `StoryBox` on the ship, marks the beat read, and on `finished` releases the death (`release_death()`). |
| `StoryBox` (`Systems/UI/StoryBox`) | `open_in(parent, speaker_name, lines, ship)`: dims the screen, spotlights the ship over it (`EnemyGraphicsManager.set_spotlit()`), and types the lines one at a time in the speaker's speech-box art (sliced and stretched, `_SpeechBox`; green for the Caravan, yellow for the Inbound, red otherwise), each with a green Close (`STORY_BOX_CLOSE`). Clicking the dim finishes a line; any key finishes or closes. Emits `finished` and frees itself. |
| `StoryBeatResource` (`Content/StoryBeats`) | Content: `speaker`, `line_1`-`line_3`, `repeat_line`, all content text (`STORY_BEAT.<FILE>.*` in `content.csv`). `id()` is the file name. Beats so far: `warden_last_words`, `dynamo_last_words`, beside their gate scenarios. |
| `FateRevelation` (`Systems/FateRevelation`) | The Bastion's confession: `is_last_gate()`, `speaker()`, `lines()` (full, or the short form if the player knew the secret when the fight started). On `combat_finished` at the last gate, learns the knowledge (`CollectionManager.learn_fate_knowledge()`). As the confession's box closes, LastWords calls `hand_over_drive()` (`FateLedger.take_drive()`); a run nobody records gets the drive straight away. |
| Horizon Drive in the charger (`EngineCharger._install_drive`) | On `vanguard_drive_taken` (with a burst and a callout) and on a Continue that holds the drive: `TileUpgradeLook.set_override(tile, DRIVE_COLOR)` dresses the charger tile as upgraded in gold whatever its resource (it holds through the Reckoning's swap to the Horizon Drive tile), and the charge rings take `engine_ring_large_drive.png`. |
| Last-gate rewards (`GameStateManager.is_at_last_gate()`, `last_gate_pays()`) | `RewardManager._spawn_reward` drops every reward at the last gate unless `fate_route_open()`: otherwise beating it ends the run and nothing could be spent. |
| `EndingCutscene` (`Scenes/Cutscenes/`) | The run that first heard the secret (`!knew_secret`, knowledge now held, recording, no AutoPilot: `GameStateManager._plays_first_ending()`) skips the gate passage: `go_through_gate()` awaits `EndingCutscene.play()`, which adds the scene over the game scene on canvas layers 89-96 (curtain, stars, pixel world, glitch, skip prompt). The flight is `ending_anim` on its AnimationPlayer (shot, husk, tithe, Fate, glitch, the purple flood); the vision after it is a tween: `FateDieSpin` (a SubViewport with its own 3D world: a lit cube built in code, faces composed from the glyphs at 5x, carved on the side facing the camera; also built small with `glyph_scale`, and steered with `turning`, `set_orientation()`, `facing(side)`, `flare()`) drawn through `palette_snap.gdshader`. It ends on black, emits `fate_ending(&"unlocked")` and `victory`, and lifts its curtain off the victory screen. `CutsceneSkipPrompt` is the skip both cutscenes share. Dev console: `fate ending`, `fate drive`. |
| `FateVectorChoice` (`Systems/UI/FateVectorChoice/`) | Built in code by `GameStateManager.go_through_gate()` at the last gate when `FateLedger.fate_route_open()`. `chosen` FORWARD carries on to victory; BACK calls `enter_reckoning()`. A run nobody plays always goes forward. |
| `ReckoningDirector` | Wakes on `load_scenario` of its `scenario` (`FATE_reckoning.tres`; `is_reckoning()`, `active()`). Its own background, `fate_reckoning.tres`: Fate's Corruption without the no-flee rule, with `NoEvasionModifier` ("Attacks can't be evaded") instead. Swaps the engine charger's tile for the Horizon Drive (2x the die into the engine) and freezes the drive at 3x its size (`ReckoningRules`, `Player.freeze_engine_max()`, released after), so dice leaving never lower the goal; the charger is dressed gold and charge never banks away. A full bank lights the map's arrows and either is the escape (`JumpEvent`). Waves come from `ReckoningQueue` as `enemy_left` empties the board, before the combat check, so the fight never ends: echoes (`echo_state`, half hull, `spawn_index` -1, washed purple through the enemy shader's cloak uniforms) rise from the left, and each wave's saved and spared ships go to `ReckoningAllyWing`. When the Tally is spent, "You" (`FateSelf`), then `spilled_pool` round robin. Fate's throws are rolled a round ahead from its own seeded RNG (`upcoming_face()`), emitted as `fate_die_rolled` with the face's chain queued (`FateRollEvent`): Mercy calls the next ally or heals and shields the one aboard; Hunger brings the next wave now (not past 6 hostiles); Duty never shields "You". `FateSelfWard` sits on the engine all fight. Every way out goes through `ReckoningRules.resolve()`, which builds a `ReckoningEnding`; the director records it (`CollectionManager.record_fate_ending(id)`) and awaits `ReckoningEndingPlayer.play()`, which emits `fate_ending` and `victory`/`game_over`. Hull 0: `CockpitDestruction` plays first and leaves `game_over` to the films. Dev console: `fate reckoning`, `fate you`, `fate allies <n>`, `fate escape <n>`, `fate end <kind>`. |
| `ReckoningHud` (`Systems/ReckoningHud`) | The banner naming each throw and what it does (`FateFaceResource.reckoning_text`). The escape is the engine charger itself, so there's no meter. |
| `GameOver` | Reads `Events.fate_ending` for the first-knowledge card (`unlocked`: an opaque backdrop, since it comes up out of the cutscene's black) and each Reckoning ending's card (`alone`, `convoy`, `last_die`, `fell_in`); after `become_fate` it goes straight to the main menu, where Throw #N now shows. The normal win closes on the Tithe Collector line. |
| `ReckoningQueue` | Pure: the run played backwards from `FateLedger`'s kills and allies, one wave per encounter, last in first out (echoes, the saved and spared ships met there, whether a civilian died there), the latest 12 encounters plus the first kill alone last. Civilian waves say *"We were running too."*; the first kill's echo, falling, *"Before me, there was only you."* |
| `ReckoningRules` | Pure: the goal (3x the drive as the fight begins) and `resolve()`, which turns what just happened (jumped out, last die left with an ally, last die taken, hull gone, "You" destroyed) into a `ReckoningEnding`: Alone, Convoy (perfect when nobody was left behind in the fight or the run), Last Die (not when the bank is already full), Become Fate, Fell In. `test/core/systems/test_reckoning_rules.gd`. |
| `ReckoningAllyWing` | The saved ships, one at a time in `EnemyManager.ESCORT_SLOT` (`ally_aboard.tres`, built like the Mayday escort, jumping in from the right), the rest waiting; table `ally_table.tres`: Shield, Raid and **Run for it** (`run_for_it.tres`, 2 faces), which jumps out carrying only the die spent on it (`EscapeWithDiceEvent`'s spent-only option): saved, and the die gone from the Fleet (`Player.dice_lost`). Lines name who's still waiting (*"[Name]'s right behind us."*, *"That's all of us."*), and say when the bank is nearly full and when the last die goes. Killed here: lost. Spared ships (debts) take no slot: one strafing pass (3x a seeded d6 to every hostile but "You"), then gone. |
| `FateSelf` + `FateSelfWard` | "You" (`fate_self.tres`): the player's hull, 1 hull, named "You", every face **Your Own Fire** (`your_own_fire.tres`: 2x the die at the player; the multiplier is on its step). `FateSelf.is_self()` keeps it out of every unaimed pick (the hit-everything and random targeting handlers, a dead ship's dice, Plunder, delayed payloads, Raid); the ward cancels whatever still lands unaimed, and every status, shield or heal. Destroyed only by damage from a die spent while it's targeted: no wreck, kill-cam or salvage; `Events.fate_self_destroyed`, then Become Fate. |
| `FateSelfPresentation` (`Graphics/FateSelf/`) | On `fate_self_arrived`: the canopy die rattles, its chain snaps, it shatters (`FateDieShards`) and the shards stream out to reform above "You" as a small `FateDieSpin` (`FateSelfDie`), which follows the hull, turns lazily toward `upcoming_face()` and lands on each throw. `FateSelfLook` dresses the hull in `fate_self.gdshader` (purple washing across in waves, tearing slices, pixels peeling toward the hole). On `fate_self_destroyed` the slices pull a copy of the hull apart and the die floats back to the canopy. The bone die returns on the next scenario or a reload. |
| Reckoning ending films (`Scenes/Cutscenes/Reckoning/`) | `ReckoningEnding` carries everything a film shows (kind, perfect, who got out, was left behind or lost, the run's missed chances, the first ship saved, who took the last die, the die's faces; `preview()` makes one up). `ReckoningEndingPlayer.play()` fades the game to black under its curtain (layer 88) and plays the ending's segments on layers 89-96, each a `ReckoningCutsceneSegment` that ends on black and calls `finish(skipped)` (a skip ends the whole ending); then it emits `fate_ending` and `victory`/`game_over` and lifts the curtain. **Arrival** (`ArrivalCutscene`, `Arrival/`): the sky with no Fate in it; Alone, the Convoy and its perfect version, and the Last Die's second shot, with the formation (`ArrivalFormation`: one slot per ship the run could have saved, capped at 12; missed slots empty, left-behind ones a failed jump-in) and the credits beside it. **Consumed** (`ConsumedCutscene`, `Consumed/`): the Last Die's engines going out flame by flame (`ConsumedHull` finds each hull's flames), and Fell In ending on the Fallen's look. **Become Fate** (`become_fate_cutscene`, `BecomeFate/`): the purple wash, the dive, the reverse shot from the hole's mouth (`hole_mouth.gdshader`), the player's own die thrown, falling credits. `ReckoningCredits` is the one list of credit lines. Dev console: `fate end <alone\|convoy\|perfect\|last_die\|become_fate\|fell_in>`. |
| Throw #N (`CollectionManager.runs_started()`) | Runs started are counted in `collection.json` from a fresh run (not a Continue). The main menu shows *Throw #N* under the title only once `fate_endings("become_fate") > 0`, and the pilgrim's `become_fate_dialogue` (*"It's been waiting for you. ...Oh. It's you."*) wins over its knowing line. |
| The Fallen (`FateLedger._raise_the_fallen`) | On `load_scenario` of one of Fate's tiles in a recording run, the newest `CollectionManager.fallen_ships()` entry joins the fight as `fallen_ship.tres`, wearing that ship's `cutscene_frames` hull flipped nose-down with a purple cloak wash (its own material). Destroyed (`enemy_destroyed`), it queues the tile it carried in `Reward.forced_rewards` for its wreck's offer and is laid to rest (`lay_fallen_to_rest`). Never saved: a replayed fight raises it again. |

**Saves.** The ledger rides every checkpoint (`fate_state`). Entering the
Reckoning sets `in_reckoning` before the jump, so its arrival checkpoint holds
it, and `GameStateManager._scenario_to_load()` sends a Continue back into the
fight, from the top like any fight. The Reckoning never checkpoints mid-fight,
so its waves, allies and "You" are never saved. The meta state (knowledge,
endings, fallen ships) is `collection.json`'s `fate` block.

**Seeds.** The pilgrim is placed by `place_fate_pilgrim()` from a hash of the
repair stations' seed, replacing one stop past a jump's reach of the arrival
(nothing placed after it may replace it: stations and consequences take
fights only),
so the RUN stream and every seeded map keep their draws (the tutorial's
included). Fate's throws use the director's own generator.

Dev console: `fate` (see `help`).

---

## Escorts

A ship the player helped can leave with them and ride along (the Mayday's
runner, "Bless you, pilot. Stay close.").

- **Authoring.** `ScenarioShipState.escort` (an `EscortResource`,
  `Content/ScenarioResources/escort_resource.gd`): the hull that rides
  along, its riding state, its farewell state, `fights`, and the `payout`.
  `Enemy.trigger_state_effects()` emits `Events.escort_signed_on` beside the
  deeds, so a ship a Continue puts back in that state doesn't sign on twice.
- **`EscortKeeper`** (`Systems/Game/Escort/`, after FateLedger in
  `main.tscn`) runs it: `JOINED` while still in the encounter it signed on
  in, `RIDING` from the next arrival, `FAREWELL` once its fights are done.
  On `load_scenario` it spawns the escort (`EnemyManager.spawn_escort()`),
  after EnemyManager has stood the encounter up; on `start_scenario` it
  slides into `EnemyManager.ESCORT_SLOT`, the pocket above the hull gauge,
  in every encounter (shops and docks too). Each `combat_finished` with it
  alive counts a fight, ahead of the after-combat checkpoint. At the arrival
  after its last fight it adds an `ArrivalIntro.Beat.ESCORT_FAREWELL`: it
  flies to the middle, the payout spawns, and the farewell state's chain
  WAITs then FLEEs, all before the encounter's ships fly in.
- **On the board.** `Enemy.is_escort`: pinned out of the formation and its
  speech-box layout, skipped by the opening fly-in, left out of
  `get_faction_ships()` (no `CIVILIANS_DEFEATED`, no bounty) and of
  `ScenarioManager._handle_enemy_leaving()` (it closes no shop), and a pirate
  firing on it isn't `PIRATE_ATTACKED_CIVILIAN`. It is in the roster, so it
  rolls a table, binds its Raid (`owes_hand_off`) and can be raided and
  killed.
- **Endings.** Dying: no payout and no standing change, and its FateLedger
  ally entry gets `"escort": "lost"`. Saying goodbye: `"delivered"`. Turned
  hostile (shot by the player, or betrayed before it left): dropped, its new
  state's deeds speak for it. The Reckoning never spawns it (it is already
  a Saved Ship tile from its `REMEMBER_SHIP`); `_place_ally` floats the
  delivered or lost line over that tile.
- **To the gate** (`EscortResource.rides_to_gate`, the Outrigger courier,
  `EVENT_Shipwright`). Its count never sends it home. The `combat_finished`
  of a gate fight (`sector_gate_scenario`) with it alive makes it `FAREWELL`
  there and then, earns its `unlocks_ship` and holds the jump
  (`Map.hold_jumps`); 1.6 s later it says goodbye from `ESCORT_SLOT` (clear
  of the bounty): each `farewell_lead_in` state in turn, each held until its
  line has typed out plus 1.5 s, then the farewell state. Once it has gone
  the ship-unlock card shows (Ship Unlocks), and Close releases the jump. A
  gate escort signing on while another rides sends that one off early,
  paid, where it is. Any escort's `payout` is paid as its farewell state
  starts, after the lead-in lines, at `payout_position` if set.
- **Saves.** `get_state()` rides every checkpoint (`escort_state`: terms,
  phase, fights left, hull read off the live ship). A Continue mid-fight
  replays it from the arrival with the hull it arrived with; one into the
  farewell's arrival replays the goodbye and pays once. A gate escort is
  `FAREWELL` in the after-combat checkpoint, so a Continue at the open gate
  replays its goodbye and the card.

---

## Background Layouts and Star Parallax

**Layouts.** A background's planets and stars live in
`set_piece_compositions` (`SetPieceComposition`,
`Content/BackgroundResources/set_piece_composition.gd`), not
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
many stars or pieces are drawn around it. A scenario can pin its own
(`ScenarioResource.set_piece_layout`, a `SetPieceComposition` used in place
of the pick; the layout draw is still made, so the stars don't change): the
tutorial's two-ship fight pins star_field's dune world and moon, the moon
clear of the left ship's health bar. `test_background_set_pieces.gd`
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

**Set pieces in a jump.** Fixed pieces (planets, moons, suns) hold still at
rest and slide down at `static_jump_drift_rate` x speed above rest
(`BackgroundManager._drift_static_objects()`), so they start slowly, speed up
with the ramp-up and are gone by the time hyperspace punches in; leaving
pieces never wrap. A sky that loads mid-jump starts its pieces above home by
the distance the outro's slow-down will carry them (`_arrival_drift()`, a
function of the current speed, `JUMP_OUTRO_TIME`), so they slide in and stop
on their home pixel as the speed reaches rest.

---

## Background Hazards

A `BackgroundResource` carries at most one of two things: a region rule
(`global_modifier`, a `BackgroundModifierResource`) or a timed hazard
(`hazard`, a `BackgroundHazardResource`): a recurring environmental event with a
first-trigger delay, a repeat interval randomized from 2–4 turns on each trigger,
and an `EffectChain`. The hazard is
the place's — the Solar Corona's star flares, the Ion Storm Front's clouds
discharge — so it can't be stacked onto unrelated scenery, and the region's art
does part of the telegraphing.

Each is described by its resource alone. A rule's `create_modifier()` builds
its `modifier_script` (a `Modifier` subclass that constructs with no
arguments) and sets each of its `parameters` on the new modifier by property
name (Doldrums: `{&"cap": 3}` sets `AmountCapModifier.cap`; an unknown name is
a `push_error`); a modifier that declares `rule` is handed the resource. There
is no enum or match to extend. Its text (`modifier_name`, `description`, and
the `callout` the monitor floats when it bites) and a hazard's (`description`,
`headline`, `banner`) fill their `{placeholders}` through
`TextTokens.fill(text, self)` (7.5): a rule's `_text_tokens()` returns its
`parameters`, and a hazard's numbers come from the chain step marked
`text_token` (Solar Flare's damage step, `{amount}`). Both take an optional
`trigger_sfx` for the monitor, which plays its chime without one.
`test_background_rule_text.gd` pins every rule's and hazard's English.

Rules can set `duration_turns` (0 means untimed). `BackgroundModifierManager`
counts completed enemy turns and emits `background_modifier_countdown_changed`;
at zero it removes the rule from the engine. Doldrums lasts three rounds, with
its remaining turns on the monitor and arrival card. Fate's Corruption uses
`NoEscapeModifier.prevents_fleeing`: `Map.can_jump()` and the arrows' appended
`CAN_JUMP` activation check reject combat escapes while engine charge remains
available. Stray Fate nodes use `fate_outskirt.tres` (stars, shards and a timed
Fate Rift 1/6 swap, without a black hole).

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

- **`EnvironmentMonitor`**, the `OverheadConsole`'s hinged flap, flips down
  under the credit readout on arrival in any region with a rule or a hazard,
  fight or not (bringing the console down first if it's up), and stays until
  the jump out; nothing shows in hyperspace. Its screen's bezel is the lamp.
  Knocks swing the whole console on its rod. A hazard shows its icon alone outside a fight, and with the
  turns left beside it once `hazard_armed` starts the countdown. Every tick
  down flashes the unit and pops the digit; at one turn left
  the digit goes red and the lamp keeps blinking even once read; when it fires
  the monitor pops without a duplicate name callout. Clicking
  it opens the hazard's info panel (`EnvironmentMonitor.hazard_info()`,
  static): the countdown in the top line where a tile's panel says when it
  activates ("In 2 turns", yellow), then the full rule. The headline isn't there, since the full rule only repeats it; it
  belongs to the card. An open panel doesn't tick. Each fresh rule or hazard also
  spawns a `RegionAlert` card (unless `Globals.show_region_alerts`, Options >
  Game > Region Alerts, is off). On arrival it is the first beat of the
  `ArrivalIntro`: once the flap is down, the card unfolds out of its
  screen into the empty sky, the cockpit dims slightly, and it holds ~2 s (a
  click anywhere skips it; only first discoveries have a Close button. The first time the player ever
  reads a given rule or hazard, recorded by `CollectionManager.record_region`
  as `rule:<file>` / `hazard:<file>`, it has no timer and waits for Close; a hazard's card adds the
  countdown-first headline, `EnvironmentMonitor.hazard_headline()` ("In 2
  turns: shields drop, 3 dmg to all"), and holds 1.3 s longer) before folding back in, which kicks the monitor
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
`Source/Content/BackgroundResources/BackgroundHazards/`.

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
> info line from a rule that doesn't own the tile, `get_rule_side_text(tile)`
> a line in the panel's side column. `EffectEvent.changes_die_values()`
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
  activation, and `Events.tile_activated_by_die(tile, value)` straight after
  when a die (or hologram) did it, with its face (once per activation, echo
  or not). `TileGrid.activations_this_turn` counts them
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
│   ├── GlitchShader (glitch_shader.tscn)
│   ├── FPSCounter (fps_counter.tscn)
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
│   │   ├── OverheadConsole (MoneyIndicator + EnvironmentMonitor flap)
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
│   └── GameStateManager
│       └── SectorGenerator (the encounter lists)
├── GameAnimationPlayer (fade animations; game_start calls trigger_startup_sequence)
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
- Two locks: `dragging_allowed` (the tutorial's and the jump's, each on its
  own schedule) and `out_of_reach` (a die still arriving, see 8.1).
  `can_pick_up()` joins them; ask it, not `dragging_allowed`, whether the
  player can grab something now (the press, the hover thump and the
  AutoPilot do). `announce_next_arrival()` makes the next settle emit
  `reached_new_home`, wherever home has moved to by then

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

Each site is its own full-screen `.aseprite` in
`Art/Textures/UI/Cockpit/Damage/` (`crack_left`, `seam_dash_right`...),
exported by `tools/export_art.py`. The layered layout they were first cut
from, one layer per site, is
`Art/_Workfiles/Textures/UI/Cockpit/Damage/cockpit_damage.aseprite`. To add a
site, draw a new 320×180 `.aseprite` there, export, add a `CockpitDamageSite`
child in `cockpit_damage.tscn` at the point in the order it should open, and
set its `kind` and `emit_points`.
The smoke puffs and glass shards are `smoke_puff.aseprite` and
`glass_shard.aseprite` beside them, one frame per variant, exported as
`<name>-Sheet.png`.

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
`custom`, `section`, `spacer`, `note`, `next_column`, `enable_when`). A row
writes through `set_option()` and re-reads through `refresh()`, so the menu
shows live values after Defaults or a change made elsewhere. Within a column
the page makes every dropdown and button as wide as the widest
(`PixelDropdown.content_width()` measures a dropdown's longest item), and a
slider writes its value on its knob. A tab listed in `OptionsMenu._SUB_TABS`
gets several pages and an `OptionsSubTabs` row to switch them (Controls:
keyboard & mouse, controller; `BindingSlots` takes the input kinds to show).
`OptionsFrame` draws the panel to fit however many tabs there are, and its
static `draw_box()` is the pixel panel `OptionsSubTabs` and `ConfirmDialog`
draw too. Progress tools (main menu only) sit in their own section and ask in
a `ConfirmDialog` (`open(message, destructive, confirm_text)`) before acting.
To add an option: one `register()` call, one row, and its label and hint keys
in `translations.csv`.

**Pixel-perfect fullscreen.** The game is a 1920x1080 canvas
(`ScreenFrame.SIZE`: Globals.SCREEN_SIZE through the 6x cameras), letterboxed
by whatever factor fits, so art pixels come out uneven (10 and 11 screen
pixels at 1.8x). Godot's stretch settings can't scale it by exactly k/6:
integer stretch counts multiples of 1920x1080 and floors the content scale
factor, and fractional stretch always fills the screen. So
`PixelPerfectScaler` switches the window to canvas_items stretching on the
usual 1920x1080 base (native-resolution rendering, viewport unchanged) and
sets the root's `global_canvas_transform` to shrink that fit to k/6 and
centre it on whole pixels (`frame_rect_for()`). The global canvas transform
moves every CanvasLayer and maps mouse input too, so no other code knows; a
mask layer (127) blacks out the band left around the frame. It applies only
in fullscreen and rechecks on size and mode changes (macOS reports
fullscreen a few frames after the resize). An earlier version enlarged the
viewport instead, and everything that measured the viewport (the opening
cutscene's framing, screen-space layers) drew wrong.

**Window Scale.** `OptionsSettings.window_scales()` offers every whole scale
from `MIN_WINDOW_SCALE` (2) up to the largest whose window plus its OS frame
fits the screen's usable rect (menu bar, Dock and taskbar excluded). The
frame is measured with `window_get_size_with_decorations` /
`window_get_position_with_decorations` while windowed, once at boot before a
saved fullscreen applies, with a 64 px title-bar guess until then.
`_centre_window` centres the frame and keeps the title bar inside the usable
area. The list is built when the menu opens, so a move to another monitor
doesn't rebuild it. Fonts drawn at art scale (the menu's `TitleText`) pin
`oversampling=1.0` in their import, or canvas_items stretching re-rasterizes
them at screen resolution, off the art grid.

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
(codex, info panel). Readable Font (`FontSwap`, Display/) is one more font
profile, `readable.tres`: its Atkinson faces go in front and the language's
own fonts follow as fallbacks (see Fonts below). Atkinson is imported as MSDF
at `msdf_size` 192 (64 stair-stepped under nearest filtering at 6x), and its
faces carry a `baseline_offset` so capitals centre where the pixel fonts' do.

**Fonts (FontRoles).** Text names a role (`small`, `body`, `popup` for callout
words, and `digits`/`digits_small` for popup figures, the same m5x7/m3x6 face in
every profile so numbers read alike in every language), never a
font file or a raw size. Each role draws through one FontVariation wrapper
(`Assets/Fonts/Roles/<role>.tres`; `small`/`body` are the old
`m3x6_ui`/`m5x7_ui` with the same UIDs). A FontProfile per locale
(`Assets/Fonts/Profiles/<locale>.tres`, en_XA for pseudo, `readable.tres` for
Readable Font) maps each role to a FontFace (`Assets/Fonts/Faces/`: font,
unit size, fallbacks, baseline offset, a note). `Localization.set_locale`
calls `FontRoles.use_locale`, which sets each wrapper's base font and
fallbacks and the project theme's slot-type sizes, live. Loaded profiles are
kept for the session: freeing a profile's fonts while laid-out text still
points at them makes the TextServer read freed data (`Parameter "fd" is
null`). Slot types are theme type variations named `<Role>X<scale>`
(`BodyX6` = body at 6x its unit), listed in `FontRoles.SLOT_TYPES`; a
Label/RichTextLabel names one in `theme_type_variation`. Small text at x1 is
the theme default and needs nothing. Code that builds a Label sets
`theme_type_variation = FontRoles.slot(role, scale)`; code that draws text
uses `FontRoles.font(role)` / `FontRoles.size(role, scale)`.
`test_font_roles.gd` fails on a raw font/size override.
A face's `spacing_top` / `spacing_bottom` make its line box English's (13 px,
11 above the baseline, 2 below): Tiny5 +4 on top, Fusion 12 −2/−1. The role
wrapper carries the x1 spacing; a slot type at another scale draws through
its own FontVariation over the wrapper with the spacing times its scale
(`FontRoles._slot_font`), because Godot adds FontVariation spacing in whole
pixels whatever the size. English faces have none, so English slots draw
through the wrappers. 4.7.1: a FontVariation over a FontVariation takes the
base's font data and fallbacks but only its own spacing and baseline offset;
a RichTextLabel with a negative `line_separation` clips up to that many
pixels without showing a scrollbar (the codex body box is 67 px for this).
World text (the wrappers and the x1/x2 slots) rasterizes its bitmap fonts
at `ScreenFrame.ART_PIXEL_SCALE`: FontRoles sets `oversampling` 6 on every
non-MSDF font a profile names (`_prepare_world()`). A bitmap glyph is placed
on its own texel grid, so at oversampling 1 world text snapped to whole art
pixels (a hovered button's `[wave]` stepped 6 canvas pixels at a time in
German and Chinese, while English's MSDF m3x6 glided); at 6 it moves by
canvas pixels and still draws crisp 6x6 blocks. 4.7.1: automatic
oversampling doesn't count a Camera2D's zoom, and MSDF seams pixel fonts'
glyphs, so neither does this. Screen slots (`SCREEN_SLOT_MIN_SCALE`, x3 up)
always draw through their own variation over copies at the imported
oversampling (`_screen_font()`), or Chinese BodyX6 would rasterize at 432 px a
glyph. `FontRoles.unit_of(font)` gives a wrapper's or slot font's unit, for
TextFit's pixel grid.
Fonts per locale: en/en_XA m3x6@16 + m5x7@16; de/fr/es/pt_BR/ru Tiny5@8
for small, m5x7 otherwise; zh_CN and ja Fusion Pixel 12 (zh_hans / ja
build)@12 for every role. monogram extended is a same-size fallback behind
m3x6/m5x7 in every Latin/Cyrillic locale (it supplies "…" and "—").
4.7.1 facts: a fallback draws at the primary's size, so a script the role
font lacks needs the primary swapped; an unregistered
`theme_type_variation` name is ignored; GDScript folds a property read on a
`const` preload at compile time, so read wrappers through a variable.
Readable Font layers the profile's `readable` overlay (default
`Profiles/readable.tres`) over the language's faces; an overlay face must
have the unit size of the face it leads, since the language's font draws
behind it at that size (zh/ja use `readable_12`, the Tiny5 languages
`readable_8`, made with `tools/rescale_font_unit.py`). `Font.get_height()` is
the tallest font in the chain plus only the leading font's spacing (Labels
size lines by it; RichTextLabels by the fonts their glyphs used), and a
Control sized outside the tree keeps a stale theme-cache size, so
DamageNumber joins the tree before measuring.

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

**Dynamic prompts.** `InputManager.prompts_changed` reports deliberate device,
controller-family or binding changes. Virtual mouse events and pointer-warp
echoes keep controller prompts active. `InputPrompts` resolves inline control
tokens against the actual PAD binding and Xbox/PlayStation/Steam artwork;
unavailable glyphs fall back to the binding name. Tutorial cards refresh without
restarting their reveal, and the ghost demonstration refreshes its button icon.
Aseprite sources and the reproducible generator live under `Art/Textures/UI/InputPrompts/`
and `tools/build_input_prompts.py`.

**Controllers and rebinding** (Systems/Input/). `VirtualCursor` turns stick
and d-pad into a pointer (in frame units, clamped to the frame, real time),
warps the OS mouse and feeds real mouse events to `Input`, so clicks, drags,
hover and physics picking all work unchanged. `InputBindings` lists the
rebindable actions, serializes their events (one option per action,
"Controls/bind_<action>", defaults from project.godot) and resolves clashes
by swapping. `BindingSlots` is the Controls tab row.

### 7.5 Text and Localization

Player-facing text is English and is translated into zh_CN, ja, ru, de, fr, es
and pt_BR through two CSVs in `Localization/`, which never share a key (lint):

| | `translations.csv` | `content.csv` |
|---|---|---|
| Holds | UI and code text | content text (tiles, enemies, actions, callouts, keywords, hazards, rules, tutorial cards, ship-state dialogue, boss titles) |
| English written | in the CSV, by hand | in the resource's own field, in the inspector |
| Read with | `tr("KEY")`, auto-translated Labels | the resource's `display_*()` accessors |
| Keys | hand-picked (`INFO_ENGINE_EVASION`) | generated from the file (`HAZARD.SOLAR_FLARE.HEADLINE`) |

Both import with `compress=0` (compressed translations report 0 messages, so
`get_available_locales()` never offered them). Localization registers every
language's `translations.<l>.translation` at startup (project.godot names
only English's), so a column ships as soon as it has text; content
translations are loaded directly by ContentText.

**ContentText** (`Systems/Localization/content_text.gd`). A content type
declares its text: `_content_text_prefix()` (the key's first part, `TILE`)
and `_content_text_fields()` (a `ContentText.Field` per property: key suffix,
a context note for translators, an optional `_max_chars`). Each field gets a
`display_<field>()` accessor returning `ContentText.text(self, &"field")`. In
English that is the field itself, so an inspector edit shows before any sync.
Other locales read `content.<locale>.translation` and fall back to English for
an empty cell. Pseudo stretches the live field. Display code only ever calls
the accessors; the dev console, debug log and AutoPilot read the raw English
on purpose.

**TextTokens** (`Systems/Localization/text_tokens.gd`) is the one resolver for
design numbers in content text. Text names a number as `{name}`; a resource
embedded in the content's file (`EffectData`, `EffectChain`,
`ActivationResource`) marks the number it owns with `text_token` and, when
it isn't the class's default (`amount`, `base_repetitions`, `threshold`),
`text_token_value`: a small `Expression` over that resource's numeric
fields or other tokens (`-amount`, `range_max`, `low_max + 1`,
`amount + damage`). The root adds numbers that live on itself through
`_text_tokens() -> Dictionary`: a tile's countdown, a background rule's
`parameters`, a `StatusResource`'s `rule_values()`. Binding is by name, so
reordering a chain never rewires the text, and steps may share a name.
`fill(text, root)` runs inside the `display_*()` accessors of tiles,
hazards, rules and keywords, after `ContentText.text()` (so translations
fill too) and before `Tile.fill_data_tokens()` (`[data]` run-time
counters) and `Utils.format_text()` (`(die_N)` / keyword tokens).
`problems()` reports an unbound name or shared names that disagree, and
`literal_numbers()` finds digits left in prose. `test_tile_text_tokens.gd`
is strict for every tile: a literal that isn't data (a rule, a d6 face) is
listed in `LITERAL_EXEMPT` in `Systems/Localization/Tools/tile_text_tokens_tool.gd`
with its reason, and `RULE_NUMBERS` (`0`) is never matched. The converter
behind `tools/loc.sh tokens report|convert|verify` lives in the same file.
An enemy action's `(amount)` is different: its rolled value, filled at run
time.

**Keys** are `<PREFIX>.<file stem>.<SUFFIX>`. A resource embedded in another
file is keyed by its property path from the file's root
(`ENEMY_ACTION.SEIZE.EFFECT_CHAIN.EFFECTS_4.CALLOUT`; arrays by index,
dictionaries by key, or by position for resource keys such as a tile's
`event_responses`), read off the file's contents, so a re-save that renumbers
sub-resource ids can't change it. A root that isn't content names its part
after its class. A type whose file names repeat across folders adds the folder
(`_content_text_folder_in_key()`; ship states:
`SHIP_STATE.<folder>.<file>.DIALOGUE`). `duplicate()` drops
`resource_path`, so keys are also stamped on each resource as metadata
(`_content_text_owner`, never saved into a `.tres`), which duplicates copy:
runtime copies go through `ContentText.copy(res)` (`EnemyActionResource.copy()`
for actions, every rolled action being a deep copy).

**UI keys and plurals.** UI text lives in `translations.csv`. A scene's
Label or RichTextLabel holds the key as its `text` (Godot auto-translates
it; `Buttons/button.gd` re-translates on hover); text set from code goes
through `tr()`. The CSV ends in a `?plural` column (confirmed on 4.7.1):
a plural row names its plural id there, and the keyless rows under it are
its further forms, numbered by position, so they must never be sorted.
Code reads them with `tr_n(&"KEY", &"KEY_PLURAL", n)`
(`STATUS_BADGE_STACKS`, `CALLOUT_DICE_LOST`). `LocTable` calls the form rows
`KEY#2`, `KEY#3`, writes them back keyless, and an export asks a locale only
for the forms `TranslationServer.get_plural_rules()` gives it.

**Tooling** (`tools/loc.sh`, close the editor first). The GDScript behind it
lives in `Systems/Localization/Tools/` (`tools/` is `.gdignore`d):
`LocCatalog` finds every content field under `res://Source` (skipping
`Scenarios/TEST`), `LocTable` reads and writes a CSV keeping untouched rows
byte-identical, `LocPipeline` runs the steps, `LocLint` the checks and
`loc_sync.gd` is the CLI.
- `sync` rewrites `content.csv` (sorted by key, `translations.csv`'s columns,
  one row per line with `\n` escapes). `_en_hash` records the English each row
  last saw; a change marks that row's translations stale (kept). A key that
  vanished and a new one from the same file with identical English are
  matched one to one and renamed (`moved OLD -> NEW`); anything else is
  reported as an orphan, never deleted. `check` reports without writing.
  `sync --ui` would add hash tracking to `translations.csv` rows (not yet run).
- `export <locale>` writes every missing or stale row, UI and content alike,
  to `Localization/pending/<locale>.csv` (git-ignored). `import <file>
  [--status reviewed]` routes each key back to its CSV, adds a column for a new
  locale, warns on token, BBCode or length problems, re-imports and lints.
  `_status` is one word (`machine`) or per-locale pairs (`de=reviewed
  fr=stale`).
- `lint` (`test/core/content/test_localization.gd`, also in GUT): content English
  synced; filled cells keep `{x}`, `%d`, `(tokens)` and BBCode; text fits
  `_max_chars` (tags count 0, tokens 1, placeholders 2). Glyph coverage is
  report-only until each language has its font.
- Debug builds' dev console `lang <locale|pseudo>` switches to any language
  (`set_locale(locale, true)`); pseudo is reachable only this way and through
  the audit.

**Fitting text** (`Systems/Localization/TextFit/`). Text in a frame names its
box (where it may appear, in its parent's coordinates) and a `TextFitPolicy`
(max lines, `prefer` WRAP or SHRINK, `balance_lines`, `min_scale`,
`vertical_alignment`, `align_by_ink`, `break_words_last_resort`; presets
`single_line()`, `wrapping()`, `row_label()`, `paragraph()`). `TextFit.solve()`
measures the label's shown text (Label: translated text; RichTextLabel:
parsed text) in its own font, size and line spacing with one `TextParagraph`,
shaped once and re-broken per candidate width, and reads each glyph's ink
from its outline (`font_get_glyph_contours`, cached). Scales step in whole
canvas pixels per font pixel (`grid` = canvas pixels per unit, the world
camera counted at its resting 6x, times font size / `FontRoles.unit_of`), so
shrunk text stays crisp; it's `Control.scale`, never a font size override.
Per scale it breaks at word bounds only; a word wider than the line fails
that scale (no "Bildschirmwack / eln"); `BREAK_ADAPTIVE` only as the last
resort, reported `fits = false` with a `needed_scale`. Wrapped lines are
balanced (binary search for the narrowest width with the same line count).
Placement centres the optical band (each glyph's font's H, or 国 for
CJK/kana/Hangul/full-width, so accents and descenders don't shift a line)
and then clamps the true ink inside the box; `align_by_ink = false` centres
line boxes instead, for row labels beside Godot-drawn widget text. Full-size
text snaps to whole font pixels of its parent (the art grid), shrunk text to
canvas pixels. Where wrapped lines' ink would run into each other (Chinese
under the theme's RichTextLabel `line_separation` -4), the layout opens the
spacing, and `apply()` overrides that label's spacing constant (meta
`text_fit_line_spacing` keeps the theme's): Latin ink may touch across lines,
as English's tight spacing already lets a descender meet the capital below,
while an ideograph on either side gets a font pixel's gap. Glyph ink comes
from outlines; for MSDF faces (m3x6, Atkinson) it's moved by where 4.7.1
actually draws the field's quad (`_msdf_shift`: m3x6 capitals draw 0.4 of a
font pixel above their outline). Measured against rendering, pixel fonts'
predicted ink is within half a canvas pixel. `apply()` places the label
by its top-left with `vertical_alignment` TOP, `clip_contents` off and
autowrap matching the measurement. Components: `TextFitter` (internal child
of a hand-placed label; box = parent less padding, the authored rect, or
`box`; refits on its label's draw when text, font RIDs, size or box change,
on translation and theme changes; `offset` moves without refitting, which
`button.gd` uses for the disabled sink), `TextFitBox` (Container around one
label; fits to the width it's given and asks for the footprint height;
non-expanding, it hugs its text), `TextFitGroup` (members share the smallest
best scale, resolved once a frame), `TextFit.fit_line()` /
`draw_fitted_line()` for `draw_string`. A label's `text_fit` meta names its
fitter; `TextFit.result_of(label)`. Adopted: every `button.gd` button
(`_TEXT_FACES` per size), the options tabs (own face, one group, and
`_layout_tabs` squeezes widths proportionally past the minimum padding),
bottom bar and Progress buttons (groups), row labels (`row_label(2)`), the
hint strip (`paragraph()`), sub-tab titles (`fit_line`), and ConfirmDialog's
question (its panel follows `fitted`) and buttons. Not measured: inline
images and BBCode that changes fonts or sizes. Soft hyphens aren't usable:
4.7.1 draws the inserted hyphen in a system font when the pixel font lacks
U+2010.

**Checking every language.** `OverflowWatcher`
(`Systems/Localization/overflow_watcher.gd`, a child of the Localization
autoload once `loc_watch on` asks for it, debug builds only, for that
session) checks the visible Labels and
RichTextLabels every 0.5 s. It looks for text taller than its box, wider with
wrapping off, sideways out of its button or panel or with its ink above or
below it (`TextFit.laid_out_ink`), on a button a sibling overlaps, cut by the
screen edge (not counting what its ScrollContainer scrolls out of view), held
back by `visible_characters` for 2 s (a stuck typewriter), with a word split
by smart wrapping (`word_broken`), with wrapped lines whose ink touches
(`lines_collide`), or with glyphs the font lacks. A fitted label is only asked
whether its fit worked (`fit_failed`) and whether it wraps onto the lines the
fit measured (`fit_mismatch`: TextFit and Godot's line breaking disagree; a
label's wrap width is the width its lines were broken at, never its widest
line, as breaking also counts a line's trailing space). A flagged label gets a red
outline and one `Loc [locale] ...` line in the debug log
(`DebugLogger.note()`) with its node path and key (its own, a `loc_key` meta,
or a reverse lookup). The `loc_watch_ignore` meta opts a label out, and
`loc_watch off` stops it. `tools/loc.sh audit
[locale|pseudo|all] [surface ...] [--headless]` (dev console `loc_audit`) runs
`Source/Debug/LocAudit/` as its own process. That process drops the MCP
autoload before it binds 9090, logs to `user://loc_audit/debug_log.txt` and
saves nothing. `LocAuditStage` is an offscreen 1920x1080 viewport laid out like
the game. `LocAuditSurfaces` drives each of 13 surfaces (menus, tiles,
enemies, actions, factions, statuses, keywords, hazards, rules, tutorial,
shop/reward, callouts, errors) the way the game does, through Clickables,
`show_info()` and `Events`. Each item is photographed, cropped to its text and
run past the watcher's checks. English runs first. An item that reads as in
English counts as untranslated rather than being photographed, and `all`
skips locales with nothing translated. The report is
`user://loc_audit/report.html`, with `report.json` (`{results: {locale:
[{surface, id, label, image, flags, untranslated}]}, no_translations}`).
`--headless` writes flags without photos. Not yet surfaces: pause-menu
options, map, game over, jump gate, boss cards, scenario dialogue and the
arrival card.

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

**Dice on offer.** A die carries `Dice.delivery`: `DELIVERED` (the default),
`ON_OFFER` (a shop shelf, or salvage) or `ARRIVING` (taken, still flying into
the hand). Only a delivered die plays (`is_playable()`;
`_check_for_acceptor` returns early otherwise), so letting a shelf die go
over a tile just buys it. The die's own drop handler runs before the
shop's. Anything that offers a die calls `put_on_offer()`, and taking one goes
through `OfferIntake.take()`, which calls `begin_arrival()`: the die is
`Draggable.out_of_reach` until `reached_new_home` fires as it settles in the
hand (an arrival, not a timer, since the hand's slots can shift under it).

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
amount; either way the bound ally spends it at once. Raid ends in
`FEED_ALLY` too: it hands the die to the ship it hit (`Binding.HOSTILE_SHIP`,
read off its targeting before the relay; `hands_off_to_hostile()`), which
spends it on the same face. A ship on the player's side with a foe fighting
the player always rolls one (`EnemyActionSituation.owes_hand_off`,
`EnemyActionSelector._ensure_hand_off()`), so feeding an ally never starves
the enemy. Loops are ruled out at
selection: each (ship, face) is a node, a relay slot is its one edge to the
(ally, face) the die lands as, and the binder only binds a relay where
walking forward can't come back to it. When no ally qualifies, that one
slot is rerolled with relays excluded, so the graph stays loop-free by
construction with no retries. Ships on the player's side bind first, so when
a civilian and a pirate raid each other on one face, the pirate's slot is
the one rerolled and the civilian keeps the Raid it owes. `relay_visited` on the events is the backstop
(Scrambled can flip a die in flight). Hologram faces aren't scaled by the run's
damage multiplier.

**Ship vs ship.** `DamageEvent` records `last_damaged_by` and emits
`ship_attacked_ship` when one enemy hits another; `ScenarioManager` turns
pirate fire on a civilian into `ScenarioEvent.PIRATE_ATTACKED_CIVILIAN`. A
ship killed by another ship (`was_killed_by_ship()`) drops no reward, plays
no kill-confirm, pays no faction bounty and doesn't count toward RunStats.

**Stealing and escaping.** Seize (`seize.tres`, no damage) snatches the die
on its way home (`GRAPPLE`, then STOLEN; a comms laugh is still wanted, see
SOUND_EFFECTS.md) and keeps it (`KEEP_DIE_WITH_ACTOR`); the ship spends it next turn on whatever that face
shows. On the Cutpurse Seize is also the `fills_kept_faces` option, so a
stolen die lands on Seize again every turn and never comes home while the
ship lives; killed, it gives its dice away as any ship does. From its fourth
round (`COMBAT_ROUNDS`) the kept-face option is Getaway instead:
`EscapeWithDiceEvent` strands every die it holds, the one being spent
included, drops the player's `num_of_dice` by the real ones, emits
`enemy_left` and jumps away. It reads as DANGEROUS and, like Flee, is never
rolled while hidden.

**Leaving.** Flee and Getaway both finish with `await Enemy.jump_away(ship)`,
after their bookkeeping (deaf to the scenario, `enemy_left`, dice handed on or
stranded): a 0.8 s `JumpFx` charge, a small camera shake, the jump out
upward in the ship's faction colour (`FactionIdentity.color`, red without
one), then the ship and any dice it carries are hidden and freed. The hull
moves onto the art grid first (`EnemyGraphicsManager.ready_jump()` →
`pixelate()`) and the streak and ring draw through `JuicePixelated`, so the
stretch steps a game pixel at a time. It's static and waits on SceneTree
timers, not tweens: a coroutine on the ship would be dropped when the ship is
freed, and the event awaiting it would hang. The departing ship's
`health.death` is disconnected (no second `enemy_left`, wreck or reward from a
stray hit) and its click region is disabled. Death, Flee and Getaway are the
only ways a ship leaves a fight.

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
| `player_attacked(attacker)` | An enemy hit aimed at the player landed on shields or hull | Tiles (`ON_PLAYER_ATTACKED`) |
| `player_evaded(attacker)` | An enemy hit missed because the engines dodged it (`EvasionModifier`) | Tiles (`ON_PLAYER_EVADED`) |
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
| `tile_activated_by_die(tile, value)` | Straight after `tile_activated`, when a die or hologram activated it | `OutriggerSync` (pod thrust) |
| `pods_level` | The Outrigger's turn ended with both pods' thrust level and above 0 | Tiles (`ON_PODS_LEVEL`) |

Tiles also respond to `TileEvent.EventType` hooks via `event_responses`:
`ON_TURN_START`, `ON_TILE_PUSHED`, `ON_TILE_MANUALLY_MOVED`,
`ON_ENEMY_TURN_OVER`, `ON_PLAYER_HEALTH_HIT`, `ON_ENGINE_CHARGE_DRAINED`,
`ON_ADJACENT_TILE_ACTIVATED`, `ON_SURROUNDING_TILE_ACTIVATED`, `ON_PLAYER_ATTACKED`,
`ON_PLAYER_EVADED` (an enemy hit missed because the engines dodged it),
`ON_PODS_LEVEL` (the Outrigger's pods ended a turn level),
`ON_PLAYER_FATAL_DAMAGE`. Most of these enable
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
│   ├── Keywords/KeywordResources/<id>.tres     # Game terms (title, rule, tokens)
│   │
│   ├── BackgroundResources/                    # Backgrounds, hazards, place rules
│   │
│   └── ScenarioResources/
│       ├── scenario_resource.gd                   # Per-scenario data
│       └── reward_resource.gd                     # What a ship, faction or scenario pays out
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
│   │   ├── Map/fate_state.gd                   # Fate's rules and progress
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
│   ├── keywords.gd                            # Keyword lookups by id (KeywordResources)
│   ├── Localization/                          # ContentText, TextTokens, OverflowWatcher, Tools/ (loc.sh's LocCatalog etc.)
│   ├── utils.gd                               # format_text (colours, die icons, keywords)
│   │
│   ├── UI/                                    # Interface nodes
│   │   ├── InfoShower/info_shower.gd           # Hover info display
│   │   ├── PauseMenu/pause_menu.gd             # Pause/Quit UI
│   │   ├── Mainmenu/main_menu.gd               # Title screen
│   │   ├── MainMenu/MenuCaravan/               # Caravan flying past the title planet
│   │   └── ... other UI files ...
│   │
│   │   ├── JumpManager/jump_manager.gd          # Hyperspace transition
│   │   ├── HazardManager/hazard_manager.gd      # Background hazard countdown
│   │   ├── RunStats/run_stats.gd                # End-of-run tally
│   │   ├── FactionStanding/                     # The run's faction memory (ledger + node)
│   │
│   ├── TutorialManager/tutorial_manager.gd     # Tutorial state machine
│   ├── TutorialManager/GhostCursor/            # GhostCursor, GhostDemo, GhostTarget
│   ├── GameStateManager/game_state_manager.gd  # State transitions, checkpoints
│   ├── SectorGenerator/sector_generator.gd     # Deals each sector's map
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


### Multiplicative shield amplification

`EffectData.multiply_shields` marks a shield multiplier explicitly. The shield
handler snapshots each target separately and stamps `ShieldEvent.amplification_unit`
with original shields × base factor. `EffectEvent.amplify()` stays additive by
default; shield multiplier events override it so Amplify +1 changes 2× into 4×,
and +2 into 6×. Fortress Protocol+ adds its flat five-shield bonus separately.
Flat shield effects retain ordinary additive amplification.
