# Global Cleanup Plan

Codebase-wide clean-ups that span multiple files, rather than single-file style/bug
fixes (those live in `CLEAN_UP_PLAN.md`). Each item below is either carried forward
from "Refactor Plan NEW.md"'s trailing Step #19 (not yet executed, confirmed against
the current codebase), or drawn from cross-cutting findings already surfaced during
the `CLEAN_UP_PLAN.md` pass. Nothing here has been re-analyzed — this is a
consolidation of things already known, for later action.

---

## 2. Simplify `error_popup_manager.gd`

**Source:** Refactor Plan NEW.md, Step #19, Phase 2. Also touches the "worth
verifying" freed-instance-safety note already raised for this file in
`CLEAN_UP_PLAN.md`.

**File:** `Source/Systems/UI/ErrorPopupManager/error_popup_manager.gd`

**Steps:**
1. **Simplify storage:** remove `var _current_popups: Array[ErrorTextPopup]`;
   replace with `var _current_popup: ErrorTextPopup` — only one error popup is ever
   shown at a time in practice (confirmed during the `CLEAN_UP_PLAN.md` pass), so the
   array was unnecessary machinery. This also sidesteps the earlier
   `is_instance_valid()`-vs-truthiness concern, since there's only one reference to
   manage instead of a loop over several.
2. **Fix layout timing:** insert `await get_tree().process_frame` immediately after
   `add_child(error_text)` and before computing `error_text.global_position` from
   `error_text.size` — currently the size may not be finalized yet when the position
   math runs.
3. **Modernize the API:** rename the internal `_create_error_popup` to a
   public-facing `show_error`. Keep it connected to `UIEvents.error_text_popup` (per
   item 1 above) in `_ready()`.
4. **Simplify the centering math:** instead of computing
   `Vector2(-popup.size.x / 2, -popup.size.y)` in the manager, set up
   `ErrorTextPopup`'s scene with a centered Pivot Offset and Top-Center anchors, then
   just set `popup.global_position = global_pos` directly and let Godot's UI system
   handle centering.

---

## 3. Move `PauseMenu` under UI, not under Main

**Source:** Refactor Plan NEW.md, Step #19. **Confirmed against `Source/Scenes/main.tscn`, 2026-08-05** — no longer a "check before moving," this is real.

**Note:** `pause_menu.gd` the *script* already lives under
`Source/Systems/UI/PauseMenu/` — this item is about the **scene tree** placement.

Confirmed in `main.tscn`: `PauseMenu` is instanced as a **direct child of `Main`**
(`[node name="PauseMenu" parent="." ... instance=ExtResource(...)]`), a sibling of
`UI`/`Graphics`/`Systems` — not nested inside the `UI` `CanvasLayer` at all. It's
positioned at `Vector2(160, 90)` (screen-center, given the fixed camera at the same
position/zoom) purely to *visually* fake being screen-space UI, while every other
full-screen overlay (`InfoShower`, `DevConsole`, `GameOver`, `GlitchShader`,
`FadeIn`, `MouseCursor`) genuinely lives inside `UI` and renders in actual screen
space via `CanvasLayer`. This means `PauseMenu` only looks correct because the
camera never pans, zooms, or shakes differently than it does today — move it into
the `UI` `CanvasLayer` so it doesn't depend on that staying true.

---

## 4. Fix the global RNG determinism bug

**Source:** `CLEAN_UP_PLAN.md` — Top Cross-Cutting Finding #1 (highest priority).

**File:** `Source/Systems/UI/MainMenu/main_menu.gd`, line 32.

Remove the line `seed('Die Fighter'.hash())`. `game_state_manager.gd` has the exact
same line already commented out, which is strong evidence this fix was applied
there but missed here. Confirmed downstream effects if left in place: sector
layout, enemy behavior, dice rolls, and background selection are all deterministic
across every playthrough, since `main_menu.gd` runs before any of those systems
draw from the global RNG.

---

## 5. Clarity pass on `Health.change_shields()`'s clamp (not a bug — confirmed)

**Source:** `CLEAN_UP_PLAN.md` — originally flagged as a bug, retracted after
developer confirmation. Kept here only as a low-priority readability nit.

**File:** `Source/Systems/Components/Health/health.gd`, line 67.

`shields = clampi(shields, 0, shields)` was flagged as a no-op clamp that should
cap shields at some maximum (by analogy with `change_health()`'s
`clampi(health, 0, max_health)` immediately above it). The developer confirmed
shields are **intentionally uncapped** — floor at 0, no maximum — and this
expression already does exactly that: Godot's `clampi(value, min, max)` returns
`min` when `value < min` and `value` unchanged otherwise, so with `max` set to
`shields` itself, the ceiling branch can never trigger. No behavior change needed.

Optional clarity-only change: replace with `shields = maxi(shields, 0)`, which
expresses "floor at 0, no ceiling" unambiguously — the self-referential `clampi`
call is what caused this to be misread as a bug in the first place, and the next
reader (including future-you) will hit the same confusion without more context.

---

## 6. Fix the `Addons/` folder casing mismatch

**Source:** `CLEAN_UP_PLAN.md` — Top Cross-Cutting Finding #3.

The on-disk folder is `Addons/` (capital A), but `project.godot`'s
`[editor_plugins]` section and `effect_data_editor_plugin.gd`'s internal `preload`
both reference lowercase `res://addons/...`. Works today only because macOS's
filesystem is case-insensitive. Recommend renaming the folder to lowercase
`addons/` to match Godot's own convention and every existing reference to it
(rather than updating the references, since lowercase is the standard Godot
plugin-folder convention).

---

## 7. Delete the dead duplicate `engine_charger.gd`

**Source:** `CLEAN_UP_PLAN.md` — Top Cross-Cutting Finding #5.

- **Delete:** `Source/Systems/Game/EngineCharger/engine_charger.gd` (dead — verified
  via `.tscn` UID cross-reference that nothing points at it) and
  `Source/Systems/Game/EngineCharger/engine_charger.tscn` (also orphaned).
- **Move:** `Source/Systems/Game/MainViewer/engine_charger.gd` (the live copy) into
  `Source/Systems/Game/EngineCharger/`, alongside its already-live sibling
  `engine_particles_controller.gd`.
- **Update:** `main_viewer.tscn`'s `ext_resource` path for the script after the move.

---

## 8. Rename Resource files to match the project's naming convention

**Source:** `CLEAN_UP_PLAN.md`, multiple entries. This project's established
convention is `ClassName` → `class_name.gd` in snake_case for every `Resource`
subclass.

- `Source/Resources/SaveResources/game_save.gd` (class `GameSaveResource`) →
  `game_save_resource.gd`
- `Source/Systems/UI/InfoShower/InfoResource.gd` (class `InfoResource`, currently
  PascalCase filename) → `info_resource.gd`

Remember to update any `.tscn`/`.tres` `ext_resource` paths and `preload()`/`load()`
calls referencing the old filenames.

---

## 9. Relocate data-only Resource classes into `Source/Content/`

**Source:** `CLEAN_UP_PLAN.md`, multiple entries (Medium confidence on each — see
individual file entries in `CLEAN_UP_PLAN.md` for the full reasoning). These
currently live under undocumented top-level folders but are consumed exclusively by
Content-tier classes, matching the pattern already established by
`TileResources`/`EnemyResources`/`ScenarioResources` living under `Content/`.

- `Source/Resources/BackgroundResources/` (`random_background_resource.gd`,
  `static_background_object_resource.gd`, `background_resource.gd`) → move as a
  group under `Source/Content/`.
- `Source/Resources/SoundEffectResources/sound_effect_resource.gd` — reconsider
  whether this is actually Content or Libraries-tier (it's fairly game-agnostic,
  see its `CLEAN_UP_PLAN.md` entry) before moving.
- `Source/Resources/SaveResources/game_save_resource.gd` (after the rename in item
  8) → move under `Source/Content/`.
- `Source/Systems/Game/RewardManager/reward_resource.gd` → move under
  `Source/Content/`, alongside `reward.gd`'s current Systems-tier home (the script
  stays; only the data resource moves).

---

## 10. Delete dead code: `FactionSystem`

**Source:** `CLEAN_UP_PLAN.md`.

**File:** `Source/Content/Enemies/faction_system.gd`

Confirmed via `grep -rn "FactionSystem"` across the whole repo: this class and its
own `Faction` enum are never referenced anywhere else. The actual faction concept in
live use everywhere else is `ScenarioManager.Faction` (a different enum with
different members: `PIRATE/CIVILIAN/BOSS` vs. this file's
`PLAYER/PIRATE/CIVILIAN/SOLDIER`). Recommend deleting the file outright rather than
maintaining two parallel faction systems.

---

## 11. Consolidate duplicated `TileResource` directory scanning

**Source:** `CLEAN_UP_PLAN.md`.

The exact same "scan `Source/Content/Tiles/TileResources/` and
`Source/Content/Tiles/ComplicatedTileResources/` for `.tres` files, load each, and
filter to `TileResource` instances" logic is independently implemented three times:

- `dev_console.gd`: `_get_available_tile_names()` and `_load_tile_by_name()`
- `reward_manager.gd`: `_load_tile_resources()`

Recommend a single shared utility (e.g. a `TileResourceRegistry` autoload or a
static helper on `TileResource` itself) exposing something like
`get_all_tile_resources() -> Array[TileResource]`, used by all three call sites.

---

## 12. Fix `Draggable.snap_back()` being an empty stub

**Source:** `CLEAN_UP_PLAN.md`.

**File:** `Source/Systems/Components/Draggable/draggable.gd`, lines 173-174.

`func snap_back() -> void: return` does nothing, despite `tile_grid.gd` calling it
in two places under comments claiming it returns a tile to its home position. In
practice, a passive per-frame homing lerp elsewhere in `_process()` likely papers
over this, but it's worth actually implementing (or removing, if truly redundant
with the passive homing) rather than leaving a misleading no-op in place.

---

## 13. Register a handler for the orphaned "Receive Die from Target" subtype

**Source:** `CLEAN_UP_PLAN.md`.

`effect_data_inspector_plugin.gd`'s `DICE_CONTROL` dropdown lists 10 subtype names,
but `effect_registry.gd` only registers 9 handlers for that category —
`"Receive Die from Target"` has no corresponding handler. Check
`effect_enums.gd`'s `DiceControlSubtype` definition to confirm the exact enum value,
then either implement and register the missing handler or remove the option from
the dropdown/enum if it was never meant to ship.

---

## 14. Implement `pause_menu.gd`'s `_save_game()`

**Source:** `CLEAN_UP_PLAN.md`.

**File:** `Source/Systems/UI/PauseMenu/pause_menu.gd`, lines 39-40.

`_save_game()` is currently `print('Saving game!')` only — it doesn't persist
anything, despite being wired to both "return to main menu" and a button literally
named "Save and Quit". The codebase already has a `GameSaveResource`
(`game_save_resource.gd` after item 8's rename) schema for exactly this; this needs
an actual implementation that serializes current player/tile/scenario state to it
and writes it to disk.

---

## 15. Narrow `GameStateManager` to just the state machine

**Source:** Architecture discussion, 2026-08-05.

**File:** `Source/Systems/Game/GameStateManager/game_state_manager.gd`

Not a recommendation to make this a fuller state-machine pattern — with exactly 3
states (`IN_COMBAT`/`OUT_OF_COMBAT`/`GAME_OVER`) and no per-state enter/exit
behavior beyond emitting a signal, a full State-object pattern (like the one
`STYLE_GUIDE.md` itself demonstrates) would be over-engineering; the state enum
plus its custom setter is the right amount of machinery for what it's modeling.

The actual problem is responsibility size: the state enum/setter is ~20 lines: the
other ~150 are startup sequencing (`_ready`, `trigger_startup_sequence`) and a full
procedural sector-generation algorithm (`_randomize_sector_scenarios`, lines 86-144)
that has nothing to do with combat/out-of-combat state at all. Extract
`_randomize_sector_scenarios()` — and the `sector_size`/`empty_scenario`/
`shop_scenario`/`combat_scenarios`/`question_scenarios`/`boss_combat_scenarios`/
`fate_scenarios`/`starting_scenario` export fields it depends on — into a dedicated
`SectorGenerator` class/resource. `GameStateManager` keeps `current_game_save`,
the state enum, and startup sequencing; `SectorGenerator` becomes independently
tunable/testable without touching state-machine code at all.

---

## 16. Centralize scenario RNG seeding

**Source:** Architecture discussion, 2026-08-05. Directly related to item 4 (the
global-RNG-reseed bug) — this is the structural fix that would have prevented that
bug from being possible in the first place.

**Current state:** `Dice`, `Enemy`, and `BackgroundManager` each carry their own
independent `static func seed(seed_value: int)` method:
- `Source/Systems/Game/Dice/dice.gd` — `Dice.seed()`, called from `player.gd`'s
  `_load_scenario()`
- `Source/Content/Enemies/enemy.gd` — `Enemy.seed()`, called from
  `enemy_manager.gd`'s `Events.load_scenario` handler
- `Source/Systems/Graphics/BackgroundManager/background_manager.gd` —
  `BackgroundManager.seed()`, called from its own `Events.load_scenario` handler

All three are fed the same `scenario.scenario_seed` value, but from three separate
call sites in three separate files, each independently responsible for remembering
to call it at the right time. There is no single place that owns "this scenario's
randomness starts here" — which is exactly how `main_menu.gd`'s stray
`seed('Die Fighter'.hash())` (item 4) went unnoticed: nothing detects or guards
against something upstream poisoning the shared global RNG before any of these
three ever get a chance to seed it.

**Recommendation:** Centralize scenario-scoped seeding into one owned place —
either:
- (a) `ScenarioManager._load_scenario()` becomes the single call site that seeds
  `Dice`, `Enemy`, and `BackgroundManager` in one block (still three calls, but one
  place instead of three), or
- (b) introduce a small `ScenarioRNG` service (autoload or a field on
  `ScenarioManager`) that `Dice`/`Enemy`/`BackgroundManager` pull a
  `RandomNumberGenerator` instance from rather than maintaining their own static
  `rng` + `seed()` pair each. This also removes the duplicated
  `static var rng: RandomNumberGenerator = RandomNumberGenerator.new()` /
  `static func seed(seed_value): rng.seed = seed_value` pattern currently
  copy-pasted across all three files.

Either way, the goal is: one obvious place to look for "where does this
scenario's randomness get seeded," not three independently-triggered static
methods.

---

## 17. Tighten the `Events` bus / `ScenarioEngine` queue boundary in `enemy_manager.gd`

**Source:** Architecture discussion, 2026-08-05.

**File:** `Source/Systems/Game/EnemyManager/enemy_manager.gd`, `run_enemy_turn()`
(lines 130-145).

This is not a recommendation to stop using the global `Events` bus alongside the
`ScenarioEngine`'s event queue in general — they solve different problems.
`ScenarioEngine`'s queue is a resolution *pipeline* (modifier-interceptable,
strictly ordered) for things where a number can be adjusted before it lands
(damage, healing, shields). `Events` is fire-and-forget broadcast for UI feedback,
audio, tutorial hooks, and cross-manager sequencing that has no business being
modifier-interceptable. Keeping these as two systems is correct; collapsing them
into one would mean giving every `Modifier` the ability to intercept things like
"whose turn is it," which doesn't make sense.

The one spot worth tightening is this specific joint:

```gdscript
func run_enemy_turn() -> void:
    ...
    await scenario_engine.finished_processing_queue   # reaches into the engine's own signal
    Events.enemy_turn_over.emit()                     # re-broadcasts a different signal on the global bus
```

`EnemyManager` reaches directly into `ScenarioEngine`'s internal
`finished_processing_queue` signal to know when combat math has settled, then
re-broadcasts a *different* "turn over" signal on the global bus. It works, but a
reader has to already know `finished_processing_queue` is being reused as a
general cross-system synchronization primitive beyond its apparent scope
("this scenario engine's queue is empty"). Two options, either is fine:
1. Add a doc comment on `ScenarioEngine.finished_processing_queue` stating it's
   intentionally used as the general "combat step settled" signal beyond the
   engine's own internal bookkeeping, so the next reader of `enemy_manager.gd`
   isn't left to infer it, or
2. Have `EnemyManager` own its own completion signal instead of awaiting the
   engine's internal one directly from outside — e.g. `scenario_engine` emits
   `finished_processing_queue`, `EnemyManager` is the only listener, and
   `Events.enemy_turn_over` is emitted from that connection rather than from an
   `await` sitting in the middle of `run_enemy_turn()`.

This is the only place in the whole `CLEAN_UP_PLAN.md` pass where the boundary
between the two signal systems was genuinely blurry rather than cleanly layered —
not a sign to rearchitect either system.

---

## 18. Copy-paste duplication clusters — specific sources of truth

**Source:** Architecture discussion, 2026-08-05, consolidating duplication findings
scattered across `CLEAN_UP_PLAN.md`. This is the single biggest *recurring pattern*
found across the whole review — not any one architectural flaw, but a habit of
copying the nearest similar file rather than extracting shared logic. Each cluster
below names every duplicate site and where the single source should actually live.

### 18.1 — Starfield generation (3 copies)

| File | Function | Position formula |
|---|---|---|
| `Source/Scenes/Cutscenes/opening_cutscene.gd` | `_set_stars()` (inline double for-loop, ~lines 39-65) | `randf_range(0, screen_size.x)`, `randf_range(0, screen_size.y)` |
| `Source/Systems/UI/Capsule/capsule_mockup.gd` | `_add_star()` (lines 22-34) | `randi_range(0, screen_size.x)`, `randi_range(0, screen_size.y * 2) - 180` |
| `Source/Systems/UI/MainMenu/main_menu.gd` | `_add_star()` (lines 50-62) | identical to `capsule_mockup.gd`'s formula |

`main_menu.gd` and `capsule_mockup.gd` are byte-for-byte identical in body;
`opening_cutscene.gd` is the same shape with a different position formula.

**Recommended single source:** a new `StarfieldGenerator` — either a small
component script under `Source/Systems/Components/` (instantiated and configured
by each of the three scenes) or a static helper under `Source/Systems/Graphics/`,
parameterized by `star_count`, `star_scene`/`twinkle_scene`, and the position
formula (expose the two different formulas above as named modes, or just pick one
canonical formula and use it everywhere — worth deciding whether the visual
difference between the cutscene and the menu/capsule backgrounds is intentional
before unifying).

### 18.2 — Flash-by-color effects (3 copies)

| File | Functions | What differs |
|---|---|---|
| `Source/Content/Enemies/Components/EnemyGraphicsManager/enemy_graphics_manager.gd` | `_health_hit_flash()` / `_shields_hit_flash()` (lines 118-132) | `Globals.red` vs `Globals.blue` |
| `Source/Systems/Graphics/Vignette/vignette.gd` | `_health_hit_vignette()` / `_shield_hit_vignette()` (whole file, lines 14-27) | `Globals.red` vs `Globals.blue` |
| `Source/Systems/UI/Buttons/button.gd` | `_on_mouse_entered()` / `soft_highlight()` (lines 45-67, 86-106) | amplitude values (12/9/6 vs 9/6/4) and `hover_text_color` vs `soft_highlight_color` |

The first two are the exact same shape (two near-identical tween blocks differing
only by a `Color`); `button.gd`'s pair is the same *pattern* (two call sites that
build the same wave-text/tween structure, differing only in tunable values) even
though the specific effect is different.

**Recommended single source:** these are two separate concerns, not one shared
function across all three files — don't try to unify `enemy_graphics_manager.gd`
and `button.gd` together, they're different effects that happen to share a shape.
- `enemy_graphics_manager.gd`: collapse into one `_flash(color: Color) -> void`
  private method, called as `_flash(Globals.red)` / `_flash(Globals.blue)`.
- `vignette.gd`: same treatment, one `_flash_vignette(color: Color) -> void`.
- `button.gd`: extract `_apply_wave_text(amp: float, freq: float, color: Color) -> void`,
  called from both `_on_mouse_entered()` and `soft_highlight()` with their
  respective amplitude/color arguments.

### 18.3 — Options menu label↔value lookup tables (2-3 copies per setting)

| Setting | `options_menu.gd` (UI sync + selection handler) | `options_saving_manager.gd` (get + set) |
|---|---|---|
| Animation speed | lines 36-44, lines 195-203 | lines 84-94, lines 101-109 |
| FPS limit | lines 46-56, lines 208-216 | lines 122-132, lines 156-166 |
| Window scale | `_reduce_scale_options()` lines 73-83, `_on_scale_option_button_item_selected()` lines 224-243 | `_get_recommended_scale()` lines 196-207 |

Each of these three settings has its string-label ↔ numeric-value mapping
re-implemented independently 2-3 times across these two files. If a value is ever
added, removed, or reordered, it's easy to update some copies and silently miss
others.

**Recommended single source:** a new small data file — e.g.
`Source/Systems/UI/OptionsMenu/options_maps.gd` — holding `const`
`Dictionary`/ordered-array lookups for each of the three settings (label→value and
value→label directions, or just one direction plus a reverse lookup helper). Both
`options_menu.gd` and `options_saving_manager.gd` reference the same constants
instead of maintaining their own copies of each `match` block.

### 18.4 — `TileResource` directory scanning (3 copies)

| File | Function(s) |
|---|---|
| `Source/Systems/UI/DevConsole/dev_console.gd` | `_get_available_tile_names()` (lines 249-265), `_load_tile_by_name()` (lines 267-282) |
| `Source/Systems/Game/RewardManager/reward_manager.gd` | `_load_tile_resources()` (lines 15-30) |

All three walk the same two hardcoded directories
(`res://Source/Content/Tiles/TileResources/`,
`res://Source/Content/Tiles/ComplicatedTileResources/`), filter to `.tres` files,
and load each as a `TileResource` — differing only in what they do with the result
(collect names, find one by name, or collect all instances). See item 11 above for
the full recommendation (already tracked there — listed here again only so this
cluster stays alongside the others for the "where duplication tends to happen"
picture).

### 18.5 — Wishlist button (2 copies)

| File | Function |
|---|---|
| `Source/Systems/UI/PauseMenu/pause_menu.gd` | `_on_wishlist_button_pressed()` (lines 43-45) |
| `Source/Systems/UI/MainMenu/main_menu.gd` | `_on_wishlist_button_pressed()` (lines 96-98) |

Identical bodies, including the hardcoded Steam store URL string.

**Recommended single source:** a `const STEAM_STORE_URL` on `Globals`
(`Source/Systems/Autoloads/globals.gd`), or a one-line static helper (e.g.
`Utils.open_wishlist()`) — either removes the need to keep two copies of the URL
string in sync if it ever changes.

### 18.6 — `main_viewer.gd`'s mirrored tab-pair logic (internal duplication, not cross-file)

**File:** `Source/Systems/Game/MainViewer/main_viewer.gd`

`_show_systems()`/`_show_map()` (lines 43-52, 67-77) and
`_systems_hovered()`/`_map_hovered()` (lines 56-64, 80-88) are each pairs of
near-identical, mirrored logic within the *same* file, differing only in which tab
button/frame/color is targeted. Unlike the clusters above, this isn't spread across
files — it's worth flagging separately because the fix is different: a small
`TabButton`-style component (owning its own label/frame/hover-color state, with
`show()`/`set_hovered(bool)` methods) that `MainViewer` instantiates twice (once
per tab) would remove the internal mirroring without needing a new shared utility
file.

---

## 19-24. `Source/Scenes/main.tscn` — scene organization recommendations

**Source:** Architecture discussion, 2026-08-05, reviewing `main.tscn` directly
(scene tree + exported field values, not just the scripts it instances). Item 3
above (moving `PauseMenu`) was confirmed as part of this same review — see its
updated entry.

### 19. Remove the dead `Globals.jump_manager` singleton registration

**File:** `Source/Systems/Game/JumpManager/jump_manager.gd`, `_ready()`.

Checked how often each scene-registered `Globals.*` singleton is actually read
elsewhere in the codebase:

| Singleton | Reads elsewhere |
|---|---|
| `Globals.player` | 90 |
| `Globals.tile_grid` | 57 |
| `Globals.enemy_manager` | 24 |
| `Globals.targeting_computer` | 14 |
| `Globals.state_manager` | 11 |
| `Globals.map` | 9 |
| `Globals.background_manager` | 6 |
| `Globals.tutorial_manager` | 5 |
| `Globals.reward_manager` / `.money_indicator` / `.scenario_manager` | 3 each |
| **`Globals.jump_manager`** | **0** |

`Globals.jump_manager = self` is never read anywhere else in the codebase —
`JumpManager` only ever reaches *outward* (`Globals.map.request_jump_to_scenario.connect(...)`)
and reacts to/emits `Events` signals (`jump`, `load_scenario`, `start_scenario`).
Nothing needs to locate it. Delete the registration line.

**Process note worth adopting:** `ErrorPopupManager` and `Shop` correctly *don't*
register themselves in `Globals` (confirmed — neither has a `Globals.x = self`
line), because nothing needs to find them either. Default should be "don't
register a node in `Globals` unless something outside it will actually need to
find it" — not "register everything just in case." A one-line comment next to
each registration stating who reads it would have made this dead entry obvious
immediately instead of requiring a `grep` sweep to find.

### 20. Move `GameAnimationPlayer` out from under `GameStateManager`

**Node:** `Systems/GameStateManager/GameAnimationPlayer` in `main.tscn`.

This `AnimationPlayer` is nested three levels deep under `Systems/GameStateManager`,
but its own `root_node` is set to `NodePath("../../..")` — i.e. `Main` itself. Its
two real animations (`game_start`, `fade_out_to_main_menu`) both animate
`UI/FadeIn` and call methods directly on `Systems/GameStateManager`
(`trigger_startup_sequence`, `load_main_menu`) — neither has anything to do with
being physically parented under `GameStateManager`; the `root_node` override is
already doing all the work of reaching `UI/FadeIn` from wherever it sits. Move it
to be a direct child of `Main`, a sibling of `UI`/`Graphics`/`Systems`/`PauseMenu`,
matching what it actually animates and calls into.

**Related coupling note:** its method-call tracks hardcode exact method names
(`load_main_menu`, `trigger_startup_sequence`) on a specific node. This is the same
category of refactor-fragile coupling flagged throughout `CLEAN_UP_PLAN.md` for
hardcoded `get_node()` paths — just living in a `.tscn` animation track instead of
a `.gd` file, which makes it easy to forget it exists. If either method is ever
renamed, this breaks silently with no compile error. Worth treating
AnimationPlayer method-call tracks with the same suspicion as a
`get_node("../../Foo")` call during future review passes.

### 21. Confirm the `GameStateManager` / `SectorGenerator` split with scene-level evidence

**Supersedes/confirms item 15** — same recommendation, now backed by what's
actually exported on the node in `main.tscn`:

```
GameStateManager
  current_game_save = ...
  sector_size = 12
  empty_scenario = ...
  shop_scenario = ...
  combat_scenarios = [...]        (3 entries)
  question_scenarios = [...]      (2 entries)
  boss_combat_scenarios = [...]   (1 entry)
  fate_scenarios = [...]          (1 entry)
  starting_scenario = ...
```

8 of these 9 exported fields exist purely for sector generation, not state
management. Make the split in item 15 a literal sibling node under `Systems`: a
new `SectorGenerator` node holds those 8 fields; `GameStateManager` keeps only
`current_game_save` and calls into `SectorGenerator` (or listens for a signal)
rather than owning that config directly.

**Process note:** this is a good example of watching the *Inspector panel*, not
just file line count, for responsibility creep. `game_state_manager.gd` is only
170 lines — nowhere near the project's own 250-300 line split threshold — but its
exported-field list was the tell that a second, unrelated responsibility had moved
in. A growing Inspector panel on a node is often an earlier signal than the script
file getting long.

### 22. Remove or document `MouseCursor`'s `z_index = 1000`

**Node:** `UI/MouseCursor` in `main.tscn`.

`MouseCursor` sets `z_index = 1000`, which is almost certainly unnecessary: it's
already the *last* child listed under `UI`, so it would draw on top from tree
order alone (nothing else in that `CanvasLayer` sets a nonzero `z_index`). Reads
like insurance against tree order not being trusted to hold. Either remove it (if
tree order is reliable enough going forward) or keep it but add a comment
explaining why, so a future addition to `UI` doesn't get silently drawn underneath
it by accident.

### 23. Standardize UI element packaging: sub-scene vs. raw node + attached script

`InfoShower`, `DevConsole`, `GameOver`, and `PauseMenu` are each instanced
sub-scenes (`.tscn` + `.gd` pairs). `GlitchShader`, `FPSCounter`, `MouseCursor`,
and `FadeIn` are raw nodes (`ColorRect`/`RichTextLabel`/`Sprite2D`) with a script
attached directly inside `main.tscn`. Both groups are conceptually the same thing
— small, self-contained UI effects — but packaged inconsistently. The
raw-node group's shaders/textures also leak into `main.tscn`'s own top-level
`ext_resource` list (`glitch.gdshader`, `dice_area_highlight_shader.gdshader`,
`default_cursor_raw.png`, etc.) rather than being scoped inside their own
component scene, which is part of why that list runs to 69 entries.

Recommend wrapping `GlitchShader`, `FPSCounter`, `MouseCursor`, and `FadeIn` into
their own `.tscn` files each, matching the `InfoShower`/`DevConsole`/`GameOver`
convention. Adopt one packaging convention project-wide going forward rather than
deciding per-node — default to sub-scenes, since that's what most of the
project's other components already do (per the Components-tier findings in
`CLEAN_UP_PLAN.md`).

### 24. Process notes specific to scene (`.tscn`) organization

Distinct from the file/code-level habits noted elsewhere in this document — these
are about the scene tree itself, which doesn't show up in a `.gd`-only review:

1. **Screen-space UI has exactly one home: the `UI` `CanvasLayer`.** No exceptions,
   even for something that visually happens to line up with the camera today (see
   item 3 / `PauseMenu`).
2. **Document every `Globals.x = self` registration with who reads it.** Costs one
   comment line; turns "is this singleton still needed" into a glance instead of a
   `grep` sweep (see item 19 / `JumpManager`).
3. **Watch the Inspector panel for responsibility creep, not just script length**
   (see item 21 / `GameStateManager`).
4. **Treat `.tscn`-level hardcoded references — AnimationPlayer method-call
   tracks, signal connections to specific method names — with the same suspicion
   as a hardcoded `get_node()` path in a script** (see item 20). They're invisible
   to a review that only reads `.gd` files, which is exactly why they accumulate.
5. **Pick one packaging convention for "small self-contained UI thing with a
   script" and apply it project-wide** (see item 23), rather than deciding fresh
   each time a new one gets added.
