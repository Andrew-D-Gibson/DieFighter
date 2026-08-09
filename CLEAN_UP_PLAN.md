# Clean Up Plan

## Top Cross-Cutting Findings (read this first)

This pass covered all 106 entries in ANALYZE.md (101 analyzed, 5 stale/missing — see below). Full per-file detail follows; these are the handful of findings that span multiple files or seem highest-value to act on first:

1. **Global RNG determinism bug — likely the single highest-value fix.** `main_menu.gd` calls `seed('Die Fighter'.hash())` on the title screen, reseeding Godot's global RNG to a fixed value. `game_state_manager.gd` has the exact same line **commented out** (strong evidence this was already identified and fixed there but missed in `main_menu.gd`). Since `_randomize_sector_scenarios()`, `Enemy.seed()`, `Dice.seed()`, and `BackgroundManager.seed()` all ultimately derive from global-RNG calls seeded this way, **every playthrough currently generates the same sector layout, enemy behavior, dice rolls, and background selection.** See `main_menu.gd`, `game_state_manager.gd`, `enemy_manager.gd`, `player.gd`, `background_manager.gd`.
2. ~~`Health.change_shields()` has no effective upper limit~~ — **corrected by the developer:** shields are intentionally uncapped (floor at 0 only, no max). `clampi(shields, 0, shields)` (line 67) does correctly produce that behavior (Godot's `clampi` returns `min` when the value is below it, and the value unchanged otherwise since `max` is set to the value itself) — not a bug. Still worth a clarity pass: `maxi(shields, 0)` expresses the same "floor only" intent unambiguously, where the self-referential `clampi` call reads like a copy-paste error. See `health.gd`.
3. **Addon plugin will break on case-sensitive filesystems.** The `Addons/` folder (capital A) is referenced everywhere — `project.godot`, and the plugin's own preload — as lowercase `res://addons/...`. Works today only because macOS's filesystem is case-insensitive. See `effect_data_editor_plugin.gd`.
4. **`Draggable.snap_back()` is an empty stub** called by `tile_grid.gd` in two places under comments claiming it snaps tiles home — it does nothing, though a passive per-frame homing lerp elsewhere in the same file likely masks the practical impact. See `draggable.gd`.
5. **A duplicate, dead `engine_charger.gd`** exists at `Source/Systems/Game/EngineCharger/`, diverging in subtle ways (missing a null-guard, missing UI-refresh calls) from the actual live copy at `Source/Systems/Game/MainViewer/engine_charger.gd`. Recommend deleting the dead copy and relocating the live one into the `EngineCharger/` folder. See both `engine_charger.gd` entries.
6. **Inspector dropdown offers an effect subtype with no registered handler.** `effect_data_inspector_plugin.gd`'s `DICE_CONTROL` list has 10 entries; `effect_registry.gd` only registers 9 handlers for that category — "Receive Die from Target" has no handler. Selecting it in the editor would silently no-op at runtime.
7. **Directory-scanning for `TileResource` assets is duplicated three times** (two copies in `dev_console.gd`, one in `reward_manager.gd`) — a good candidate for a single shared utility.
8. **`_save_game()` in `pause_menu.gd` doesn't actually save anything** — it's a `print()` stub, despite being wired to a button literally named "Save and Quit."
9. **`FactionSystem` (faction_system.gd) is entirely dead code** — its own `Faction` enum is never referenced anywhere else; the codebase actually uses `ScenarioManager.Faction` throughout.
10. **A recurring "duplicated logic differing only by a color/value" pattern** shows up independently in `button.gd`, `enemy_graphics_manager.gd`, `vignette.gd`, `main_viewer.gd`, and `options_menu.gd`/`options_saving_manager.gd` (the latter pair also duplicating several lookup tables across files) — each is noted individually below with a specific extraction recommendation.

---

## Stale ANALYZE.md entries (files not found on disk)

The following 5 files listed in ANALYZE.md do not exist on disk and were skipped rather than analyzed:
- `Source/Content/Enemies/EnemyActions/EnemyActionFilters/enemy_action_filter.gd` — staged for deletion in current git status (`git status` shows `D`)
- `Source/Systems/Game/TileGrid/GridStatusEffects/grid_status_effect.gd` — not present, no matching git deletion either (folder doesn't exist under `Source/`)
- `Source/Systems/Game/TileGrid/GridStatusEffects/LockoutStatus/lockout_status.gd` — same as above
- `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_status.gd` — same as above
- `Source/Systems/Game/TileGrid/GridStatusEffects/AmplifierStatus/amplifier_tile_status.gd` — same as above

Recommend removing these 5 lines from ANALYZE.md once confirmed intentional (the GridStatusEffects logic may have been renamed/relocated already — worth a quick `grep -r "GridStatusEffect\|LockoutStatus\|AmplifierStatus"` to confirm nothing still references these class names before treating them as dead entries).

---

## opening_cutscene.gd
**Current responsibilities:**
- Procedurally spawns and animates a parallax starfield (regular + twinkling stars) for the opening cutscene
- Preloads and transitions to the next scene (`entering_cockpit_cutscene`) via threaded loading
- Plays hit VFX/SFX (flash shader, camera shake, particles) on the player ship, presumably called from an AnimationPlayer method track
- Handles click-to-skip input

**Style issues:** none found — blank-line-before-function spacing was checked line-by-line against every `func` in the file and consistently uses the double-blank-line convention demonstrated in STYLE_GUIDE.md lines 19-22.

**Coupling issues:**
- Lines 76-94 (`_player_ship_hit`) and line 69 hardcode VFX/SFX tuning values (`hit_flash_time = 1.5`, `particles.amount = 30`, `rotation = PI`, `explosion.amount = 20`) with no `@export`, so a designer can't tune hit-flash timing or particle counts without editing code. Minor — this is a one-off cutscene, not reused content.
- `_switch_to_next_scene()` and `_input()` (lines 97-113) are byte-for-byte duplicated in `entering_cockpit_cutscene.gd` (only the target scene UID differs) — see that file's Coupling issues below. Flagging both.

**Split recommendation:** No — under 300 lines, and every responsibility here (background animation, transition, hit-juice, skip-input) serves this one cutscene scene; no unrelated reasons to change independently. The duplicated transition logic is better addressed as an extraction (see Bugs/Coupling), not a split of this file's own concerns.

**Bugs:**
- Lines 90-94: `_player_ship_hit()` creates an `explosion` particle instance (`explosion_particles.instantiate()`), sets its `color`/`amount`, but then calls `$PlayerShip.add_child(particles)` again instead of `add_child(explosion)`. The `explosion` node is never added to the tree — it's instantiated and immediately leaked/discarded, and the original `particles` (hit particles) node gets added to the tree twice instead of once each. Traceable directly from the code: `particles` is added at line 88 already, then re-added at line 94 where `explosion` should have been used instead.

**Suggested folder:** Content — this is a specific narrative-scene controller with game-content-flavored presentation logic, using the sanctioned `Events`/`Globals` systems. The existing `Source/Scenes/Cutscenes/` location is a reasonable top-level bucket for one-off scene controllers, distinct from the Content/Systems/Libraries tiers.
**Confidence:** Medium — folder taxonomy for "Scenes" isn't explicitly covered by ARCHITECTURE_OVERVIEW.md's tiers, and I can't see what (if anything) instantiates or references this scene beyond the cutscene chain itself.

---

## entering_cockpit_cutscene.gd
**Current responsibilities:**
- Preloads and transitions to the main game scene via threaded loading
- Handles click-to-skip input

**Style issues:**
- Line 4: only a single blank line separates `var main_game_scene: String = ...` (line 3) from `func _ready() -> void:` (line 5). STYLE_GUIDE.md demonstrates a double-blank-line convention before function definitions (see lines 19-22, and repeated throughout the example). This is a real violation — the rest of this same file (lines 7-8 before `_switch_to_next_scene`, lines 18-19 before `_input`) correctly uses double blank lines, making the single blank line at line 4 an inconsistency within the file itself.

**Coupling issues:**
- `_switch_to_next_scene()` (lines 9-17) and `_input()` (lines 20-25) are byte-for-byte duplicated in `opening_cutscene.gd` (lines 97-113 there), differing only in the target scene UID variable name. This is the same threaded-scene-load-and-skip-on-click pattern implemented twice. Recommend extracting a small reusable helper (e.g., a `SceneTransitioner` component/script taking a scene UID as a parameter) that both cutscene scripts can use, since this pattern is content-agnostic and likely to recur for future cutscenes.

**Split recommendation:** No — the file itself is 26 lines and singularly focused; the fix here is extracting the *shared* logic into a new reusable script, not splitting this file's own responsibilities.

**Bugs:** none found.

**Suggested folder:** Content — same reasoning as `opening_cutscene.gd`.
**Confidence:** Medium — same caveat as `opening_cutscene.gd` regarding the "Scenes" bucket and unseen reverse dependencies.

---

## random_background_resource.gd
**Current responsibilities:**
- Holds a pool of eligible `BackgroundResource` entries
- Randomly selects one from the pool (given an externally-supplied RNG) and caches the current selection
- Exposes flags for whether reselection should happen on scenario load vs. manual background change (read/consumed elsewhere, not enforced by this class)

**Style issues:** none found — double-blank-line-before-function convention is followed consistently (lines 12-13, 24-25, 28-29).

**Coupling issues:** none found — the RNG is passed in as a parameter rather than reached for via a singleton, which is good decoupling; no autoload or node references.

**Split recommendation:** No — small, single-purpose resource, clearly cohesive.

**Bugs:** none found. The empty-pool guard (`push_error` + `return null` at lines 16-17) is a reasonable validation at a content-authoring boundary (a mis-configured resource with no eligible backgrounds).

**Suggested folder:** Content — this is a data-driven content resource in the same vein as `TileResource`/`EnemyResource`, which live under `Source/Content/`. It currently lives under `Source/Resources/BackgroundResources/`, a top-level folder not documented anywhere in ARCHITECTURE_OVERVIEW.md's file structure. Recommend relocating the whole `BackgroundResources` group under `Source/Content/` to match the established resource-folder convention (this itself, plus `static_background_object_resource.gd` and `background_resource.gd` below, all move together).
**Confidence:** Medium — the placement recommendation is about matching an established sibling-folder convention, not derived from visible reverse dependencies of this specific file.

---

## static_background_object_resource.gd
**Current responsibilities:**
- Data container for a single static background object placement: scene, position, scale, rotation, modulate, parallax level
- Exposes a trivial `get_parallax_level()` getter for an already-public `@export var`

**Style issues:**
- Line 10: only a single blank line separates `@export var parallax_level: int = 0 ...` (line 9) from `func get_parallax_level() -> int:` (line 11). STYLE_GUIDE.md demonstrates a double-blank-line convention before function definitions (lines 19-22) — this is a real violation, the only function in the file.

**Coupling issues:** none found.

**Split recommendation:** No — trivial data resource.

**Bugs:** none found. `get_parallax_level()` is redundant (the field is already `@export`-public and directly readable), but that's a minor design nit, not a defect.

**Suggested folder:** Content — same relocation reasoning as `random_background_resource.gd` above; these three files form one cohesive resource group and should move together.
**Confidence:** Medium — same caveat as `random_background_resource.gd`.

---

## background_resource.gd
**Current responsibilities:**
- Pure data container describing one background configuration: base color, nebula settings, star settings, debris settings, and a list of static objects

**Style issues:** none found — the file has no functions, so the blank-line-before-function convention doesn't apply anywhere.

**Coupling issues:** none found.

**Split recommendation:** No — pure data resource, single clear purpose.

**Bugs:** none found.

**Suggested folder:** Content — same relocation reasoning as the other two `BackgroundResources` files; move as a group.
**Confidence:** Medium — same caveat as the other two files in this group.

---

## sound_effect_resource.gd
**Current responsibilities:**
- SFX tuning data (name, play limit, volume, pitch, pitch randomness)
- Concurrent-play throttling: a `static var audio_counts` dictionary shared across every `SoundEffectResource` instance, keyed by `name`, incremented/decremented via `on_audio_start()`/`on_audio_finished()`
- Pitch-escalation state machine: tracks recent play timestamps and computes an escalating pitch offset for rapid repeated plays

**Style issues:** none found — blank-line-before-function spacing checked at every `func` boundary (lines 24-25, 30-31, 36-37, 43-44, 58-59) and consistently double-blank.

**Coupling issues:**
- `static var audio_counts: Dictionary[String, int]` (line 18) is process-lifetime global mutable state living inside a `Resource` class, keyed only by the human-readable `name` string rather than resource identity. Two different `.tres` resources that happen to share the same `name` value would silently share a play-count budget. This isn't one of the rubric's listed coupling patterns exactly, but it's the same underlying smell (implicit shared global state bypassing the `Events`/`Globals` systems) and worth calling out.

**Split recommendation:** No — only two responsibility categories are really in play here (data/config + a self-contained runtime throttling/escalation state machine), and the file is 67 lines. Cohesive enough as a "smart resource."

**Bugs:**
- Worth verifying: `on_audio_finished()` (lines 38-42) is the only path that decrements `audio_counts[name]`. If the node playing this sound is freed or the scene changes while the sound is still playing (before its `finished` signal/callback fires `on_audio_finished()`), the count for that `name` is never decremented. Since `audio_counts` is a `static var` with process lifetime, this would permanently and silently reduce the available concurrent-play budget for that SFX name for the rest of the session. I can't see the calling code in `SFXPlayer`/`sound_effects_player.gd` from this file alone to confirm whether it guards against this (e.g., via `tree_exiting` cleanup), so this is a risk to verify there rather than a confirmed defect.

**Suggested folder:** Libraries — nothing in this file references game-specific classes (no `Tile`, `Enemy`, `Events`, `Globals`); it's generic reusable audio-throttling/escalation logic that could be dropped into an unrelated project unmodified.
**Confidence:** Medium — I can't see `SFXPlayer`'s usage pattern to confirm there's no game-specific coupling implied by how it's invoked.

---

## game_save.gd
**Current responsibilities:**
- Pure data schema for a save file: player stats (health, max health, defense), dice count, money, tile placement state, current scenario index, and remaining sector scenarios

**Style issues:** Known naming inconsistency (already flagged in prior context, not re-derived here): the class is `GameSaveResource` but the file is `game_save.gd` rather than `game_save_resource.gd`, breaking the project's otherwise-consistent `ClassName` → `class_name.gd` snake_case convention seen across every other Resource subclass in this codebase (`BackgroundResource` → `background_resource.gd`, `SoundEffectResource` → `sound_effect_resource.gd`, etc.). This isn't demonstrated in STYLE_GUIDE.md itself, so it's a project convention rather than a documented style-guide rule, but it's a real, fixable inconsistency — recommend renaming to `game_save_resource.gd`.

**Coupling issues:** none found.

**Split recommendation:** No — pure, cohesive data schema.

**Bugs:** none found.

**Suggested folder:** Content — it directly references `TileResource` and `ScenarioResource`, both Content-tier classes, so it belongs alongside them rather than under the undocumented top-level `Source/Resources/` folder. Recommend relocating together with the `BackgroundResources` group noted earlier.
**Confidence:** Medium — placement judgment based on its Content-class dependencies, not on visible reverse-dependencies (what reads/writes this save resource).

---

## enemy_state_reward_resource.gd
**Current responsibilities:**
- Pure data resource tying together an enemy's spawn configuration for a scenario: which `EnemyResource` to spawn, its spawn path location (0.0-1.0), its starting `ScenarioShipState`, and its `RewardResource` on defeat

**Style issues:** none found — no functions, nothing to check.

**Coupling issues:** none found.

**Split recommendation:** No — small, single-purpose data resource.

**Bugs:** none found.

**Suggested folder:** Content — already correctly placed under `Source/Content/ScenarioResources/`, consistent with its sibling resources and its dependencies on other Content-tier classes (`EnemyResource`, `ScenarioShipState`, `RewardResource`).
**Confidence:** High — already located correctly, no relocation reasoning required.

---

## scenario_ship_state.gd
**Current responsibilities:**
- Data for one ship's dialogue/faction/attitude/on-enter effects at a scenario state
- Resolves state transitions in `handle_scenario_event()`: looks up the next state for a given `ScenarioManager.ScenarioEvent`, resolving through a `ScenarioShipStateProbabilityTransition` indirection if present, or falling back to "stay in the current state"

**Style issues:** none found — double-blank-line-before-function convention followed (lines 10-11 before `func handle_scenario_event`).

**Coupling issues:** none found — depends only on other Content-tier scenario classes (`ScenarioManager.Faction`/`ScenarioManager.ScenarioEvent` enums are read, not called into) and `Enemy.Attitude`.

**Split recommendation:** No — cohesive: one class owning "what this ship does when it enters this state" plus "what state comes next."

**Bugs:**
- Worth verifying: `handle_scenario_event()` is declared to return `-> ScenarioShipState`, but the local variable `next_state` is typed `ScenarioShipStateBase` (matching the `transitions` dictionary's value type, line 9) and is returned directly at line 21 without a cast or type check when it is *not* a `ScenarioShipStateProbabilityTransition`. If `transitions` ever holds a value that is exactly `ScenarioShipStateBase` (the empty marker base class) rather than one of its two concrete subclasses, this would return a value that doesn't satisfy the declared `ScenarioShipState` return type. In practice this likely never happens because `ScenarioShipStateBase` has no fields and is presumably never used directly in scenario authoring — but that's an authoring-discipline assumption the type system isn't actually enforcing here, and I can't confirm from this file alone whether `.tres` authoring ever places a bare `ScenarioShipStateBase` in a `transitions` dictionary. `validate_scripts` reports this file as compiling clean, consistent with GDScript's static checker not catching this particular covariance gap.

**Suggested folder:** Content — already correctly placed under `Source/Content/ScenarioResources/ScenarioShipStateScripts/`.
**Confidence:** High for folder placement; Medium for the bug note since it depends on `.tres` authoring discipline I can't verify from code alone.

---

## scenario_ship_state_base.gd
**Current responsibilities:**
- Empty marker base class (`extends Resource`) that `ScenarioShipState` and `ScenarioShipStateProbabilityTransition` both extend, allowing `transitions` dictionaries to hold either concrete type polymorphically

**Style issues:** none found — 3-line file, nothing to check.

**Coupling issues:** none found.

**Split recommendation:** No — a marker base class by definition has no responsibilities to split.

**Bugs:** none found.

**Suggested folder:** Content — matches its two subclasses, already correctly placed.
**Confidence:** High.

---

## scenario_ship_state_probability_transition.gd
**Current responsibilities:**
- Holds a weighted-probability table (`Dictionary[ScenarioShipState, float]`) mapping candidate next-states to selection weights
- Implements weighted-random selection (`get_next_state_from_probabilities()`) via cumulative-subtraction against a random value in `[0, sum_of_weights]`

**Style issues:** none found — double-blank-line-before-function convention followed (lines 5-6 before `func get_next_state_from_probabilities`).

**Coupling issues:** none found.

**Split recommendation:** No — single well-scoped algorithm, cohesive.

**Bugs:** none found. The weighted-selection algorithm (lines 8-22) is a standard, correct cumulative-weight selection (mathematically equivalent to the more common running-sum-then-compare approach, just implemented via subtraction). Worth verifying: the algorithm relies on `weighted_probabilities.values()` (line 8) and `weighted_probabilities.keys()` (line 18) returning entries in the same relative order across two separate calls on the same unmodified dictionary — Godot Dictionaries do preserve insertion order for this, but I'm flagging it as a runtime-semantics assumption rather than asserting it confidently. The fallback at the end (`pick_random()`) is reached only via floating-point rounding residue after the subtraction loop, not truly "never" as its comment claims — but the fallback behavior itself is still correct, so this is a stale/inaccurate comment, not a functional bug.

**Suggested folder:** Content — already correctly placed.
**Confidence:** High.

---

## scenario_resource.gd
**Current responsibilities:**
- Pure data resource for one scenario: map icon, background pool reference, sector-gate flag, starting enemy spawn list, per-faction reward table, and a scenario-specific RNG seed

**Style issues:** none found — no functions, nothing to check.

**Coupling issues:** none found.

**Split recommendation:** No — cohesive data schema.

**Bugs:** none found.

**Suggested folder:** Content — already correctly placed under `Source/Content/ScenarioResources/`.
**Confidence:** High.

---

## tile_event.gd
**Current responsibilities:**
- Pure data resource: an `EventType` enum (turn start, tile pushed, tile manually moved, player fatal damage) plus a `listen_only_for_self` flag, used as dictionary keys in `TileResource.event_responses_v2`

**Style issues:** none found — no functions, nothing to check.

**Coupling issues:** none found.

**Split recommendation:** No — trivial, cohesive data resource.

**Bugs:** none found. The explicit `= 100` jump on `ON_PLAYER_FATAL_DAMAGE` (line 8) looks like a deliberate gap left for future insertions rather than a mistake.

**Suggested folder:** Content — already correctly placed under `Source/Content/Tiles/TileEventListener/`.
**Confidence:** High.

---

## tile.gd
**Current responsibilities:**
- Resource-driven setup: reacting to `tile_resource`/`uses_remaining` being set, applying textures/sprite-frame state
- Input/interaction wiring: connecting `clickable`, `draggable`, and dice-drop (`_on_die_accepted`) component signals
- Core game logic: activation-criteria checking (`clears_activation_criteria`), building and queueing `TileActivationEvent`/`TileEventTriggeredEvent` onto the `ScenarioEngine`
- Tile-event dispatch/orchestration: `_connect_tile_event_signals()` wires four separate `Events` signals to `handle_tile_event()`, which looks up a matching `TileEvent` response and queues it
- Presentation/juice: `set_gray_out()` (saturation tween), `set_highlight()` (shader param), `_update_dice_queue_locations()` (queue layout math)
- UI info construction: `_get_tile_info()` builds an `InfoResource`, backed by a bespoke string-templating/expression-evaluation feature (`_replace_event_data_in_string()`) that extracts `[data]...[/data]` spans, resolves identifiers against `effect_data`, and evaluates the result via `Expression`

**Style issues:** none found — the double-blank-line-before-function convention was checked at every `func` boundary in the file and is followed consistently, including around the doc-commented `_find_matching_event_response` (lines 117-121), which matches the `##`-doc-comment-directly-above-declaration pattern shown in STYLE_GUIDE.md.

**Coupling issues:** none found — component dependencies (`draggable`, `clickable`, `shakeable`, `sprite_frames`, `dice_queue`, `can_accept_dice`) are all `@export`-injected rather than reached for via `$Path` traversal, and all `Events`/`Globals` usage is the sanctioned Content→Systems direction.

**Split recommendation:** Yes. This file is ~230 lines of actual logic and mixes at least 4 of the listed responsibility categories (input wiring, game state/logic, presentation/juice, signal-routing orchestration, plus a UI-templating utility) — a designer tuning the gray-out tween timing, a systems programmer changing activation-criteria dispatch, and someone extending the `[data]` string-templating syntax all touch this same file for unrelated reasons.
  - **Extract `_replace_event_data_in_string()`** into a small, game-agnostic utility (e.g. a new function in `Source/Systems/utils.gd`, which already exists as a general helper script) taking `(text: String, data: Dictionary) -> String`. It has no dependency on `Tile` beyond reading `effect_data`, so it's a pure function candidate and the most clear-cut extraction — no signal needed, just a static/free-function call.
  - **Extract the visual/juice methods** (`set_gray_out`, `set_highlight`, the `_saturation_tween`, and the sprite-frame updates currently embedded in the `uses_remaining` setter) into a small owned component (following the existing `Source/Systems/Components/` pattern, e.g. a `TileVisuals` component) that `Tile` calls directly (`tile_visuals.set_gray_out(...)`) since this is a tightly-owned rendering concern, not something that needs decoupling via signals.
  - **Extract `_connect_tile_event_signals()` + `handle_tile_event()` + `_find_matching_event_response()`** into a small dispatcher owned by `Tile` (e.g. `TileEventDispatcher`) that listens to the four `Events` signals itself and either calls back into `Tile` directly or emits a single `matched_event(tile_event)` signal for `Tile` to queue onto `scenario_engine`. This shrinks `_ready()`'s block of ad hoc lambda-based `Events` connections and isolates the "which stored response applies" lookup logic from the "how do I react to being clicked/dragged" wiring.
  - What stays in `Tile`: `tile_resource`/`uses_remaining` setup, `clears_activation_criteria()`, `_on_die_accepted()`, and ownership of `scenario_engine` — this is the actual "Tile" identity and its core game-state responsibilities.

**Bugs:**
- Worth verifying: the `uses_remaining` setter (lines 14-26) unconditionally dereferences `tile_resource.uses_per_combat` (line 16) and, when not `-1`, `sprite_frames.frame` (line 26), with no null guard — unlike the `tile_resource` setter just above it (lines 7-11), which explicitly checks `if sprite_frames:` before calling `_set_up_resource()`. Since both `tile_resource` and `uses_remaining` are `@export var`s with their own setters, and `uses_remaining` defaults to `-1` (line 14), if Godot's scene/resource deserialization applies the `uses_remaining` export value before `tile_resource` and `sprite_frames` are assigned, this setter would null-dereference. I can't confirm the exact export-property deserialization order from this file alone (this is exactly the kind of property-setter-initialization-order semantics that needs verifying against actual Godot behavior/test), so this is a risk to check rather than a confirmed defect — in practice it may never trigger if Godot always deserializes in declaration order and `tile_resource` (declared first, line 7) is always set before `uses_remaining` (declared second, line 14).

**Suggested folder:** Content — already correctly placed under `Source/Content/Tiles/`; this is core game-content behavior, not something to relocate.
**Confidence:** High for folder placement (already correct); Medium for the bug note (depends on Godot deserialization-order semantics I can't verify from this file).

---

## tile_resource.gd
**Current responsibilities:**
- Pure data resource: tile metadata (name/descriptions/hint text), rarity enum, textures, uses-per-combat, activation checks, effect chains (`effect_chain_v2`, `event_responses_v2`), dragging/queue-limit config

**Style issues:** none found — no functions, category grouping (`@export_category`) is consistent.

**Coupling issues:** none found.

**Split recommendation:** No — cohesive data schema, single reason to change (tile content authoring).

**Bugs:** none found.

**Suggested folder:** Content — already correctly placed under `Source/Content/Tiles/`.
**Confidence:** High.

---

## activation_resource.gd
**Current responsibilities:**
- Defines the `ActivationType` enum for tile activation criteria
- Holds a `Dictionary[ActivationType, Callable]` lookup table (`activation_functions`) implementing the actual satisfied/not-satisfied check per type, several of which read live game state via `Globals` (`state_manager`, `enemy_manager`, `targeting_computer`, `player`)
- Holds a parallel `Dictionary[ActivationType, String]` (`failed_activation_messages`) of player-facing failure text per type
- Exposes `criteria_satisfied(die)` and `get_criteria_fail_text()` as the lookup entry points

**Style issues:** none found — double-blank-line-before-function convention followed before `criteria_satisfied` (lines 122-124) and `get_criteria_fail_text` (lines 126-128, allowing for the trailing whitespace line).

**Coupling issues:** `Globals.state_manager`/`Globals.enemy_manager`/`Globals.targeting_computer`/`Globals.player` are read repeatedly across the `activation_functions` closures (lines 39, 46, 53, 72, 75, 78, 82, 86) — this is the sanctioned Content→Systems direction per ARCHITECTURE_OVERVIEW.md's Autoloads table, so not flagged as a violation; noting it once here since the pattern repeats many times in one file (flagging all instances together per the "flag all or none" rule, i.e., none).

**Split recommendation:** No — despite being ~130 lines with two sizeable dictionary literals, every entry in both dictionaries is added/changed together for one reason ("add or adjust an activation criterion"), which is the opposite of the "multiple unrelated reasons to change" split trigger. This reads as a cohesive lookup-table pattern, not an unrelated-responsibilities pile-up.

**Bugs:** none found. I specifically cross-checked `ENGINE_NOT_CHARGED`/`ENGINE_CHARGED` and `CANT_BE_ACTIVATED_WITH_DIE` for a suspected message/logic swap (their names are easy to transpose) and traced through both the boolean logic and the corresponding failure text — both pairs are consistent (e.g. `ENGINE_NOT_CHARGED` is satisfied when charge < max, and its failure message "ENGINE IS FULLY CHARGED" correctly describes why it fails when charge == max). All 10 `ActivationType` enum values have entries in both dictionaries, so `criteria_satisfied()`'s unguarded `activation_functions[type].call(die)` (line 125) won't currently `KeyError`.

**Suggested folder:** Content — already correctly placed under `Source/Content/Tiles/`.
**Confidence:** High.

---

## faction_system.gd
**Current responsibilities:**
- Defines a `Faction` enum (`PLAYER, PIRATE, CIVILIAN, SOLDIER`)
- Holds static `VALID_TARGETS` (who can attack whom) and `FACTION_ATTITUDES` (who feels how about whom) lookup tables
- Exposes `can_attack()` and `get_faction_attitude()` static query functions

**Style issues:** none found per demonstrated STYLE_GUIDE.md rules. Note (not a formal violation): line 1's comment (`# First, let's create a FactionSystem class to handle faction relationships`) reads like a leftover fragment from an AI/pairing session, and is redundant with the proper `##` doc comment on lines 5-6 — worth deleting for cleanliness even though STYLE_GUIDE.md doesn't demonstrate a rule against it.

**Coupling issues:** `FactionSystem` defines its own `Faction` enum, but I confirmed via `grep -rn "FactionSystem"` across the entire repo that this class name is **never referenced anywhere else** — not in any `.gd`, `.tscn`, or `.tres` file. Meanwhile, every other part of the codebase that needs a faction concept (`scenario_ship_state.gd` line 5, `scenario_resource.gd` line 9, and ARCHITECTURE_OVERVIEW.md's description of `ScenarioManager` faction tracking) uses `ScenarioManager.Faction` instead, which per ARCHITECTURE_OVERVIEW.md has a *different* member set (`PIRATE/CIVILIAN/BOSS`) than this file's `Faction` enum (`PLAYER/PIRATE/CIVILIAN/SOLDIER`). This is dead, orphaned code that duplicates (and diverges from) the faction concept actually in use — a strong candidate for deletion rather than cleanup.

**Split recommendation:** No — the question here isn't how to split this file, it's whether to keep it at all (see Coupling issues).

**Bugs:** none found in the logic itself (I checked `FACTION_ATTITUDES` for internally-inconsistent entries and the data is self-consistent), but the file appears to be entirely dead code per the grep evidence above.

**Suggested folder:** N/A — recommend confirming with the project owner whether this is safe to delete outright rather than relocating it.
**Confidence:** High that it's unreferenced (direct grep evidence); Medium on whether it's safe to delete (can't rule out dynamic/string-based instantiation I wouldn't catch via grep, though nothing in this codebase's patterns suggests that's how classes are looked up).

---

## enemy.gd
**Current responsibilities:**
- Component setup from `enemy_resource`: graphics, dice-queue position, health values, health-bar position/attitude, dialogue offset (`_update_resource()` and its five `_update_*` helpers)
- Signal wiring/orchestration: four separate `_connect_*_signals()` methods wiring `health`, scenario `Events`, combat `Events`, and `dice_manager` signals together
- Scenario state-machine handling: `_handle_scenario_event()`, `trigger_state_effects()`
- Turn-action generation: `generate_turn_actions()` — a ~45-line weighted-random selection algorithm choosing 6 actions per turn, respecting `force_include` options and tutorial-forced actions
- Turn execution: `run_turn()` builds and queues one `EnemyActionEvent` per queued die onto the `ScenarioEngine`
- Death handling: `_on_death()` mixes reward-spawning, SFX, particle VFX, and `queue_free()`
- Click handling: `_on_clicked()` retargets the targeting computer
- Static, process-lifetime shared state: `static var rng` (documented and intentional — matches ARCHITECTURE_OVERVIEW.md 8.4's "Shared RNG per scenario") and `static var forced_actions` (tutorial action injection)

**Style issues:**
- Lines 86-87: only a single blank line separates the closing `)` of `_connect_health_signals()` (line 86) from the `## Connects all scenario-related signals` doc comment / `func _connect_scenario_signals()` (lines 88-89). Every other function boundary in this file (I checked all of them) uses the double-blank-line convention demonstrated in STYLE_GUIDE.md lines 19-22, making this one spot an inconsistency within the file itself.

**Coupling issues:** none found — all `Globals`/`Events` usage is the sanctioned Content→Systems direction, and component references (`health`, `graphics_manager`, `dice_manager`, `dialogue_manager`) are `@export`-injected rather than reached for via path traversal.

**Split recommendation:** Maybe. Much of the presentation/graphics work is already extracted into owned components (`EnemyGraphicsManager`, `EnemyDiceManager`, `EnemyDialogueManager`, `Health`), so this file is mostly orchestration-glue plus the Enemy's own turn logic — reasonably cohesive as "the Enemy's behavior," not an obvious multi-way split. The one piece that stands out as a distinct, separately-tunable concern is `generate_turn_actions()` (turn-AI/balance logic) together with its supporting state (`turn_actions`, `forced_actions`, `rng`): it's a self-contained weighted-random algorithm that a designer would iterate on independently of anyone touching signal wiring or death VFX. Recommend extracting it into a small dedicated class (e.g. `EnemyTurnActionGenerator`) that `Enemy` owns and calls into — this would also make the `forced_actions`/`rng` shared-state pattern explicit and easier to reason about (see Bugs below) rather than living as implicit static state alongside orchestration code.

**Bugs:**
- Lines 219-222: in `generate_turn_actions()`, the early-return path (`if len(turn_actions) >= 6: turn_actions = turn_actions.slice(0,6); return`) skips the `turn_actions.shuffle()` call (line 236) **and** the loop that assigns `activating_die_number` to each action (lines 239-241). Since `run_turn()` looks up the action to execute by array position (`turn_actions[die.value - 1]`, line 256) rather than by `activating_die_number`, gameplay itself still works — but `activating_die_number` exists specifically "so it can display the correct hint text when clicked" (comment, line 238). For any enemy whose forced tutorial actions plus `force_include` options fill all 6 slots (triggering this early return), the intent/hint UI (`TargetingComputer`, per ARCHITECTURE_OVERVIEW.md) would show stale or default `activating_die_number` values instead of the real die-to-action mapping.
- Line 106: `scenario_state = new_state` in `_handle_scenario_event()` is redundant — it unconditionally re-assigns the same value that was already assigned inside the `if new_state != scenario_state:` block just above (line 104), or is a no-op reassignment when the branch was skipped (since `new_state` would already equal `scenario_state` in that case). Not harmful, but dead weight worth deleting.
- Worth verifying: `static var forced_actions` (line 50) is shared across every `Enemy` instance and drained via `.slice()` in `generate_turn_actions()` (lines 199-203), which every enemy calls in response to the same `Events.player_turn_start` signal (line 116). If a tutorial scenario ever has more than one enemy on screen while using `forced_actions` to script a specific enemy's action, whichever enemy's turn-generation happens to run first (an order determined by scene-tree/signal-connection sequencing, not by which enemy the tutorial intended) would consume the forced actions instead. I can't confirm from this file alone whether any tutorial scenario actually has multiple simultaneous enemies while using this mechanism, so this is a risk to check against the tutorial content rather than a confirmed defect.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/`.
**Confidence:** High for folder placement and the confirmed bugs (both traced through concrete code paths); Medium for the `forced_actions` ordering risk, which depends on tutorial-content specifics I can't see from this file.

---

## disabler_graphics_manager.gd
**Current responsibilities:**
- Plays a continuous looping bob-tween animation on two `Sprite2D` parts (`left_x`, `right_x`), presumably the visual "disabled" X-marker overlay for a ship

**Style issues:** none found — double-blank-line-before-function convention followed (lines 5-6 before `func _ready`).

**Coupling issues:** none found — component references are `@export`-injected, no autoload or path-traversal usage.

**Split recommendation:** No — trivial, single-purpose visual effect script.

**Bugs:** none found. The tweens are local variables that go out of scope when `_ready()` returns, but Godot's `Tween` objects are kept alive by the scene tree while running/looping, so this is a standard and safe pattern, not a leak.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/EnemyShipGraphicScenes/` as a per-enemy-type visual effect.
**Confidence:** High.

---

## enemy_health_bar.gd
**Current responsibilities:**
- Extends `HealthBarController` (Systems component) to add an "attitude indicator" visual: a sprite frame that changes based on `Enemy.Attitude`, with a distinct tween animation per attitude (friendly spin+pop, neutral quick click, aggressive pop)

**Style issues:**
- Lines 13-36 (`set_attitude_indicator`'s body) are indented two tabs deep instead of one, inconsistent with every other function body in this same file (e.g. `_handle_running_tween`, lines 41-44, uses single-tab indentation) and with the single-tab-per-nesting-level convention demonstrated throughout STYLE_GUIDE.md's example. This doesn't break parsing (GDScript only requires consistent indentation within a block), but it's a real, demonstrable inconsistency confined to this one function.

**Coupling issues:** none found — `$AttitudeIndicator` references (used 7 times) are single-level child lookups within this node's own subtree, not the "deep/external path" pattern the coupling rubric targets.

**Split recommendation:** No — small, single-purpose visual component; all four functions serve the one "attitude indicator feedback" responsibility.

**Bugs:** none found. The `if $AttitudeIndicator.frame != N:` guards (lines 15, 23, 31) correctly prevent restarting an already-playing state's animation.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/Components/EnemyHealthBar/`; it specializes the generic `HealthBarController` System component with Enemy-specific (`Enemy.Attitude`) behavior, so Content is appropriate rather than Systems.
**Confidence:** High.

---

## enemy_dice_manager.gd
**Current responsibilities:**
- Extends `DiceQueue` (Systems component) to add enemy-specific visual scaling on add/remove (dice shrink to 0.75x while held by an enemy)
- Lays out held dice in a grid pattern above the enemy ship (`_update_dice_queue_locations`)
- Redistributes this enemy's remaining dice to other living enemies or the player when the enemy dies/leaves (`give_away_dice`)

**Style issues:** none found — double-blank-line-before-function convention checked and followed at every boundary (lines 3-4, 8-9, 13-14, 18-19, 28-29).

**Coupling issues:** none found — `Globals.enemy_manager`/`Globals.player` (lines 32, 39) are the sanctioned Content→Systems direction.

**Split recommendation:** No — small, cohesive specialization of the base `DiceQueue` component.

**Bugs:** none found. I initially suspected `give_away_dice()`'s backward iteration (`range(len(queue)-1, -1, -1)`, line 34) combined with mutating `queue` mid-loop (via the target's `add()` → base `DiceQueue.add()` → `die.host_queue.remove(die)`, which erases from *this* queue) might skip or double-process entries, but traced it through `dice_queue.gd`: iterating backward while erasing at the current index is safe (already-visited higher indices are never touched by a later, lower-index erase), so this is correct.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/Components/EnemyDiceManager/`; it's an Enemy-specific specialization of the generic Systems `DiceQueue`.
**Confidence:** High.

---

## dice_queue.gd
*(Pulled forward from its later position in ANALYZE.md to cross-check `enemy_dice_manager.gd`'s `give_away_dice()` correctness — analyzed fully here rather than re-reading later.)*

**Current responsibilities:**
- Base dice-queue behavior: `add()` (transfers `host_queue`, optionally destroys holographic dice, optionally randomizes value, appends to `queue`, emits `die_added`), `remove()` (erases from `queue`, emits `die_removed`), `has_value()` query

**Style issues:** none found — double-blank-line-before-function convention followed (lines 8-9, 33-34, 39-40).

**Coupling issues:** none found — no autoload dependencies; this is a clean, decoupled base component.

**Split recommendation:** No — small, single-purpose, cohesive base component.

**Bugs:** none found. `add()`'s ordering (remove from previous host first, line 12-13; then possibly free if holographic, line 16-18; then append, line 26-27) is correct and is what makes `EnemyDiceManager.give_away_dice()`'s backward-iteration pattern safe (see that file's notes above). The `if die not in queue:` guard (line 26) defends against double-adding a die that's already present.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Components/DiceQueue/`, matching the documented Components composition pattern.
**Confidence:** High.

---

## enemy_graphics_manager.gd
**Current responsibilities:**
- Ship graphics instantiation/replacement (`update_ship_graphics`)
- Death animation sequencing: hides health bar, fades ship transparency via tween, spawns and awaits a death-explosion sprite (`play_death_animation`)
- Health bar forwarding: position, attitude, and health-component wiring (`set_health_bar_position`, `set_health_bar_attitude`, `set_health_bar_health`)
- Hit-reaction orchestration: shake + color flash on shields/health damage (`on_shields_hit`, `on_health_hit`)
- Idle bobbing animation (`start_bob_tween`/`stop_bob_tween`)
- Hit-flash shader triggering, nearly duplicated between health and shields (`_health_hit_flash`, `_shields_hit_flash`)
- Transparency helper (`_set_transparency`)

**Style issues:**
- Line 21: only a single blank line separates `var _bob_tween: Tween` from the `## Sets up the ship graphics and associated components` doc comment / `func update_ship_graphics()` (lines 22-23). Every other function boundary in this file (checked all of them) uses the double-blank-line convention from STYLE_GUIDE.md lines 19-22, making this single spot an inconsistency within the file itself.

**Coupling issues:**
- `start_bob_tween()` (line 107) calls `get_parent().moving_in_world` — a direct, untyped property read on the parent node. This assumes the parent is specifically an `Enemy` node with a `moving_in_world` field, with no compile-time enforcement (`get_parent()` returns a generic `Node`). Since this component lives in the `Source/Content/.../Components/` composition pattern (meant to be an owned, somewhat interchangeable part), reaching into a specific parent's internal field is the same category of fragility the coupling rubric targets for sibling/parent reaches — recommend either exporting `moving_in_world` awareness into this component directly (e.g., an `@export var suppress_bob: bool` toggled by `Enemy`) or exposing a getter method on `Enemy` rather than reading its field by convention.
- `_health_hit_flash()` (lines 118-123) and `_shields_hit_flash()` (lines 127-132) are near-duplicates — identical tween structure and timing, differing only in the `flash_color` value (`Globals.red` vs `Globals.blue`). Recommend collapsing into one `_flash(color: Color)` helper.

**Split recommendation:** No — despite covering many methods, every one of them serves the single responsibility "enemy visual/presentation feedback"; this isn't a case of unrelated concerns piling up, just one component with several related effects. The duplication noted above is a de-duplication opportunity, not evidence for a structural split.

**Bugs:** none found. Traced `update_ship_graphics()`'s `queue_free()`-then-immediate-reassignment pattern (lines 24-26) and confirmed it's safe (Godot defers the actual free, so overwriting the reference doesn't clash with the pending deletion of the old node).

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/Components/EnemyGraphicsManager/`; it directly references `Enemy.Attitude` and assumes an `Enemy`-shaped parent, so it's Enemy-specific Content rather than a generic Systems component.
**Confidence:** High.

---

## enemy_turn_action_list.gd
**Current responsibilities:**
- Trivial data wrapper: an array of `EnemyActionOptionResource` representing one turn's pool of possible actions

**Style issues:** none found — no functions, nothing to check.

**Coupling issues:** none found.

**Split recommendation:** No — trivial wrapper.

**Bugs:** none found.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/EnemyActions/EnemyTurnActionList/`.
**Confidence:** High.

---

## enemy_action_resource.gd
**Current responsibilities:**
- Data for one concrete enemy action: name, description, textures, `effect_chain_v2`, and a rolled `intent_amount`
- A clamped `activating_die_number` setter (restricts to 1-6)
- Display logic: `get_intent_amount_text()` and `show_info()`, which builds an `InfoResource` (substituting `(amount)`/die-number text into the description) and emits it via `Events.show_info`

**Style issues:** none found — double-blank-line-before-function convention followed (lines 19-20 before `get_intent_amount_text`, lines 25-26 before `show_info`).

**Coupling issues:** none found — `Events.show_info.emit()` is the sanctioned Content→Systems direction.

**Split recommendation:** No — cohesive: this is a "concrete action + how to describe it" data-and-display resource, all serving one purpose.

**Bugs:** none found. The `[color=yellow]` BBCode tag opened in `show_info()` (line 35) is never explicitly closed with `[/color]`, but since this string is used wholesale as `bottom_label_text` and nothing follows it, this doesn't produce a visible defect — Godot's `RichTextLabel` handles an unclosed tag at the end of text without error.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/EnemyActions/EnemyActionResources/`.
**Confidence:** High.

---

## enemy_action_option_resource.gd
**Current responsibilities:**
- Configuration for one weighted action choice: `base_action` reference, `weight`, `min_amount`/`max_amount` range, `force_include` flag
- `get_action()`: deep-duplicates `base_action`, rolls a random amount via `Enemy.rng`, and stamps it onto the duplicate's `intent_amount`

**Style issues:** none found — double-blank-line-before-function convention followed (lines 11-12 before `get_action`).

**Coupling issues:** none found beyond the expected, documented dependency on `Enemy.rng` (the shared per-scenario RNG, per ARCHITECTURE_OVERVIEW.md 8.4) — this is a normal sibling-Content-class reference, not an autoload misuse.

**Split recommendation:** No — small, single-purpose resource.

**Bugs:**
- Lines 10 and 20-21: `var amount: int = 0` is a persistent instance field on `EnemyActionOptionResource`, but it's only ever written (`amount = Enemy.rng.randi_range(...)`, line 20) and immediately copied to the returned duplicate's `intent_amount` (line 21) — I confirmed via `grep -rn "\.amount\b"` across the whole `Source/` tree that nothing ever reads `EnemyActionOptionResource.amount` afterward. Since `EnemyActionOptionResource` instances are shared `.tres` content assets (potentially referenced by multiple `EnemyTurnActionList`s / enemies), storing this roll result as a field on the shared resource rather than a local variable serves no purpose and is an unnecessary, slightly risky pattern (mutating shared-resource state on every `get_action()` call for no read benefit). Recommend making `amount` a local variable inside `get_action()` instead of a class field.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/EnemyActions/`.
**Confidence:** High.

---

## action_popup.gd
**Current responsibilities:**
- Plays a scale+fade "popup" tween on a sprite, then emits `popup_finished` and frees itself

**Style issues:**
- Line 7: only a single blank line separates `signal popup_finished()` (line 6) from `func _ready()` (line 8), where STYLE_GUIDE.md's demonstrated convention (lines 19-22) calls for a double blank line before a function definition.

**Coupling issues:** none found beyond what's covered under Bugs below (the hardcoded `$Sprite2D` is a same-subtree child reference, not the deep/external path pattern the coupling rubric targets).

**Split recommendation:** No — trivial, single-purpose popup script.

**Bugs:**
- Line 3 declares `@export var sprite: Sprite2D`, presumably so this script could be pointed at a differently-named or externally-supplied sprite node, but the actual tween code at lines 12-13 hardcodes `$Sprite2D` instead of using the `sprite` field. The exported variable is never read anywhere in the file — it's dead, and the hardcoding defeats its apparent purpose (if the child node were ever renamed, `$Sprite2D` would break silently while the presumably-intended `sprite` export would have kept working).

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/` as an enemy-action-intent visual popup.
**Confidence:** High.

---

## enemy_resource.gd
**Current responsibilities:**
- Pure data resource: enemy name/description, health/shields, action-option pool, and graphics configuration (ship scene, offsets, targeting image, health-bar/dice-queue positions)

**Style issues:** none found — no functions, nothing to check. (Minor, non-rule-based observation: there's a single blank line before `@export_category('Behavior')` at line 8 but a double blank line before `@export_category('Graphics')` at lines 12-13 — an inconsistency in category-grouping whitespace, but STYLE_GUIDE.md doesn't demonstrate a rule for spacing around `@export_category` groups, so this isn't cited as a violation.)

**Coupling issues:** none found.

**Split recommendation:** No — cohesive data schema.

**Bugs:** none found.

**Suggested folder:** Content — already correctly placed under `Source/Content/Enemies/EnemyResources/`.
**Confidence:** High.

---

## mouse_cursor.gd
**Current responsibilities:**
- Custom cursor sprite that follows the mouse and hides the OS cursor
- Swaps texture between default/info cursor based on `Clickable` hover-delay signals
- Dynamically connects/disconnects to whichever `Clickable` is "current" via `Events.set_current_clickable`

**Style issues:**
- Line 7: only a single blank line separates `var current_clickable: Clickable = null` (line 6) from `func _ready()` (line 8), where STYLE_GUIDE.md's demonstrated convention (lines 19-22) calls for a double blank line before a function definition. Every other function boundary in this file correctly uses the double-blank convention.

**Coupling issues:** none found — `Events.set_current_clickable`/`Globals.mouse_is_dragging_something` are the sanctioned Content→Systems direction (here Systems→Systems, equally sanctioned), and the dynamic connect/disconnect to `Clickable` is guarded with `is_connected()` checks (lines 40, 42, 44, 49, 51, 53), avoiding double-connection errors.

**Split recommendation:** No — cohesive, single-purpose cursor-feedback script.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/MouseCursor/`; generic UI/input feedback independent of specific game content.
**Confidence:** High.

---

## game_over.gd
**Current responsibilities:**
- Listens for `Events.game_over` and a `BOSS_DEFEATED` scenario event to show a game-over or victory screen
- Builds BBCode wave/color text for the end-state label
- Wires main-menu and quit buttons

**Style issues:** Lines 13-15 contain **three** consecutive blank lines between the end of `_ready()`'s body and `func _on_main_menu_button_pressed()`, where every other function boundary in this same file (lines 18-19, 21-22, 31-32) uses exactly the double-blank-line convention demonstrated in STYLE_GUIDE.md. This is the opposite kind of inconsistency from most other findings in this pass (too many blank lines rather than too few), but it's still a real deviation from the file's own otherwise-consistent pattern.

**Coupling issues:** none found — `%EndStateLabel` is Godot's scene-unique-name feature (not a fragile deep `$Path` chain), and `QuitManager`/`Globals`/`Events` usage is all sanctioned Systems access.

**Split recommendation:** No — small (40 lines), single cohesive "end-state screen" responsibility.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/GameOver/`, matching its listing as a UI System in ARCHITECTURE_OVERVIEW.md.
**Confidence:** High.

---

## button_rotator.gd
**Current responsibilities:**
- Plays a slow, looping "breathing" scale tween on itself, starting after a 6-second delay

**Style issues:**
- Line 4: only a single blank line separates `var original_scale: Vector2` from `func _ready()` (line 5), where STYLE_GUIDE.md's demonstrated convention (lines 19-22) calls for a double blank line before a function definition.

**Coupling issues:** none found.

**Split recommendation:** No — trivial, single-purpose visual effect.

**Bugs:**
- Line 10: `var angle_amount: int = 7` is declared but never used in any live code — I checked the entire function body, and its only references are inside the commented-out rotation-tween lines (17-20). This is confirmed dead code (an unused variable), not a speculative guess.
- The script is named `button_rotator.gd`, but all rotation logic is commented out (lines 17-20); the file currently only performs a scale-breathing effect, not a rotation. Either the name is now stale/misleading, or the rotation effect was intentionally disabled but left in a half-removed state — worth a decision on which one is intended (delete the dead rotation code and rename the file, or re-enable the rotation).

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/`; generic UI juice effect, not tied to specific content.
**Confidence:** High.

---

## button.gd
**Current responsibilities:**
- Custom `Button` subclass driving a `RichTextLabel` + `AnimatedSprite2D` presentation: hover wave-text effect, disabled-state styling, click-window timing (`pressed_within_window` signal fired only if the button is released within a configurable window), hover SFX

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary (lines 32-33, 43-44, 67-68, 73-74, 78-79, 84-85) and consistently followed.

**Coupling issues:**
- `_on_mouse_entered()` (lines 45-67) and `soft_highlight()` (lines 86-106) are near-duplicates: both build an identical `[wave amp=... freq=... connected=1]...[/wave]` BBCode string via an identical `if button_size == LARGE/MEDIUM/SMALL` amplitude lookup, differing only in the specific amplitude values (12/9/6 vs 9/6/4) and which color is applied (`hover_text_color` vs `soft_highlight_color`). Recommend extracting a shared private helper, e.g. `_apply_wave_text(amp: float, freq: float, color: Color)`, called by both with their own amplitude/color arguments.

**Split recommendation:** No — at 107 lines with a clear single identity ("a stylized game button"), this doesn't warrant a structural split; the duplication above is a de-duplication fix, not a split trigger.

**Bugs:**
- Worth verifying: the file's header doc comment (lines 1-3) states the attached `AnimatedSprite2D` "must include animations 'default', 'pushed', and 'disabled'," implying three named-animation states. But the actual code only ever sets `$AnimatedSprite2D.frame` directly to `0` or `1` (lines 36, 40, in `update_ui()`) for the disabled/enabled states, and nothing in `_on_button_down()`/`_on_button_up()` references a "pushed" animation or frame at all — there's no visual feedback for the pressed state beyond the click-window SFX. This may be stale documentation left over from a removed feature, or a genuinely missing pushed-state visual; I can't tell which from this file alone.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/Buttons/` as a generic reusable UI component.
**Confidence:** High for folder placement and the duplication finding; Medium for the "pushed" animation gap, since it depends on intent I can't verify from this file (and possibly the `.tscn` scene) alone.

---

## options_saving_manager.gd
**Current responsibilities:**
- Serializes current Game/Graphics/Audio/Misc settings (read live from `Globals`, `DisplayServer`, `AudioServer`, `Engine`) into a `ConfigFile` and saves it to `user://options_settings.cfg`
- Loads that config back and applies each setting to the corresponding live system
- Computes a "recommended" display scale based on screen size (`_get_recommended_scale`)

**Style issues:** none found — double-blank-line-before-function convention checked at all 9 function boundaries and consistently followed.

**Coupling issues:** `_get_recommended_scale()` (lines 196-207) duplicates the exact same scale-fitting loop found in `options_menu.gd`'s `_reduce_scale_options()` (lines 73-83) — both iterate `[4, 6, 8, 9, 10, 12]`, checking `(base_resolution * scale) <= display_size` and breaking on the first that doesn't fit. See `options_menu.gd`'s entry below for the fuller picture of duplication between these two files.

**Split recommendation:** No — despite being 208 lines and touching four different subsystems (`Globals`, `DisplayServer`, `AudioServer`, `Engine`), every function here serves one single reason to change: "persist or restore a setting." This is cohesive by purpose even though it's not cohesive by which engine API it touches.

**Bugs:** none found. The load-failure path (`if err != OK: printerr(...)`, lines 44-46) correctly falls through to `config.get_value(..., default)` calls that supply sensible defaults, so a missing settings file (first run) degrades gracefully rather than crashing.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/OptionsMenu/`.
**Confidence:** High.

---

## options_menu.gd
**Current responsibilities:**
- Tab switching between Game/Graphics/Audio option screens (`_on_game_button_pressed`, `_on_graphics_button_pressed`, `_on_audio_button_pressed`)
- Initial UI sync from live settings on open (`_setup_game_options_UI`, `_setup_graphics_options_UI`, `_setup_audio_sliders`, `_reduce_scale_options`, `_set_scale_choice_label`)
- ~11 individual UI event handlers that each directly read/write `Globals`, `DisplayServer`, `AudioServer`, or `Engine` in response to a checkbox/slider/dropdown change

**Style issues:** none found — double-blank-line-before-function convention checked across all function boundaries and consistently followed.

**Coupling issues:** This file and `options_saving_manager.gd` implement the same string-label↔value mappings **three times over**, in two separate files:
  1. Animation speed (`0.5x/1x/2x/4x` ↔ `Globals.animation_speed`): `options_menu.gd` lines 36-44 (UI sync) and lines 195-203 (`_on_animation_speed_option_button_item_selected`), plus `options_saving_manager.gd` lines 84-94 (`_get_current_game_settings`) and lines 101-109 (`_set_game_settings`).
  2. FPS limit (`30/60/120/Unlimited` ↔ `Engine.max_fps`): `options_menu.gd` lines 46-56 and 208-216, plus `options_saving_manager.gd` lines 122-132 and 156-166.
  3. Window scale (`[2,4,6,8,9,10,12]` ↔ window size): `options_menu.gd`'s `_reduce_scale_options()` (lines 73-83) and `_on_scale_option_button_item_selected()` (lines 224-243), plus `options_saving_manager.gd`'s `_get_recommended_scale()` (lines 196-207).
  
  If a new option value is ever added or reordered in one of these places, it's easy to update only some of the 5-6 copies and leave the rest silently inconsistent. Recommend extracting shared lookup tables (e.g. a small `options_maps.gd` or `const` dictionaries) that both `OptionsMenu` and `OptionsSavingManager` reference as the single source of truth.

**Split recommendation:** Yes. At 259 lines, this mixes UI input handling (checkbox/slider/dropdown callbacks), settings-application logic (writing to `DisplayServer`/`AudioServer`/`Engine`/`Globals`), and tab-orchestration in one file, with three genuinely unrelated reasons to change (someone tuning graphics options vs. audio options vs. game options). Recommend splitting into per-tab controllers — e.g. `GameOptionsTab`, `GraphicsOptionsTab`, `AudioOptionsTab` — each owning its own `_setup_*_UI()` and its own `_on_*` handlers, with `OptionsMenu` reduced to a thin coordinator that owns tab-switching (`_on_game_button_pressed` etc.) and the top-level `_ready()`/close/save wiring (calling into `%OptionsSavingManager`). This would also make the lookup-table de-duplication from the Coupling note above easier to scope per-domain.

**Bugs:**
- Line 258: `_on_text_speed_option_button_item_selected(index: int) -> void: pass # Replace with function body.` is an empty stub — this reads exactly like a Godot-editor-generated signal-callback placeholder that was never filled in. If a "Text Speed" option control exists in the scene and is wired to this callback, changing it currently does nothing.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/OptionsMenu/`.
**Confidence:** High.

---

## capsule_mockup.gd
**Current responsibilities:**
- Spawns a fixed-seed starfield background, presumably for generating consistent store-page/capsule marketing art rather than in-game use

**Style issues:** none found — double-blank-line-before-function convention followed (lines 10-11, 20-21).

**Coupling issues:** none found.

**Split recommendation:** No — trivial, single-purpose script.

**Bugs:**
- Line 14: `seed('Die Fighter 42'.hash())` calls Godot's **global** `seed()` function, which reseeds the shared process-wide random state used by every unqualified `randf()`/`randi()`/`randf_range()`/`randi_range()` call in the entire application (many other files in this codebase call these global random functions, e.g. `opening_cutscene.gd`). This is a real, unambiguous side effect: if this script's scene is ever loaded in the same process as actual gameplay (rather than run in total isolation purely to render a screenshot), it would deterministically reset randomness for everything else running at that point. I can't confirm from this file alone how/when this scene is actually invoked (a one-off marketing-art generation scene run standalone would make this harmless), so I'm flagging the mechanism as confirmed and the real-world impact as worth verifying against how this scene is used.

**Suggested folder:** This looks like a dev/marketing tool rather than a shipped UI system or gameplay content — worth considering a dedicated `Tools/` or similar location separate from `Source/Systems/UI/`, though given this is a solo-developed project and it's a single harmless file, leaving it in place is also reasonable.
**Confidence:** Low — I can't see how or when this scene is actually invoked (manual editor use vs. part of a build), which is exactly the kind of reverse-dependency information this rubric calls for discounting confidence on.

---

## camera.gd
**Current responsibilities:**
- Connects small/large camera-shake `Events` signals to the `Shakeable` child component
- On a large "glitch" shake, additionally toggles the glitch shader on for the shake's duration

**Style issues:**
- Line 2: only a single blank line separates `extends Camera2D` from `func _ready()` (line 3), where STYLE_GUIDE.md's demonstrated convention calls for a double blank line before a function definition.

**Coupling issues:** none found — `$Shakeable` is a same-subtree child reference, and `Globals`/`Events` usage is sanctioned.

**Split recommendation:** No — trivial, single-purpose script (17 lines).

**Bugs:** Worth noting (design choice, not a defect): both the camera shake *and* the glitch-shader flash are gated behind the single `Globals.screenshake_enabled` flag (line 5/9). A player who disables screenshake for comfort/accessibility reasons also loses the glitch visual feedback on critical hits, even though these are conceptually two different effects that some players might want to control independently. Not a bug, but worth a design decision either way.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/Camera/`.
**Confidence:** High.

---

## InfoResource.gd
**Current responsibilities:**
- Pure data carrier for the info-popup UI: title/top/bottom/side label text plus a texture

**Style issues:** Naming inconsistency matching the project's known pattern (see prior context, not re-derived here): the class is `InfoResource` but the file is `InfoResource.gd` (PascalCase) rather than `info_resource.gd` (snake_case), breaking the project's otherwise-consistent `ClassName` → `class_name.gd` convention seen across every other Resource subclass (`BackgroundResource` → `background_resource.gd`, `SoundEffectResource` → `sound_effect_resource.gd`, etc.). Recommend renaming to `info_resource.gd`.

**Coupling issues:** none found.

**Split recommendation:** No — trivial data resource.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/InfoShower/`; it's a UI data contract tightly coupled to that specific popup's layout (title/top/bottom/side), not generic enough for Libraries.
**Confidence:** High.

---

## info_shower.gd
**Current responsibilities:**
- Shows/hides an info popup, populating title/top/bottom/side labels via `Utils.format_text`
- Animates a "zoom from cursor to fixed position" tween using a duplicate tweening texture node, swapped for the real static one once the tween completes
- Click-to-dismiss via `_on_screen_dim_gui_input`

**Style issues:**
- Line 4: only a single blank line separates `var texture_final_pos: Vector2 = ...` from `func _ready()` (line 5), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.
- Lines 54-56: three consecutive blank lines separate the end of `_show_info()` from `func _on_screen_dim_gui_input()` (line 57), where every other boundary in this file (and the demonstrated convention) uses exactly two.

**Coupling issues:** none found — `%Unique` name references are Godot's scene-unique-name feature, not fragile path traversal.

**Split recommendation:** No — cohesive single-purpose popup controller (~61 lines).

**Bugs:**
- Worth verifying: `_show_info()` (lines 13-53) creates a new `Tween` and `await`s its completion (line 51) before hiding `%TweenableTextureDisplay` and restoring `%TextureDisplay.modulate.a = 1`. If `_show_info()` is triggered again (e.g., the player's mouse moves quickly across multiple hoverable tiles) before the previous call's 0.5s tween finishes, two `Tween`s would be animating the same `%TweenableTextureDisplay` node's `scale`/`position` concurrently, and two pending `await ... .finished` continuations would both eventually run their hide/show cleanup. I can't fully trace Godot's exact per-frame resolution behavior for two concurrent tweens on the same node/property from this file alone, so this is a risk worth testing (rapid re-hover) rather than a confirmed defect — the end state each continuation writes is identical, so a worst case is likely a brief visual jitter rather than a broken state.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/InfoShower/`, matching ARCHITECTURE_OVERVIEW.md's UI Systems table.
**Confidence:** High for style/placement; Medium for the concurrent-tween risk, which depends on Godot Tween-scheduling semantics I can't fully verify from this file.

---

## fps_counter.gd
**Current responsibilities:**
- Toggleable debug FPS display, updating its text once per frame while visible

**Style issues:** none found — double-blank-line-before-function convention followed (lines 2-3, 6-7, 11-12).

**Coupling issues:** none found.

**Split recommendation:** No — trivial debug utility.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/DebugItems/`.
**Confidence:** High.

---

## pause_menu.gd
**Current responsibilities:**
- Toggles pause state and pause-menu visibility in response to `Events.toggle_pause_menu`
- Wires main-menu, options, save-and-quit, and wishlist buttons

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found — `%OptionsMenu` is the sanctioned scene-unique-name feature; `QuitManager` is a documented autoload.

**Split recommendation:** No — small, cohesive pause-menu controller (46 lines).

**Bugs:**
- Lines 39-40: `_save_game()` — called from both `_on_main_menu_button_pressed()` (before leaving the scene) and `_on_save_and_quit_button_pressed()` — consists solely of `print('Saving game!')`. It does not actually persist any game state (the codebase already has a `GameSaveResource` schema for exactly this, per `game_save.gd`, but nothing here writes to it). This means both "return to main menu" and the literally-named "Save and Quit" button currently discard all progress rather than saving it, despite the UI/flow explicitly implying otherwise.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/PauseMenu/`, matching ARCHITECTURE_OVERVIEW.md's UI Systems table.
**Confidence:** High.

---

## glitch_controller.gd
**Current responsibilities:**
- Shows/hides a `ColorRect` glitch-shader overlay in response to `Events.set_glitch`

**Style issues:**
- Line 2: only a single blank line separates `extends ColorRect` from `func _ready()` (line 3), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found.

**Split recommendation:** No — trivial, single-purpose script.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/Glitch/`.
**Confidence:** High.

---

## error_popup_manager.gd
**Current responsibilities:**
- Listens for `Events.error_text_popup`, plays an error SFX, clears any existing error popup, and spawns a new `ErrorTextPopup` at a given position

**Style issues:**
- Line 9: only a single blank line separates `var _current_popups: Array[ErrorTextPopup]` from `func _ready()` (line 10), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found.

**Split recommendation:** No — small, cohesive manager.

**Bugs:**
- Worth verifying: `_clear_current_popups()` (lines 26-31) checks `if _current_popups[i]:` (line 28) as a truthiness guard before calling `queue_free()`, rather than `is_instance_valid(_current_popups[i])`. If a popup in this array were ever freed by some other path before this runs, a plain truthiness check on a stale `Node` reference is exactly the kind of freed-instance-safety edge case that's easy to get wrong in GDScript — I can't confirm from this file alone whether that ever actually happens (nothing else in this file frees these nodes early), so this is a defensive-coding improvement to consider rather than a demonstrated live bug.
- Note: `_create_error_popup()` calls `_clear_current_popups()` *before* appending the new popup (line 16 before line 23), meaning only one error popup is ever shown at a time by design (each new one replaces the last). The `Array` tracking is more machinery than strictly needed for a single-item case, but this isn't wrong, just worth knowing it's intentional.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/ErrorPopupManager/`.
**Confidence:** High.

---

## error_text_popup.gd
**Current responsibilities:**
- Self-contained timed popup: floats upward, fades out over its last `fade_time` seconds, then frees itself

**Style issues:** none found — double-blank-line-before-function convention followed (lines 10-11, 14-15).

**Coupling issues:** none found.

**Split recommendation:** No — trivial, self-contained effect.

**Bugs:** none found. Traced the countdown/fade math (lines 17-25): alpha only changes during the final `fade_time` seconds and linearly approaches 0, matching the intended fade-out.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/ErrorPopupManager/ErrorTextPopup/`.
**Confidence:** High.

---

## main_menu.gd
**Current responsibilities:**
- Title-screen setup on app start: fade-in, hiding the options menu, clearing/regenerating a starfield background, playing an intro `AnimationPlayer` animation, preloading the opening cutscene via threaded loading
- Click-to-skip the intro animation (`_input`)
- Play/Options/Quit/Wishlist button wiring

**Style issues:** Lines 85-87 contain three consecutive blank lines between the end of `_on_play_button_pressed()` and `func _on_options_button_pressed()` (line 88), where every other function boundary in this file uses exactly the double-blank convention demonstrated in STYLE_GUIDE.md.

**Coupling issues:**
- `_add_star()` (lines 50-62) is essentially byte-for-byte identical to `capsule_mockup.gd`'s `_add_star()` (same instantiate/z_index/position-formula/modulate-randomization body), and is a close cousin of `opening_cutscene.gd`'s inline star-spawning loop (`_set_stars()`, using a slightly different position formula). That's the star-field generation pattern duplicated across three files. Recommend extracting a shared, parameterized starfield-generator (e.g., a small component under `Source/Systems/Components/` or a reusable script in `Source/Systems/Graphics/`) that all three scenes can use.
- `_on_wishlist_button_pressed()` (lines 96-98) duplicates `pause_menu.gd`'s `_on_wishlist_button_pressed()` exactly, including the hardcoded Steam store URL string. Recommend a single shared constant or helper function so the URL only needs updating in one place if it ever changes.

**Split recommendation:** No — at 99 lines this is a cohesive "title screen controller"; the duplication noted above is a de-duplication opportunity across files, not a reason to split this file's own internal structure.

**Bugs:**
- Line 6: `@export var background_color: Color = Globals.purple` is declared but never used in any live code — I checked the whole file, and its only two references are the commented-out lines 21 (`#%FadeIn.self_modulate = background_color`) and 26 (`#self.self_modulate = background_color`). This is a confirmed dead/unused exported variable, still visible in the inspector but with no effect.
- **Confirmed significant across three files, not just theoretical:** line 32, `seed('Die Fighter'.hash())`, reseeds Godot's **global** random state (same mechanism flagged in `capsule_mockup.gd`) in `main_menu.gd`, which per ARCHITECTURE_OVERVIEW.md is the actual title screen shown at the start of every session — running before anything else. `game_state_manager.gd` has the *exact same* `seed('Die Fighter'.hash())` call, but **commented out** there, and that file's `_randomize_sector_scenarios()` draws heavily on the global RNG (`randi_range`, `randf`, `pick_random`, `randi`) with no local RNG of its own to generate the run's entire sector layout, boss, scenario mix, and each scenario's own `scenario_seed`. `enemy_manager.gd` then feeds that same `scenario_seed` into `Enemy.seed()`, so enemy behavior RNG is affected too. This is strong evidence the developer already identified and fixed this exact problem in `game_state_manager.gd` but missed applying the same fix here — meaning every playthrough currently generates an identical sector layout and enemy RNG stream on every launch. See `game_state_manager.gd`'s and `enemy_manager.gd`'s entries for the full chain of evidence. Recommend removing this line to match.
- Minor cleanup: lines 21, 26, and 76 are commented-out dead code (`#%FadeIn.self_modulate = ...`, `#self.self_modulate = ...`, `#get_tree().change_scene_to_file(main_game_file)`) worth removing.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/MainMenu/`, matching ARCHITECTURE_OVERVIEW.md's listing of `MainMenu` as the root title-screen UI system.
**Confidence:** High for the dead-code/duplication findings; Medium for the global-seed concern, which depends on `EnemyManager`'s seeding logic that I haven't yet analyzed.

---

## background_modifier_label.gd
**Current responsibilities:**
- None — the file is just `class_name BackgroundModifierLabel` / `extends Node2D` with no body at all.

**Style issues:** none found (nothing to check).

**Coupling issues:** none found (nothing to check).

**Split recommendation:** No — there's nothing here to split.

**Bugs:** This class and its companion scene (`background_modifier_label.tscn`) are unreferenced anywhere else in the project — I checked both by class name (`grep -rn "BackgroundModifierLabel"`) and by the scene's Godot UID (`qy7xyquee3nh`), and neither turns up in any other `.gd` or `.tscn` file. This looks like scaffolding for a planned-but-never-implemented feature rather than a live bug. Worth a decision: either flesh it out or delete both files.

**Suggested folder:** N/A pending a decision on whether to implement or delete.
**Confidence:** High that it's unreferenced (direct grep + UID evidence); can't rule out being loaded dynamically by a path I wouldn't catch via grep, though nothing else in this codebase's patterns suggests that.

---

## dev_console.gd
**Current responsibilities:**
- Console UI mechanics: history navigation (up/down arrows), open/close toggling (keybind action and typing a backtick), command-string parsing and submission
- A large dispatch `match` statement routing ~25 text commands to individual handler functions, already informally grouped by the author into `# ── Tile / Grid ──`, `# ── Player ──`, `# ── Enemies ──`, `# ── Misc ──` sections (lines 174, 343, 457, 491)
- ~25 individual cheat/debug command implementations (tile/grid manipulation including file-based save/load, player stat cheats, enemy cheats, misc utilities like FPS toggle and test sounds)
- Resource-directory scanning to look up `TileResource` assets by name for the `give_tile` command

**Style issues:**
- Line 248: only a single blank line separates the end of `_give_tile()` from `func _get_available_tile_names()`, where STYLE_GUIDE.md's convention calls for a double blank line.
- Line 266: same issue between the end of `_get_available_tile_names()` and `func _load_tile_by_name()`.
- (I spot-checked a broad sample of the file's ~35 function boundaries beyond these two; the rest I checked were consistently double-blank.)

**Coupling issues:**
- `_get_available_tile_names()` (lines 249-265) and `_load_tile_by_name()` (lines 267-282) duplicate the exact same nested-directory-scan structure (same two hardcoded directories, same `.ends_with(".tres")` filter, same `ResourceLoader.load` call), differing only in what they do with each found `TileResource` (collect unique names vs. return the first name match). Recommend extracting a shared `_scan_tile_resources() -> Array[TileResource]` helper both build on.
- Broad, direct reach into `Globals.scenario_manager`, `Globals.tile_grid`, `Globals.player`, `Globals.enemy_manager` internals throughout — this is extensive but all through the sanctioned `Globals` registry, and broad state access is inherent to what a debug console needs to do, so not flagged as a violation.

**Split recommendation:** Yes. At 542 lines, this is well past the split threshold, and — unlike some other long-but-cohesive files in this pass — it has genuinely separate, author-acknowledged reasons to change: someone adding a new tile/grid debug command has no reason to touch enemy-cheat code, and vice versa (evidenced by the file's own section-comment groupings). Recommend extracting the command *implementations* into per-domain scripts (e.g. `DevConsoleTileCommands`, `DevConsolePlayerCommands`, `DevConsoleEnemyCommands`, `DevConsoleMiscCommands`), keeping the UI mechanics (history, toggling, parsing/dispatch) in `dev_console.gd` itself, which would delegate to whichever domain handler owns a given command name.

**Bugs:**
- Lines 168-171: `_on_line_edit_text_changed()` calls `current_text.replace('`', '')` and discards the result. GDScript `String.replace()` returns a new string rather than mutating in place — since the return value here isn't assigned back to `line_edit.text` (or anything else), this line has **no effect**: the backtick character used to toggle the console remains visibly typed into the input field every time the console is opened this way. This is a confirmed bug (`String.replace()`'s non-mutating semantics are basic, well-documented GDScript behavior, not an edge case). It also means this toggle path behaves inconsistently with `_toggle_dev_console()` (lines 52-57), which explicitly clears `line_edit.text` and grabs focus when opening via the keybind — the backtick path does neither.
- Lines 14-18 (`_test()`, wired to the `test` console command): declares `var tile: Tile = Globals.tile_grid.tile_locations[Vector2i(0,0)]` and never uses `tile` afterward (checked the full function body) — a genuinely unused variable. This line would also throw a runtime error if there's no tile at grid position (0,0), since indexing a `Dictionary` with `[]` for a missing key raises an error rather than returning null. This reads as leftover developer scratch code behind the `test` command rather than a player-facing issue, but it's live, reachable code as written.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/DevConsole/`.
**Confidence:** High for all findings above (each traced through concrete code paths).

---

## dice_area_highlight.gd
**Current responsibilities:**
- Shows/hides a drop-zone highlight sprite in response to drag/drop-related `Events` signals, with an explicit redundant hide-on-turn-over as a safety net

**Style issues:**
- Line 2: only a single blank line separates `extends Sprite2D` from `func _ready()` (line 3), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found — `Globals.player`/`Events` usage is sanctioned.

**Split recommendation:** No — trivial, single-purpose visual feedback script.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/UI/`.
**Confidence:** High.

---

## utils.gd
**Current responsibilities:**
- Generic signal/array helpers: `disconnect_all_callables()`, `array_while_excluding()`
- Dice-position sorting: `sort_dice_by_position()`
- A block of ~13 hardcoded content-specific texture-path constants (`dice_image_paths`, `fate_image_path`, etc.)
- `format_text()`: BBCode color-name substitution plus `(die_N)`/icon-name substitution into `[img]` tags, built directly on the path constants above
- A self-contained typewriter/delay-tag subsystem: `parse_delay_tags()`, `map_delay_positions()`, `_find_corresponding_position()`, `remove_delay_tags()` — roughly 110 lines of non-trivial character-alignment logic for mapping `(delay=N)` tag positions between raw, delay-stripped, and fully-processed/BBCode-stripped versions of the same text
- `strip_bbcode_tags()`: regex-based BBCode/image/resource-path stripping
- `slice_texture_right()`: generic image-cropping utility

**Style issues:**
- Line 3: only a single blank line separates `extends RefCounted` from the `## Disconnects all the callables...` doc comment / `func disconnect_all_callables()` (line 5), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none in the autoload/path-traversal sense, but see Split recommendation — this file itself is the coupling problem: it bundles game-agnostic utilities with game-content-specific asset paths and a complex, unrelated parsing subsystem under one grab-bag `Utils` class name.

**Split recommendation:** Yes. At 264 lines, this mixes at least four unrelated concerns with entirely separate reasons to change: (1) generic, game-agnostic helpers (`disconnect_all_callables`, `array_while_excluding`, `slice_texture_right`) that could be copy-pasted into any Godot project, (2) a block of hardcoded game-asset paths plus the BBCode-formatting logic built on them, (3) a genuinely complex, self-contained delay-tag character-alignment subsystem that has nothing to do with any other member of this class, and (4) a dice-specific sort helper. Recommend:
  - Extract `parse_delay_tags`, `map_delay_positions`, `_find_corresponding_position`, `remove_delay_tags` into their own class (e.g. `TypewriterDelayTagParser`) — this subsystem shares no state with the rest of `Utils` and is complex enough to deserve isolated ownership and testing.
  - Extract `format_text`, `strip_bbcode_tags`, and the `static var *_image_paths` constants into a dedicated text-formatting class (e.g. `RichTextFormatter`) — these belong together (the constants only exist to serve `format_text`) and are conceptually distinct from generic utilities.
  - Leave `disconnect_all_callables`, `array_while_excluding`, and `slice_texture_right` as the genuinely generic residents of a `Utils`/Libraries-tier class.
  - `sort_dice_by_position` is algorithmically generic but conceptually dice-specific; a milder call, could stay or move alongside `Dice`/`DiceQueue`.

**Bugs:**
- Worth verifying: `_find_corresponding_position()` (lines 184-219) is a heuristic character-by-character alignment algorithm with a lookahead-based mismatch-recovery fallback (lines 199-208). I traced through its logic but couldn't construct full certainty without seeing actual call-site strings — a plausible failure mode is when `format_text()` replaces a `(die_N)`-style token with an `[img]...[/img]` tag that `strip_bbcode_tags()` later removes *entirely* (content included), leaving zero corresponding characters in `target_text` for that span; the `if not found: source_index += 1` fallback (line 208) would then advance through the source without ever advancing `target_index`, potentially misplacing any delay marker positioned within or after such a span. This is a complex heuristic I'd want to verify with concrete test strings rather than assert as a confirmed defect from static reading alone.

**Suggested folder:** Mixed — see Split recommendation. The generic helpers belong in Libraries (game-agnostic); the text-formatting and delay-tag pieces are Systems-tier (UI-adjacent, but not tied to specific game content beyond the hardcoded asset paths).
**Confidence:** High for the split rationale and style issue; Medium for the delay-tag alignment concern, which I flagged as worth testing rather than confirmed.

---

## quit_manager.gd
**Current responsibilities:**
- Intercepts the OS window-close request and routes it through the same `request_quit()` path as in-game quit buttons
- Guards against duplicate cleanup with `_is_quitting`
- Runs cleanup (increment `Globals.times_run`, save options) before actually quitting

**Style issues:**
- Line 4: only a single blank line separates `var _is_quitting: bool = false` from `func _ready():` (line 5), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found — `Globals`/`Events` usage is the expected Systems-to-Systems autoload dependency.

**Split recommendation:** No — small, cohesive.

**Bugs:** none found. The `_is_quitting` guard correctly prevents `_cleanup_before_quit()` from running twice if both the window-close notification and a manual `request_quit()` call somehow race.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching its Autoloads-table entry in ARCHITECTURE_OVERVIEW.md.
**Confidence:** High.

---

## sound_effects_player.gd
**Current responsibilities:**
- Listens for `Events.play_sound`, spawns a one-shot `AudioStreamPlayer` child, applies volume/pitch/pitch-escalation/pitch-randomness from the `SoundEffectResource`, and frees itself when playback finishes

**Style issues:** none found — double-blank-line-before-function convention followed (lines 3-4, 8-9).

**Coupling issues:** none found.

**Split recommendation:** No — small, cohesive.

**Bugs:** none found here, but this file confirms the mechanism behind the "worth verifying" concern raised in `sound_effect_resource.gd`'s entry: `on_audio_finished()` is only ever called via `player.finished.connect(sfx.on_audio_finished)` (line 30), so if a spawned `player` were ever removed from the tree without its `finished` signal firing, that SFX's play-count would leak. Additional context that lowers the practical risk: `SFXPlayer` is itself an autoload (per ARCHITECTURE_OVERVIEW.md), so its spawned `player` children are not part of whatever scene gets swapped by `change_scene_to_*` — they aren't implicitly freed by ordinary scene transitions, which was the most obvious way this could have gone wrong. Restating rather than retracting the earlier note: still worth a mental note, but lower-probability than I'd initially guess.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching ARCHITECTURE_OVERVIEW.md's `SFXPlayer` autoload entry.
**Confidence:** High.

---

## effect_registry.gd
**Current responsibilities:**
- Pure registration table mapping `(category, subtype)` pairs to shared `EffectHandler` instances, organized into clearly-labeled section comments matching ARCHITECTURE_OVERVIEW.md's documented Effect Categories
- `get_handler()` lookup with an error-logging miss path

**Style issues:**
- The file's `##` doc comment block (lines 1-14) appears *before* `extends Node` (line 16), whereas STYLE_GUIDE.md's demonstrated ordering is `class_name` → `extends` → `##` doc comment (lines 4-9 of the guide). This file has no `class_name` (expected, since it's accessed by its autoload singleton name rather than a type), but the doc-comment-before-`extends` ordering is still a deviation from the one ordering STYLE_GUIDE.md actually shows.

**Coupling issues:** none found — this is the Systems-tier registry resolving Behavior-tier handler classes, exactly the role ARCHITECTURE_OVERVIEW.md 6.1 describes for it.

**Split recommendation:** No — despite 131 lines and ~80 registration calls, this is a pure, single-reason-to-change lookup table (the same reasoning applied to `activation_resource.gd` earlier in this pass): adding a new effect handler always touches this file in the same way.

**Bugs:** none found. Two very minor, non-functional observations: (1) `get_handler()`'s error message (lines 31-37) pretty-prints the category name via `EffectEnums.Category.find_key(category)` but falls back to a raw integer (`str(subtype)`) for the subtype, making failed lookups slightly harder to debug than they could be. (2) The four `CONDITIONAL` subtypes (lines 120-123) each get their own separate `ConditionalHandler.new()` instance rather than sharing one, which mildly contradicts this file's own doc comment ("a single shared instance per handler type is safe and efficient," lines 3-4) — harmless since handlers are stateless, but worth noting as a small inconsistency with its own stated design principle.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching ARCHITECTURE_OVERVIEW.md's `EffectRegistry` autoload entry.
**Confidence:** High.

---

## debug_logger.gd
**Current responsibilities:**
- Opens and clears a log file at startup, subscribes to ~11 different `Events` signals (scenario, combat, turn, game-over events), and writes each as a timestamped line
- Closes the file on `_exit_tree()`

**Style issues:** This file's blank-line spacing is a systematic, file-wide deviation: every single function boundary I checked (13 of them, including lines 4-5 before `_ready`, 32-33 before `_log`, and every `_on_*` handler boundary such as 45-46, 48-49, 51-52, 54-55, 57-58, 60-61, 62-63, 66-67, 69-70, 72-73, 75-76) uses exactly one blank line, where STYLE_GUIDE.md's demonstrated convention calls for two. Unlike other files in this pass where this was an isolated inconsistency, here it's the file's consistent (if consistently wrong) formatting style throughout — worth a single pass to add the missing blank lines rather than a line-by-line list.

**Coupling issues:** none found — subscribing broadly to the `Events` bus is exactly what a centralized logger is documented to do (ARCHITECTURE_OVERVIEW.md's Autoloads table: "Centralized logging and debug output"), not a violation of the sanctioned-dependency direction.

**Split recommendation:** No — every function serves the identical single purpose (log this event as a line of text); broad signal coverage isn't the same as mixed responsibilities.

**Bugs:**
- Line 4: `_log_path: String = "res://debug_log.txt"` — writing to a `res://` path at runtime only works in the editor, where `res://` maps to the actual project folder on disk. In an exported/shipped build, `res://` is packed into a read-only PCK archive, so `FileAccess.open(_log_path, FileAccess.WRITE)` (line 11) would fail and return null, silently disabling all logging via the existing `if _log_file == null: ... return` guard (lines 12-14, 34-35). This is well-established Godot behavior, not a runtime edge case I'm guessing at. Whether this is intentional (a dev-only tool that's meant to no-op when shipped) or an oversight (logging was meant to work in exported debug builds too, which would require `user://` instead) is a design question I can't resolve from the code alone.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching ARCHITECTURE_OVERVIEW.md's `DebugLogger` autoload entry.
**Confidence:** High for the style and `res://` findings; the intent behind the `res://` choice is Medium since it could plausibly be deliberate.

---

## input_manager.gd
**Current responsibilities:**
- Global screenshot input action (always active)
- Pause-menu toggle and end-turn shortcut, gated on the game not being over

**Style issues:**
- Line 2: only a single blank line separates `extends Node` from `func _ready()` (line 3), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found — `Globals`/`Events` usage is sanctioned.

**Split recommendation:** No — small, single-purpose input dispatcher.

**Bugs:** none found. The `EndTurn` action requiring an empty dice queue (line 21) could look redundant if `Player.end_turn()` already checks this itself, but I haven't yet analyzed `player.gd` to confirm either way — not asserting anything wrong here.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching ARCHITECTURE_OVERVIEW.md's `InputManager` autoload entry.
**Confidence:** High.

---

## screenshotter.gd
**Current responsibilities:**
- On startup, scans `user://screenshots` for existing numbered screenshots to resume numbering (or creates the directory on first run)
- Saves a numbered PNG screenshot in response to `Events.take_screenshot`

**Style issues:**
- Line 4: only a single blank line separates `var ssCount: int = 1` from `func _ready()` (line 5), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.
- `ssCount` (line 3, and used throughout) is camelCase, where STYLE_GUIDE.md's example uses snake_case consistently for every variable and function name shown. Recommend renaming to `ss_count`.

**Coupling issues:** none found.

**Split recommendation:** No — small, single-purpose.

**Bugs:** none found. I specifically traced the `file_name.substr(2, file_name.length() - 6)` filename-parsing math (line 19) against concrete examples (`"ss12.png"` → `"12"`, `"ss5.png"` → `"5"`, `"ss123.png"` → `"123"`) to confirm the `-6` offset (2 for `"ss"` + 4 for `".png"`) is correct rather than assuming it from the magic number alone. I also considered whether concurrent `Events.take_screenshot` emissions could race on the shared `ssCount` field across the `await RenderingServer.frame_post_draw` suspension point (line 31) — since GDScript coroutines resume and run to their next `await` point without interruption, and `screenshot()` has no `await` between reading `ssCount` (line 35) and incrementing it (line 37), each resumed call fully completes its save-and-increment before another queued resume can run, so this isn't actually a race.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching ARCHITECTURE_OVERVIEW.md's `Screenshotter` autoload entry.
**Confidence:** High.

---

## events.gd
**Current responsibilities:**
- Pure signal-bus declarations: 35+ signals organized into commented sections (Loading, Startup, Game State, Combat/Turn, Player, Enemy, Dice, Tile & Grid, Reward/Economy, UI, Info/Tutorial, Interaction, Visual/Effects, Audio, Configuration)

**Style issues:** Line 38: only a single blank line separates the end of the "Player Events" section (`signal player_fatal_damage()`) from the `# Enemy Events` comment (line 39), where every other section transition in this file (I checked all of them) uses a double blank line. Signals aren't functions, so this isn't strictly the STYLE_GUIDE.md func-spacing rule, but it breaks this file's own otherwise 100%-consistent internal pattern.

**Coupling issues:** none — an event bus doesn't couple to specific implementations by design; that's its entire purpose. `scenario_event`'s and similar signals' typed parameters referencing `ScenarioManager`/`Enemy` are normal Systems-to-Systems/Content type references for event payloads.

**Split recommendation:** No — despite 35+ signals, this is the single documented purpose of this autoload (ARCHITECTURE_OVERVIEW.md's "central event bus"). Splitting a signal bus into multiple files would work against the architecture's explicit design of having one central bus.

**Bugs:** none found — pure declarations, nothing executable to break.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching ARCHITECTURE_OVERVIEW.md's `Events` autoload entry.
**Confidence:** High.

---

## globals.gd
**Current responsibilities:**
- Central registry of references to other system singletons (`Player`, `TileGrid`, `Map`, `EnemyManager`, etc.), presumably populated by each system's own `_ready()` elsewhere
- Shared color palette constants
- A few global settings/flags (`screenshake_enabled`, `animation_speed`, `times_run`, `mouse_is_dragging_something`)

**Style issues:** none found per demonstrated STYLE_GUIDE.md rules — this file has no functions, so the blank-line-before-function convention doesn't apply; the variable-grouping whitespace isn't something STYLE_GUIDE.md's example demonstrates a rule for.

**Coupling issues:** none — this file is the registry other systems point at; it doesn't reach out to anything itself.

**Split recommendation:** No — a registry legitimately holding many unrelated system references together is its entire documented purpose (ARCHITECTURE_OVERVIEW.md: "Central registry for all system singletons and global constants"). Splitting it into multiple mini-registries would undermine that single-source-of-truth role.

**Bugs:** none found — pure declarations, no logic to verify (the actual assignment of e.g. `Globals.player = self` happens in each system's own script, not visible from this file).

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Autoloads/`, matching ARCHITECTURE_OVERVIEW.md's `Globals` autoload entry.
**Confidence:** High.

---

## dice_receptacle.gd
**Current responsibilities:**
- A single-die "engine" slot: only accepts a die when the player's engine is fully charged, caps its queue at one die, positions/shows-hides the held die

**Style issues:**
- Line 6: only a single blank line separates `@export var dice_queue: DiceQueue` from `func _ready()` (line 7), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found — `Globals.player.engine_charge` is sanctioned.

**Split recommendation:** No — small, cohesive; the "for now this is silly" comment (line 17) already flags the 1-die cap as a known, deliberate simplification rather than an oversight.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/MainViewer/DiceReceptacle/`.
**Confidence:** High.

---

## engine_charger.gd (`Source/Systems/Game/MainViewer/`) — the live version
**Current responsibilities:**
- Engine-charge progress bar UI: listens to charge-changed/combat-start/combat-end/scenario-load events, tweens the progress bar value and fill-head position, toggles the "charged" indicator, and updates the numeric label

**Style issues:** Lines 39-41 contain three consecutive blank lines between the end of `_check_for_combat_scenario()` and `func _update_ui()` (line 42), where every other boundary in this file uses exactly the double-blank convention from STYLE_GUIDE.md.

**Coupling issues:** none found beyond what's noted below regarding a duplicate file.

**Split recommendation:** No — cohesive single-purpose UI component (81 lines).

**Bugs:** none found in this file's own logic; it correctly guards `_update_ui()` with `if not Globals.player: return` (lines 43-44) before dereferencing player state.

**Important — duplicate file:** There is a **second, near-identical file** at `Source/Systems/Game/EngineCharger/engine_charger.gd` with the same exported properties and nearly the same body. I confirmed via `grep` on both `.tscn` files' `ext_resource` UIDs that **this file (`MainViewer/engine_charger.gd`) is the one actually in use** — both `main_viewer.tscn` and the seemingly-related `Source/Systems/Game/EngineCharger/engine_charger.tscn` reference this exact script by UID (`dplooim5t4fni`), not the sibling `.gd` file sitting in the `EngineCharger/` folder next to that `.tscn`. See the `EngineCharger/engine_charger.gd` entry below for the full picture — recommend deleting that dead duplicate and relocating *this* live file into `Source/Systems/Game/EngineCharger/` (alongside `engine_particles_controller.gd`, which already lives there and is also live) so the folder name matches its actual contents. This would also require updating `main_viewer.tscn`'s `ext_resource` path.

**Suggested folder:** Systems — recommend moving to `Source/Systems/Game/EngineCharger/` per the note above, consolidating with its already-live sibling `engine_particles_controller.gd`.
**Confidence:** High — verified via direct `.tscn` UID cross-reference, not inference.

---

## engine_charger.gd (`Source/Systems/Game/EngineCharger/`) — dead duplicate
**Current responsibilities (as written):** Same nominal purpose as the file above (engine-charge progress bar UI), but this specific file is not attached to anything.

**Style issues:** Not evaluated in detail — the file is dead code (see Bugs), so style fixes here aren't worth applying.

**Coupling issues:** none found.

**Split recommendation:** N/A.

**Bugs:** This file is unreferenced dead code. I confirmed via `grep` that no `.tscn` `ext_resource` entry points at `res://Source/Systems/Game/EngineCharger/engine_charger.gd` — both `main_viewer.tscn` and even the `.tscn` file sitting right next to *this* `.gd` file (`EngineCharger/engine_charger.tscn`) instead reference `MainViewer/engine_charger.gd`'s UID. `EngineCharger/engine_charger.tscn` is itself also unreferenced by any other scene. This looks like a leftover from an incomplete folder reorganization (the "real" implementation moved to `MainViewer/`, either forgetting to delete this old copy, or this was the original that got superseded). Notably, this dead copy is also missing two things the live version has: a `if not Globals.player: return` null-guard in `_update_ui()`, and explicit `_update_ui()` calls after the `start_combat`/`combat_finished` handlers set `engine_charge` (lines 13-18) — meaning if this file were ever mistakenly re-wired back in, it would both crash-risk on early calls and lag one frame behind on UI refresh after combat transitions.

**Suggested folder:** Recommend deleting this file (and the orphaned `EngineCharger/engine_charger.tscn` next to it) entirely, after moving the live `MainViewer/engine_charger.gd` into this folder per that entry's note.
**Confidence:** High — based on direct `.tscn`/UID cross-referencing, not inference.

---

## engine_particles_controller.gd
**Current responsibilities:**
- Ties a `GPUParticles2D`'s `amount_ratio` to the player's engine-charge percentage

**Style issues:**
- Line 2: only a single blank line separates `extends GPUParticles2D` from `func _ready()` (line 3), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** `engine_charge / float(max_engine_charge)` (line 9) is the same "charge proportion" computation duplicated in `engine_charger.gd` (both the live and dead-duplicate copies). That's now three independent copies of this one-line formula. Recommend exposing it as a computed property or method on `Player` (e.g. `Player.engine_charge_proportion() -> float`) so it only needs to be correct in one place.

**Split recommendation:** No — trivial, single-purpose script.

**Bugs:** none confirmed. Worth noting alongside the coupling issue above: if `max_engine_charge` were ever `0` for any player configuration, this division would produce `inf`/`nan` rather than crashing (GDScript float division by zero doesn't raise an error) — I haven't yet analyzed `player.gd` to know whether `max_engine_charge` can actually be `0` for any valid `num_of_dice`, so this isn't asserted as a live bug, just something to check once that file is analyzed.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/EngineCharger/`, which is where this whole cluster of engine-charge scripts should live.
**Confidence:** High.

---

## main_viewer.gd
**Current responsibilities:**
- Tab-switching between the Systems and Map views: background frame swap, tab-label color/wave-text styling, `tile_grid`/`map` visibility toggling
- Hover-feedback styling for each tab button
- Startup reveal-shader tweens for both views
- Map-tab "engine fully charged" highlight styling

**Style issues:** Lines 64-66 contain three consecutive blank lines between the end of `_systems_hovered()` and `func _show_map()` (line 67), where every other boundary in this file uses the double-blank convention from STYLE_GUIDE.md.

**Coupling issues:** `_show_systems()`/`_show_map()` (lines 43-52, 67-77) and `_systems_hovered()`/`_map_hovered()` (lines 56-64, 80-88) are each pairs of near-identical, mirrored logic differing only in which tab/color/frame is targeted — the same "duplicated tab-pair" pattern seen elsewhere in this pass (e.g. `button.gd`'s hover/highlight duplication). The two reveal-tween functions (`_systems_reveal_tween`/`_map_reveal_tween`, lines 106-135) are a third such pair. Recommend generalizing into a shared parameterized helper (or a small per-tab-button component) rather than three separate copy-pasted pairs.

**Split recommendation:** Maybe — the de-duplication above might shrink this file enough on its own that a structural split into separate files isn't needed; if the duplication is left as-is, the file's three duplicated pairs are a reasonable case for extracting a `TabButton`-style component that both the Systems and Map tabs instantiate.

**Bugs:**
- Traced a concrete state-transition bug: `_check_for_engine_charge()` (lines 90-94) sets the map tab to a special purple wave-highlight ("MAP" with `Globals.medium_purple` + wave BBCode) once `Globals.player.engine_charge >= max_engine_charge`. But `_map_hovered(false)` (the `else` branch, lines 85-87) unconditionally resets the map label to plain white "MAP" text whenever the mouse isn't hovering it and it's not the current screen — with no check for whether the engine is still fully charged. Concretely: engine reaches full charge → map tab shows the purple wave highlight → player hovers the map tab (fine, still highlighted) → player moves the mouse away → `_map_hovered(false)` fires and wipes the highlight back to plain white, even though the engine remains fully charged. The highlight only reappears the next time `Events.engine_charge_changed` fires, which won't happen again while charge stays pegged at max (e.g., across an entire out-of-combat exploration period). This is a real, traceable UX regression, not speculative.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/MainViewer/`, matching ARCHITECTURE_OVERVIEW.md's `MainViewer` entry.
**Confidence:** High — the hover/highlight bug was traced through concrete state transitions, not inferred.

---

## scenario_manager.gd
**Current responsibilities:**
- Owns the `ScenarioEngine` lifecycle: instantiates it on `load_scenario`, wires it to every `Tile` and `EnemyManager` on `start_scenario`, tears it down on `jump`
- Translates low-level `player_attacked_ship`/`enemy_left` events into higher-level `ScenarioEvent` signals (attacked-pirate/civilian, faction-defeated variants) and faction-wipeout reward spawning

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found — `get_tree().get_nodes_in_group('Tile')` (line 52) is Godot's group system, a sanctioned decoupled lookup pattern rather than a fragile path traversal; all `Globals`/`Events` usage is the sanctioned direction.

**Split recommendation:** No — cohesive single-responsibility scenario/faction-event orchestrator (106 lines), matching its documented role in ARCHITECTURE_OVERVIEW.md ("Per-scenario event dispatch; faction tracking").

**Bugs:** none found. `_handle_enemy_leaving()`'s defensive `if ship in other_faction_ships: other_faction_ships.erase(ship)` (lines 84-86) correctly handles the ambiguity of whether `enemy_left` fires before or after `EnemyManager` removes the ship from its own tracked list.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/ScenarioManager/`.
**Confidence:** High.

---

## game_state_manager.gd
**Current responsibilities:**
- Owns the `IN_COMBAT`/`OUT_OF_COMBAT`/`GAME_OVER` state machine, emitting `start_combat`/`combat_finished` only on actual transitions (via a custom setter)
- App-startup sequencing: loads the game save, connects game-flow events, kicks off the first scenario load
- Combat-state detection (`_check_combat_state`/`_in_combat`, checking for any alive `AGGRESSIVE` enemy)
- Procedural sector-layout generation (`_randomize_sector_scenarios`, ~55 lines): builds the roguelike run's scenario sequence (shops, combat/question mix, boss, leading "corrupted" scenario, starting-scenario placement) and seeds each scenario's RNG
- Main-menu navigation helpers

**Style issues:** none found — double-blank-line-before-function convention checked and followed throughout.

**Coupling issues:** none found — `Globals`/`Events`/`Utils` usage is sanctioned.

**Split recommendation:** Maybe. At 170 lines this mixes the state-machine/startup-orchestration responsibility with a substantial, self-contained procedural-generation algorithm (`_randomize_sector_scenarios`) that doesn't actually need to know about combat state at all — it only needs the game save and the scenario-resource pools. Recommend extracting it into a dedicated `SectorGenerator` class/resource; this would leave `GameStateManager` focused purely on state-machine and startup duties, and would make the generation algorithm easier to balance-tune and test in isolation.

**Bugs:**
- **Confirmed significant, not just theoretical (see also `enemy_manager.gd`, which closes the loop):** Line 49 has a *commented-out* `#seed('Die Fighter'.hash())` — the exact same global-RNG-reseeding call flagged as live/active in `main_menu.gd`'s `_ready()` (and in `capsule_mockup.gd`). This is strong corroborating evidence that the earlier flag on `main_menu.gd` is a real, live bug: it strongly suggests a developer previously had this reseed active here too and deliberately disabled it — likely *because* it broke randomization — but the same fix was never applied to `main_menu.gd`. And this file confirms exactly why it would matter: `_randomize_sector_scenarios()` draws extensively from the **global** RNG functions (`randi_range` lines 90, 134; `randf` line 106; `pick_random` lines 107, 111, 120, 127, 130; `randi` line 144 for each scenario's own seed) with no local `RandomNumberGenerator` instance of its own. `enemy_manager.gd` then seeds `Enemy.rng` directly from that same `scenario.scenario_seed` value (`Enemy.seed(scenario.scenario_seed)`), so this affects enemy behavior too, not just layout. Since `main_menu.gd` (the title screen, which runs before this) still actively calls `seed('Die Fighter'.hash())`, every single playthrough starting from the main menu would generate the **same** sector layout, boss choice, scenario mix, and enemy RNG stream — a significant, player-visible loss of the game's replay variety. Recommend removing `main_menu.gd`'s live reseed call to match the fix already applied here.
- Worth verifying: line 45's `assert(current_game_save)` is a debug-only check — Godot strips `assert()` calls entirely in exported/release builds. If `current_game_save` were ever unexpectedly null in a shipped build, this line would silently do nothing instead of failing clearly, and the game would instead crash later at `len(current_game_save.sector_scenarios)` (line 51) with a less diagnosable null-dereference. This is standard, well-documented Godot behavior; whether `current_game_save` can actually be null in practice is a separate question I can't resolve from this file alone.
- Note (flagged by the code's own author): line 6's `## Minimum of 3 (?)` comment on `sector_size` signals the author themselves isn't fully confident about a lower bound for this value — not a bug, but worth resolving that uncertainty since `_randomize_sector_scenarios()`'s loop math (line 94) doesn't defend against a very small `sector_size`.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/GameStateManager/`.
**Confidence:** High for the global-seed finding (directly corroborated by comparing this file's commented-out line against `main_menu.gd`'s live one) and the `assert()`-stripping fact; Medium on whether `current_game_save` can practically be null in shipped builds.

---

## scenario_engine.gd
**Current responsibilities:**
- The core combat event-processing engine described in ARCHITECTURE_OVERVIEW.md §4.1: FIFO `event_queue` processing through a before-hook → resolve → after-hook pipeline, plus `inject_event()` for mid-chain follow-ups
- Modifier registration/lifecycle (`add_modifier`, `remove_modifier`, `sort_modifiers`, `clear_temporary_modifiers`, `clear_modifiers`)

**Style issues:** none found — double-blank-line-before-function convention checked across every boundary and consistently followed.

**Coupling issues:** none found — this is a clean, fully decoupled core engine with zero autoload dependencies, exactly what's expected of a foundational Systems-tier class.

**Split recommendation:** No — despite being the most central class in the combat system, every method here directly serves one job: managing the event queue and modifier pipeline. A textbook cohesive file that shouldn't be split just because it's important.

**Bugs:** none confirmed, but one discrepancy worth flagging between the code and ARCHITECTURE_OVERVIEW.md's own documentation of this exact pipeline: the doc (§4.1) describes 4 steps — before-hooks, conditional resolution ("if not canceled"), after-hooks, then emit `event_resolved` — implying only step 2 (resolution) is skipped on cancellation. The actual code's `if event.canceled: continue` (in `process_event_queue()`) jumps back to the top of the loop, skipping **both** the after-hooks loop **and** the `event_resolved.emit(event)` signal for canceled events, not just the resolution step. I can't tell from the code alone whether the documentation is just imprecise (and skipping everything on cancel is the intended, correct design) or whether modifiers/listeners are meant to still run/fire on a canceled event and currently don't — worth a decision on which one is correct and updating whichever is wrong (code or doc).

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/ScenarioEngine/`, matching ARCHITECTURE_OVERVIEW.md §4.1.
**Confidence:** High that the code and documentation disagree (directly compared both); Medium on which one reflects the intended design.

---

## scenario_engine_test.gd
**Current responsibilities:**
- A manual smoke-test harness (not an automated test) exercising the `EffectChainV2`/`ConditionalEffectData`/`EffectContext` pipeline with a hardcoded odd/even-die-value example, meant to be run directly in the editor and checked by reading console output

**Style issues:**
- Lines 6-8 (and continuing through the rest of the function) mix indentation styles: line 6 is indented with a tab, while lines 7 onward use three literal spaces for what should be the same indentation level (the direct body of `_ready()`). This is a real, visible inconsistency against every other file in this codebase, which uses tabs uniformly (matching STYLE_GUIDE.md's example). `validate_scripts` confirms this doesn't cause a parse error, so it's a style/readability issue, not a compile-time defect.
- Line 4: only a single blank line separates `@onready var engine: ScenarioEngine = $ScenarioEngine` from `func _ready()` (line 5), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found — this is intentionally a self-contained test harness with no autoload dependencies.

**Split recommendation:** No — trivial, single-purpose manual test script.

**Bugs:** none found. I confirmed via `grep` that `scenario_engine_test.tscn` (this script's companion scene) isn't referenced by any other scene or script in the project — it's a standalone dev scene meant to be opened and run directly, not dead/orphaned code.

**Suggested folder:** Systems — reasonably placed alongside the engine it tests (`Source/Systems/Game/ScenarioEngine/`); a dedicated `tests/` subfolder convention would be a nice-to-have if the project ever accumulates more manual test scenes like this, but isn't necessary for just one file.
**Confidence:** High.

---

## shop.gd
**Current responsibilities:**
- Shop open/close (`_open_shop`/`_close_shop`)
- Generating the shop's 4 tile offers (deduplicated against tiles already owned/offered, priced by rarity) plus a fixed dice-purchase slot
- Purchase-completion logic when a dragged item is dropped outside the shop's bounding box

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found beyond what's covered under Bugs — `Globals`/`Utils` usage is sanctioned.

**Split recommendation:** No — at 132 lines this is cohesive as "the shop"; the real issue (see Bugs) is a data-modeling fix, not a structural split.

**Bugs:**
- The code already flags this itself: line 114's `## TODO: there is a bug here with accessing stuff, and a visual bug too`. I traced the "accessing stuff" half concretely: `_on_shop_item_dragged()` (line 115) recovers the item's price by **parsing the displayed label text back into an int** (`int(prices[item_to_shop_index[item]].get_child(0).text)`) rather than reading an actual stored price value. This is fragile by construction — it depends on `get_child(0)` always being the price label and its `.text` always being a bare parseable number, and it means the "real" price only exists as rendered UI text rather than as data. Recommend storing the price alongside `item_to_shop_index` (e.g., a parallel `Dictionary[Node, int]` of item→price, populated in `_create_shop_tiles()`/`_create_dice_buy_zone()` where the price is already computed) instead of re-deriving it from a label. I wasn't able to independently confirm the "visual bug" half of the TODO from this file alone — it likely depends on how the `Draggable` component (not yet analyzed) handles an item not being accepted; worth revisiting once `draggable.gd` is analyzed.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/Shop/`, matching the `Shop` entry in ARCHITECTURE_OVERVIEW.md's scene tree.
**Confidence:** High for the price-parsing finding (traced directly); the visual-bug half of the author's own TODO is unconfirmed pending `draggable.gd`.

---

## dice.gd
**Current responsibilities:**
- Die value/visual representation: texture and shader material selection for holographic vs. normal dice, driven by a clamped `value` setter
- Drag-and-drop acceptance checking (`_check_for_acceptor`, broadcasting to any `CanAcceptDice` group member)
- Static shared RNG for rolls plus a tutorial "forced rolls" override queue (mirrors the same documented pattern as `Enemy.rng`/`Enemy.forced_actions`)
- Reroll-with-tween animation
- Self-cleanup from its `host_queue` on tree exit

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** `reroll_with_tween()` (line 76) type-checks `host_queue.get_parent() is Enemy or host_queue.get_parent() is Tile` to decide the die's held scale. This is a mild "knows about specific holder types" coupling — a new kind of die-holder added later would need this list updated here too — though it's a minor, contained instance, not a deep path/autoload issue.

**Split recommendation:** No — 102 lines, cohesive as the core `Dice` entity, comparable to how `Tile`/`Enemy` are kept as single files for their core identity+behavior.

**Bugs:** Worth verifying, but I concluded this is very likely *not* actually a bug after reasoning through it: the `value` setter (lines 25-38) clamps every assignment to `clampi(new_value, 1, 6)`, while `_ready()` (line 44) checks `if value == 0: value = get_random_die_value()` as a sentinel for "no value was explicitly set, roll randomly." If Godot's exported-property initializer invoked the custom `set()` for the class-level default (`= 0`), that default would immediately clamp to `1`, and the `_ready()` sentinel check would never fire — every die would always show face "1" instead of rolling. I believe (based on documented GDScript behavior) that an inline default value on a property with a custom setter is applied directly to backing storage *without* invoking the setter, which is exactly what makes this "0 as an unset sentinel" pattern work correctly — and this is corroborated by the fact that dice visibly roll random values in actual gameplay per the project's history, not always showing "1". Flagging the reasoning here rather than as a live defect, since my conclusion is that it's fine.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/Dice/`, matching ARCHITECTURE_OVERVIEW.md's `Dice` entry.
**Confidence:** High.

---

## enemy_manager.gd
**Current responsibilities:**
- Spawns enemies from scenario data along a spawn path, manages the `enemies` roster (add/remove/query alive/by-faction)
- Runs enemy turns sequentially (`run_enemy_turn`)
- Jump-out sequencing: flies enemies off-screen with a parallax-matched speed, cleans them up once off-screen
- Bulk dev-style operations (`kill_all_enemies`, `damage_all_enemies`, `shield_all_enemies`) — these back the `dev_console.gd` enemy commands
- Propagates the `scenario_engine` reference to every enemy

**Style issues:** none found — double-blank-line-before-function convention checked across all ~18 function boundaries and consistently followed.

**Coupling issues:** none found — extensive but sanctioned `Globals`/`Events` usage, and the `Enemy.seed()`/`Enemy.forced_actions` static references match the documented shared-RNG/tutorial-force design.

**Split recommendation:** No — at 215 lines this touches spawning, turn-running, and jump-animation logic, but all of it serves one cohesive "own and coordinate the enemy roster" responsibility with no clearly separable reason to change.

**Bugs:**
- This file is the confirming link in the global-RNG-reseed chain flagged in `main_menu.gd`/`game_state_manager.gd`: line 42's `Enemy.seed(scenario.scenario_seed)` seeds the shared enemy RNG directly from `scenario.scenario_seed`, which `game_state_manager.gd` sets via the **global** `randi()` function. Combined with `main_menu.gd`'s active `seed('Die Fighter'.hash())` reseed, this confirms enemy behavior RNG would also be deterministic across every playthrough, not just the sector layout.
- Worth verifying/fixing for consistency: `_remove_dead_enemies()` (lines 124-127) guards each entry with only `if not enemies[i] or ...`, while two other methods in this same file — `run_enemy_turn()` (line 136) and `_update_jumping_enemies()` (line 170) — both use the more defensive `if not enemy or not is_instance_valid(enemy):` pattern. A plain truthiness check on a `Node` reference doesn't necessarily catch an already-freed-but-non-null instance the way `is_instance_valid()` does. I can't confirm this window is actually reachable in practice (the normal death flow removes an enemy from `enemies` via `Events.enemy_left` before `queue_free()` runs), so this is a consistency/robustness fix rather than a demonstrated live crash.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/EnemyManager/`, matching ARCHITECTURE_OVERVIEW.md's `EnemyManager` entry.
**Confidence:** High for both findings — the RNG chain is now fully confirmed across three files, and the guard-pattern inconsistency is directly visible within this one file.

---

## legend.gd
**Current responsibilities:**
- Slides a legend panel up/down in response to `Events.map_shown`/`Events.systems_shown` or a direct button press

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found — `%ButtonSprite` is a sanctioned scene-unique reference.

**Split recommendation:** No — small, single-purpose.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/Map/Legend/`.
**Confidence:** High.

---

## map.gd
**Current responsibilities:**
- Camera/slider coordinate math: bounds, position-for-scenario, and bidirectional slider↔camera-position conversion (already isolated as 4 small pure-ish helper functions, lines 42-66)
- Game-save loading and scenario-list ownership
- Engine-charge-driven UI state (arrow-tile highlight/gray-out)
- Map sprite generation from scratch on demand (`_update_map_sprites`, ~70 lines): timeline bars, encounter icons, fate/danger overlay sprites
- Jump mechanics (`jump()`, `_tween_map_to_index()`): validates and animates travel, and spreads the "fate corruption" effect into nearby scenarios
- Danger-zone randomization (`_pick_new_danger_ranges`)
- Map-lock controls (`disable_controls`/`enable_controls`)

**Style issues:** Minor: the doc comments on the camera-math helpers (lines 41, 48, 55, 63, e.g. `##Returns min and max camera positions...`) are missing the space after `##` that every other `##` doc comment in this codebase uses (matching STYLE_GUIDE.md's own example, e.g. `## Hierarchical State machine for the player.`). Blank-line-before-function spacing was spot-checked across this large file and found consistently double-blank.

**Coupling issues:** none found — `Globals`/`Events` usage is sanctioned, and `left_arrow_tile`/`right_arrow_tile` are `@export`-injected `Tile` references, not path traversal.

**Split recommendation:** Yes. At 314 lines, this mixes at least three genuinely separable concerns with different reasons to change: (1) the camera/slider coordinate math (already nicely isolated, could move into a small `MapCameraMath` helper taking `scenario_list`/`sprite_spacing` as parameters), (2) map-sprite visual construction (`_update_map_sprites`, could become a `MapSpriteBuilder`), and (3) the fate-corruption/danger-zone game mechanic (`jump()`'s spreading logic + `_pick_new_danger_ranges()`, could become a `MapCorruptionTracker` owning the `left_fate_index`/`right_fate_index`/`*_scenarios_in_danger` state). What would remain in `Map` is the actual scene-controller identity: `_ready()` orchestration, UI-state updates, `is_valid_destination()`, and control locking.

**Bugs:**
- Confirmed via full-file search: `right_scenarios_in_danger` (declared line 11) is **never assigned or read anywhere else in the file** — `_pick_new_danger_ranges()` only computes `left_scenarios_in_danger`, and `jump()`'s fate-spreading loop only uses `left_fate_index`/`left_scenarios_in_danger`. Meanwhile `right_fate_index` (line 9) *is* used (assigned in `_load_game_save`, read in `jump()`'s "set current scenario to fate/empty" check), but never drives any actual right-side corruption spread or right-side visual rendering — `_update_map_sprites()` only ever builds a `left_fate`/`left_fate_background`/`left_danger` sprite set, with no right-side counterpart anywhere in that ~70-line function. This reads as an unfinished mirror of the left-side corruption mechanic (or vestigial from a design that was simplified to left-only) rather than a working symmetric feature — worth a decision on whether to finish the right-side implementation or remove the dead `right_scenarios_in_danger` field and any now-unnecessary parts of `right_fate_index`'s handling.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/Map/`, matching ARCHITECTURE_OVERVIEW.md's `Map` entry.
**Confidence:** High for both the split rationale and the dead/unfinished right-side-corruption finding (confirmed via exhaustive search of the file, not inferred from a snippet).

---

## money_indicator.gd
**Current responsibilities:**
- Displays the player's money total with a "grace period" that batches rapid successive changes into one animated pop
- Animates a floating `+N`/`-N` change label counting down to zero while the main money label counts up/down to the new total
- Fades itself in the first time a reward with money is spawned

**Style issues:**
- Line 16: only a single blank line separates `var countdown_tween: Tween` from `func _ready()` (line 17), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found beyond what's covered under Bugs.

**Split recommendation:** No — 148 lines, but cohesive: every piece serves the single "animate the money display" responsibility.

**Bugs:**
- Traced a concrete, reproducible bug: `_on_money_changed()` (line 39) computes `total_change = new_value - int(money_label.text)` — reading the **currently displayed label text** as a stand-in for "the previous total," rather than tracking the actual last-known value in a dedicated field. This is fine when the previous count-up animation has already finished (the label shows the true prior total by then) but breaks when a new `Events.set_money` arrives *while the previous countdown/count-up animation is still running* — which is exactly the scenario the grace-period mechanism exists to handle. Concretely: money goes from 0 → 100 (an animation starts counting the label up over ~2s); while that animation is midway and the label currently reads "50", a second change arrives taking money to 150. `total_change` is computed as `150 - 50 = 100`, when the actual new change is `150 - 100 = 50` — the displayed "+100" change indicator would be wrong, overstating the real delta by the amount still mid-animation. Recommend tracking the true last-known total in a dedicated field (e.g., `_last_known_total: int`, updated once per resolved change) instead of parsing it back from the animating label — the same "read state back from rendered text instead of storing it" pattern flagged in `shop.gd`.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/MoneyIndicator/`, matching ARCHITECTURE_OVERVIEW.md's `MoneyIndicator` entry.
**Confidence:** High — traced through concrete example values, not speculative.

---

## targeting_computer.gd
**Current responsibilities:**
- Target selection: keyboard/click cycling through alive enemies with wrap-around, `target_enemy()` for direct targeting
- Target validity re-checking whenever the enemy roster changes
- Intent-display UI sync (`_update_ui`, ~50 lines): builds each of the 6 intent icons, action-amount text, click-for-info wiring, and die-highlight state from the targeted enemy's `turn_actions`
- Presentation: indicator movement/bob tweens, per-die intent-pulse tweens, one-time startup reveal tween

**Style issues:** Spacing in this file is notably inconsistent — I found both a missing-blank case (line 20: only one blank line before `func _ready()`, where the die-sprites array ends at line 19) and two triple-blank cases (lines 47-49 before `func _initial_target()`, and lines 70-72 before `func _on_left_button_input_event()`), against STYLE_GUIDE.md's double-blank convention. I didn't exhaustively check all ~15 function boundaries in this large file, but the mix of under- and over-spacing suggests this file would benefit from a single formatting pass.

**Coupling issues:** `_update_ui()` and `_on_enemy_used_die()` navigate to specific UI elements via positional child indices (`$Intents.get_child(i)`, `.get_child(0)`, `.get_child(1)`) rather than named/unique references. This is within the node's own subtree (not the "deep external path" pattern the rubric targets), but it's still fragile — reordering child nodes in the editor would silently break this. A `%`-unique-name pattern (used extensively elsewhere in this codebase) would be more robust.

**Split recommendation:** Maybe. At 252 lines this mixes input handling, targeting state, intent-display UI construction, and presentation tweens. The clearest, lowest-risk extraction is the one-off startup/reveal logic (`_startup`, `_reveal_tween`, lines 234-251) — fully self-contained with no shared state, a designer tuning intro-reveal timing has nothing to do with targeting logic. The intent-icon UI building (`_update_ui`'s ~50-line body) is a *plausible* second extraction into an owned `EnemyIntentDisplay` component, but it's tightly coupled to `targeted_enemy` state, so the indirection cost is a closer call than the reveal-tween extraction.

**Bugs:**
- Traced a concrete UX issue: `targeted_enemy_index` is a raw array index into whatever `Globals.enemy_manager.get_alive_enemies()` currently returns, not tied to the targeted enemy's identity. `check_target_is_valid()` (called after `Events.enemy_left`, among others) only re-validates that the *index* is still in-bounds — it never re-derives the index from "which enemy was previously targeted." Concretely: if the enemy at index 1 dies while the player is targeting the enemy at index 2, the array shifts and `targeted_enemy_index = 2` now points at whatever enemy used to be at index 3 — the targeting UI would silently swap to a different enemy's intents with no explicit action from the player. Recommend re-deriving `targeted_enemy_index` from `enemies.find(targeted_enemy)` after the roster changes, falling back to bounds-clamping only if the previously-targeted enemy is genuinely gone.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/TargetingComputer/`, matching ARCHITECTURE_OVERVIEW.md's `TargetingComputer` entry.
**Confidence:** High for the targeting-index bug — traced through a concrete death-during-targeting scenario, not speculative.

---

## enemy_dialogue_manager.gd
**Current responsibilities:**
- Shows dialogue text with a character-by-character reveal tween and occasional blip SFX
- Selects a faction-colored dialogue box texture
- Debounces rapid successive dialogue calls with a cooldown timer
- Auto-hides after a configurable display duration; fade in/out animations

**Style issues:** none found per the function-definition spacing convention (the file's few oddly-spaced blank-line runs, e.g. lines 70-72, are mid-function rather than before a function definition, so they aren't the specific rule STYLE_GUIDE.md demonstrates).

**Coupling issues:** none found beyond what's covered under Bugs.

**Split recommendation:** No — under 125 lines, cohesive as "the enemy dialogue box's behavior."

**Bugs:**
- **Likely a real design bug, not just a style nit:** `time_last_dialogue_was_shown` (line 23) is declared `static`, meaning it's shared across **every** `EnemyDialogueManager` instance in the scene, not per-enemy. The debounce logic in `show_dialogue()` (lines 38-43) reads clearly like it's meant to stop one enemy from re-triggering its own dialogue too rapidly — but because the timestamp is static/global, if two *different* enemies both want to show dialogue around the same time (e.g., both entering an aggressive state at scenario start, since `Events.start_scenario` triggers `trigger_state_effects()` on every enemy), the second enemy's dialogue box would be artificially delayed by the first enemy's cooldown, even though they're separate, non-overlapping UI elements with no real reason to be throttled together. Recommend making this an instance member (drop `static`) unless there's a deliberate global rate-limit intent I'm not seeing from this file alone.
- Confirmed dead code via full-file search: `_set_text()` (lines 117-121) is never called anywhere in this file — `show_dialogue()` sets `%RichTextLabel.text` directly (line 49) without ever going through this wave-BBCode-wrapping helper.
- Confirmed unused via full-file search: `yellow_dialogue_box` (line 15) is declared but never referenced again — `faction_textures` (lines 17-21) only maps `CIVILIAN`→green and `PIRATE`/`BOSS`→red, and `ScenarioManager.Faction` only has those three members, so there's no path that would ever need yellow.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/EnemyDialogueManager/`.
**Confidence:** High for the dead-code findings (confirmed via full-file search); High for the `static` debounce issue's mechanism (unambiguous GDScript semantics), Medium on whether the multi-enemy-delay symptom is actually noticeable in practice without observing it live.

---

## tile_grid.gd
**Current responsibilities:**
- Grid coordinate math (`grid_to_global_pos`, `global_pos_to_grid`, `grid_to_local_pos`, validity/openness checks)
- Tile creation/loading from a save (`create_tile`, `_setup_tiles`, `_load_game_save`)
- Drag-and-drop drop resolution (`_drop_tile_on_grid_pos`, ~55 lines): handles landing on an open cell, swapping with an occupied cell, or snapping back when dropped outside the grid or with nowhere to go
- Programmatic tile placement (`move_tile`, `receive_tile`, `_assign_tile_to_grid_pos`)
- The Asteroids-style push mechanic (`push_tile`)

**Style issues:** none found — double-blank-line-before-function convention checked across all function boundaries and consistently followed. Minor naming nit: `_setup_tiles(_tile_locations: ...)`'s parameter is prefixed with an underscore (a convention this codebase and GDScript generally use for "intentionally unused"), but it's actually used throughout the function body (line 49 onward) — the underscore prefix is misleading here.

**Coupling issues:** none found — all interaction goes through the `tile_locations` dictionary and each `Tile`'s own `@export`-injected `draggable` component; no deep external path traversal.

**Split recommendation:** No — at 269 lines this is a legitimately complex but cohesive core mechanic; drag-drop resolution, programmatic placement, and the push mechanic all share and mutate the same `tile_locations` state and don't have genuinely separable reasons to change.

**Bugs:** none found. I specifically traced two non-obvious operations end-to-end with concrete positions to check for a classic "moved data reads its own overwritten state" mistake, since both mutate `tile_locations` while reading it: (1) the tile-swap logic in `move_tile()`/`_drop_tile_on_grid_pos()` (moving the existing occupant to the incoming tile's old slot *before* moving the incoming tile) is safe because `_assign_tile_to_grid_pos()` re-derives each tile's current position fresh via `find_tile_pos()` rather than using a stale captured value; (2) `push_tile()`'s reverse-order iteration (farthest tile first) is safe because each iteration only reads a `from_pos` that hasn't yet been written to by an earlier (farther) iteration.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/TileGrid/`, matching ARCHITECTURE_OVERVIEW.md §8.3.
**Confidence:** High.

---

## money_particle.gd
**Current responsibilities:**
- A floating money-pickup particle: random float velocity that decays over a randomized lifetime, then homes in on the money indicator via tween, and is "collected" (adds money, spawns a small effect, plays SFX, frees itself) on physical overlap with the money indicator's collision area

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed. Naming inconsistency worth flagging: the `money_amount` enum (line 7) is snake_case, where every other enum encountered across this entire pass (`ButtonSize`, `ScreenShowing`, `Faction`, `GameState`, `ActivationType`, `EventType`, `Attitude`, `ScenarioEvent`) is PascalCase. STYLE_GUIDE.md doesn't include an enum example to cite directly, so this isn't a formally-demonstrated rule violation, but given how uniform the PascalCase convention is elsewhere in this same codebase, it's worth renaming to `MoneyAmount` for consistency.

**Coupling issues:** none found.

**Split recommendation:** No — small, cohesive single-purpose particle (105 lines).

**Bugs:** none found. Worth noting as a design detail rather than a defect: `money_amount`'s enum values (`SMALL = 1`, `LARGE = 5`) intentionally double as the actual money amount added on pickup (`Globals.player.money += amount`, line 96) — not just an arbitrary identifier. This is consistent and correctly relied upon by `reward.gd`'s `_spawn_money_particles()` (see that entry), just worth flagging as an implicit dual-purpose value that isn't obvious from the enum alone.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/MoneyParticles/`.
**Confidence:** High.

---

## jump_manager.gd
**Current responsibilities:**
- Orchestrates the full hyperspace jump sequence: jump signal → background jump-intro → delay → load new scenario → background jump-outro → start scenario

**Style issues:** none found — double-blank-line-before-function convention followed (lines 3-4, 8-9).

**Coupling issues:** none found — sanctioned `Globals`/`Events` usage throughout.

**Split recommendation:** No — trivial, single-purpose orchestration (19 lines).

**Bugs:** none found — a clean, simple sequencing function matching ARCHITECTURE_OVERVIEW.md's documented jump flow.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/JumpManager/`, matching ARCHITECTURE_OVERVIEW.md's `JumpManager` entry.
**Confidence:** High.

---

## reward_resource.gd
**Current responsibilities:**
- Pure data resource: money reward range, number of reward items, and probability of a dice reward vs. a tile reward

**Style issues:** none found — no functions, nothing to check.

**Coupling issues:** none found.

**Split recommendation:** No — trivial data schema.

**Bugs:** none found.

**Suggested folder:** Content — this is a data-driven content resource referenced by `ScenarioResource.rewards` and `EnemyStateRewardResource.reward_resource` (both Content-tier), matching the same relocation reasoning already given for `BackgroundResources`/`SoundEffectResources`/`game_save.gd` earlier in this pass. Recommend moving under `Source/Content/` alongside those.
**Confidence:** Medium — same caveat as the other resource-relocation recommendations in this pass (placement judgment based on sibling-convention matching and consuming-class dependencies, not visible reverse-dependencies).

---

## reward.gd
**Current responsibilities:**
- Reward-pickup popup sequencing: spawns money particles, waits, then reveals `num_of_rewards` items (dice or tiles), with fallback rules (give dice instead of a tile when the grid has no space, no eligible tile rewards remain, or by the configured `dice_probability`) and tutorial-forced-reward support
- Drag-to-claim completion handling (`_end_reward`)
- Converts a claimed money amount into a spawn count of `MoneyParticle` instances (`_spawn_money_particles`)

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found beyond sanctioned `Globals` usage.

**Split recommendation:** No — 118 lines, cohesive as "the reward popup's behavior"; reward-type selection and its presentation are tightly bound (adding a new reward type touches both together).

**Bugs:** none found. Minor cleanup notes: line 21's `#Globals.player.money += money` is commented-out leftover from before the particle-based money system replaced a direct instant-add (harmless, just worth deleting); `_spawn_money_particles()`'s `floor(amount / MoneyParticle.money_amount.LARGE)` (line 109) wraps an already-integer GDScript `/` division (which truncates for two ints) in a redundant `floor()` call — harmless, just unnecessary.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/RewardManager/`; this is the behavior/scene-controller half of the reward system (as opposed to `reward_resource.gd`'s data half, recommended for relocation above).
**Confidence:** High.

---

## reward_manager.gd
**Current responsibilities:**
- Loads every `TileResource` from two hardcoded directories on startup (`_load_tile_resources`)
- Computes eligible tile rewards by excluding tiles the player already has on the grid (`get_possible_tile_rewards`)
- Spawns `Reward` popup instances (`_spawn_reward`)

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** `_load_tile_resources()` (lines 15-30) is a **third independent copy** of the exact same directory-scanning logic already flagged twice in `dev_console.gd` (`_get_available_tile_names()`/`_load_tile_by_name()`) — same two hardcoded directories (`Source/Content/Tiles/TileResources/`, `Source/Content/Tiles/ComplicatedTileResources/`), same `.ends_with(".tres")` filter, same `ResourceLoader.load` pattern. Recommend a single shared utility (e.g. `TileResourceRegistry.get_all_tile_resources() -> Array[TileResource]`) that both this file and `dev_console.gd` call, rather than three copies of the same directory walk.

**Split recommendation:** No — small (48 lines), cohesive.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/RewardManager/`, matching ARCHITECTURE_OVERVIEW.md's `RewardManager` entry.
**Confidence:** High.

---

## player.gd
**Current responsibilities:**
- Core player state: health/shields wiring, `engine_charge`/`num_of_dice`/`money` setters with side-effecting signal emission
- Turn flow: reroll, spawn dice, end turn, start-of-turn/start-of-scenario handling
- Drag-based dice-queue reordering input handling in `_process()` (~40 lines of mouse-position/bounding-rect math)
- Signal orchestration in `_ready()` wiring `health`/`dice_manager`/many `Events` together

**Style issues:**
- Lines 104-106 contain three consecutive blank lines between the end of `_reset_newest_die_transform()` and `func _process()` (line 107), where every other boundary in this file uses the double-blank convention from STYLE_GUIDE.md.
- `_load_scenario()`'s single-line body (line 207, `Dice.seed(scenario.scenario_seed)`) is indented with two tabs instead of one relative to its `func` declaration (line 206) — a self-contained indentation inconsistency within this one function, similar to the one found earlier in `enemy_health_bar.gd`.

**Coupling issues:** none found — sanctioned `Globals`/`Events` usage, and `get_tree().get_nodes_in_group('Dice')` (line 183) is a sanctioned group-based lookup rather than path traversal.

**Split recommendation:** Maybe. At 221 lines, the drag-based dice-queue-reordering logic in `_process()` (lines 108-147) is a distinct, self-contained input-handling concern — it only touches `dice_manager`/`_dice_queue_spacing`, not the rest of Player's state (health, money, engine charge, turn flow) — and could reasonably be extracted into a small owned component (e.g. alongside the existing `DiceQueue`/`Draggable` components) without much added indirection, since it doesn't need to reach back into anything else on `Player`.

**Bugs:**
- Worth verifying: `num_of_dice`'s setter (lines 21-27) computes `max_engine_charge = (6*(num_of_dice-1)) - floor(1.7078 * sqrt(num_of_dice))`, matching the formula documented in ARCHITECTURE_OVERVIEW.md §8.1. I evaluated it directly: for `num_of_dice = 1`, this yields `(6*0) - floor(1.7078*1) = 0 - 1 = **-1**` — a negative `max_engine_charge`. Since `engine_charge`'s own setter (line 14) does `clampi(new_value, 0, max_engine_charge)`, a negative max would mean the clamp's min (0) exceeds its max (-1), which is undefined/implementation-specific behavior for `clampi()`. I can't confirm from this file alone whether `num_of_dice` ever actually reaches exactly `1` in this game's default starting configuration (likely players start with more than one die), so this is a real formula edge case worth checking against the actual starting `GameSaveResource` values, not a confirmed live crash.
- Line 151: `print('tile activation complete emitted')` in `_check_for_end_of_turn()` is a leftover debug print left in shipping code — this fires every time a tile activation completes, which is frequent during normal play. Recommend removing.
- Confirms and extends the global-RNG-reseed finding from earlier in this pass: `_load_scenario()` (line 207) calls `Dice.seed(scenario.scenario_seed)`, meaning the same poisoned `scenario_seed` chain (traced through `main_menu.gd` → `game_state_manager.gd` → `enemy_manager.gd`) also determines every die roll for the entire run, not just sector layout and enemy behavior. See `main_menu.gd`'s entry for the root cause.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/Player/`, matching ARCHITECTURE_OVERVIEW.md §8.1.
**Confidence:** High for the debug-print and RNG-chain findings (directly visible/confirmed); Medium for the `num_of_dice=1` formula edge case, since I can't confirm it's reachable in practice from this file alone.

---

## player_health_bar.gd
**Current responsibilities:**
- Extends `HealthBarController` to add player-specific shield-frame visuals, hull/shield info popups, and a startup reveal-tween sequence

**Style issues:** none found for blank-line spacing (checked all boundaries, consistently double-blank). Worth a mention: line 20's `else:\` uses an unnecessary line-continuation backslash to join the `else:` with its single-statement body on the next line — equivalent to writing `else: %Shields.frame = 0` on one line, just via an unusual/confusing route. `validate_scripts` confirms this parses without error, so it's a readability nit, not a defect.

**Coupling issues:** none found — `%RevealOverlay`/`%Shields` are sanctioned scene-unique references.

**Split recommendation:** No — small (75 lines), cohesive specialization of `HealthBarController`.

**Bugs:**
- Worth verifying, likely a real bug: `_set_shields()` (lines 14-21) compares `health_component.shields` against `health_component.max_health` (not a shields-specific capacity) to decide which visual frame to show. Elsewhere in this codebase (`enemy.gd`'s `_update_health_from_resource()`), shield capacity (`starting_shields`) is configured completely independently from `max_health` — if the player's shield capacity is meaningfully smaller than `max_health` (plausible, since they're separate stats), this threshold would be wrong: e.g., with `max_health=20` and a shield cap of `5`, `shields < max_health/2.0` (`5 < 10`) would be true even at *full* shields, so the "full shields" frame (0) might never actually display. I haven't yet analyzed `health.gd` directly to confirm its exact field names, so I'm not asserting this as 100%-confirmed until cross-checking there, but the evidence from `enemy.gd` strongly suggests `max_health` is the wrong denominator here.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Game/Player/PlayerHealthBar/`, specializing `HealthBarController` for the player (parallel to `EnemyHealthBar`).
**Confidence:** High for the style/spacing findings; **now confirmed High** for the shield-frame threshold bug — `health.gd` (analyzed next) confirms `starting_shields` is a completely independent field from `max_health`, exactly as suspected.

---

## health.gd
**Current responsibilities:**
- HP/shields state with clamping, `take_damage()` (splitting damage between shields and health), `change_health()`/`change_shields()`, death/fatal-damage signaling, an invulnerability toggle

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found — clean, fully decoupled component.

**Split recommendation:** No — small (73 lines), cohesive.

**Bugs:** none — **retracted after developer confirmation.** I originally flagged `change_shields()` (line 67): `shields = clampi(shields, 0, shields)` as a bug, reading it as a no-op clamp that should have referenced a max-shields field (by analogy with `change_health()`'s `clampi(health, 0, max_health)` immediately above it). The developer confirmed shields are intentionally uncapped — floor at 0, no maximum — and this expression does correctly produce exactly that: Godot's `clampi(value, min, max)` returns `min` when `value < min`, and `value` unchanged otherwise; with `max` set to `shields` itself, the "ceiling" branch can never trigger, so this is equivalent to `maxi(shields, 0)`. Not a bug. Still worth a clarity-only pass: `shields = maxi(shields, 0)` expresses the same behavior without reading like a copy-paste error (which is exactly how it was misdiagnosed here) — tracked as a style nit in `GLOBAL_CLEANUP_PLAN.md` rather than a bug.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Components/Health/`, matching the documented Components pattern.
**Confidence:** High.

---

## can_accept_dice.gd
**Current responsibilities:**
- Checks whether a drop point falls within a rectangular collision area and emits `die_accepted` if so, gated on `enabled`/visibility

**Style issues:** none found — double-blank-line-before-function convention followed (lines 9-10, 17-18).

**Coupling issues:** none found — receives `die`/`drop_pos` as parameters, no autoload or path reach.

**Split recommendation:** No — trivial, single-purpose.

**Bugs:** none found. The doc comment's self-documented constraint ("Intended to work only with a RectangleShape2D," line 4) matches its actual use of `.shape.get_rect()`, so this isn't an undocumented fragility.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Components/CanAcceptDice/`.
**Confidence:** High.

---

## draggable.gd
**Current responsibilities:**
- Drag-state machine (`DragState`: DEFAULT/ENEMY_HOLDING/MOVING_WITH_CODE/DRAGGING) and mouse-drag input handling
- Floating idle-bob animation (sine-wave bob/drift/rotation) when at rest near `home_position`
- "Wiggle" tween juice while actively being dragged
- Hover scale feedback and SFX
- `snap_back()` — intended to return the object to its home position on a rejected drop

**Style issues:** none found — double-blank-line-before-function convention checked across every boundary and consistently followed.

**Coupling issues:** `_on_mouse_entered()`/`_on_mouse_exited()` (lines 156-157, 166-167) type-check `parent.host_queue.get_parent() is Tile` and `parent is Dice` — this is a Systems-tier component (`Source/Systems/Components/`) directly referencing specific Content-tier classes (`Dice`, `Tile`). Per ARCHITECTURE_OVERVIEW.md's dependency-flow rule (Content depends on Systems, not the reverse), this is a reverse dependency that couples an otherwise-generic, reusable drag component to specific game content types, working against its own reusability. Separately, `_on_input_event()` (line 127) checks `parent_node.has_node("Clickable") and parent_node.clickable` — a redundant double-check mixing a hardcoded string-based child-name lookup with an `@export`-based reference to (presumably) the same node; if the child were ever renamed, `has_node("Clickable")` would silently fail even though `.clickable` still resolves correctly. Recommend dropping the `has_node()` check and relying on `.clickable` alone.

**Split recommendation:** Maybe. At 175 lines this mixes core drag-state input handling with a self-contained ~20-line floating/idle-bob animation subsystem (its own dedicated `bob_amplitude`/`drift_amplitude`/`rotation_amplitude` export parameters and sine-wave math, lines 105-116) that a VFX-focused contributor could reasonably want to tune in isolation from the drag mechanics. Extracting it into a small `FloatingIdleAnimator` component (delegated to when `state == DEFAULT`) is a plausible, low-risk split.

**Bugs:**
- **Significant, worth flagging clearly:** `snap_back()` (lines 173-174) is an empty stub — `func snap_back() -> void: return`. `tile_grid.gd` calls this in two places expecting it to return a tile to its home position (with a comment there literally claiming "Draggable handles snapping back to home_position"), but it does nothing. That said, I traced through `_process()`'s passive homing behavior (lines 105-116) and found that once a drag ends, `state` becomes `DEFAULT` regardless of whether the drop was accepted or rejected, and the `DEFAULT`-state branch continuously lerps the object back toward `home_position` every frame anyway — so objects likely still end up back home in practice, just via a smooth multi-frame drift rather than the immediate "snap" the name and surrounding comments imply. This is a real, confirmed no-op function masquerading as working code (worth fixing or removing to avoid misleading future readers), but I don't believe it currently causes a "stuck forever" visual bug given the fallback homing behavior.
- I verified `_ready()`'s commented-out `#mouse_entered.connect(_on_mouse_entered)` / `#mouse_exited.connect(_on_mouse_exited)` (lines 63-64) are **not** dead code left behind by mistake — `draggable.tscn` wires these same signals to the same methods via the scene editor's own connection list, so the code-based connections were correctly disabled to avoid double-firing. Flagging this only because it looked suspicious at first glance and is worth ruling out explicitly rather than assuming.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Components/Draggable/`.
**Confidence:** High for the `snap_back()` finding and the Content-type coupling (both directly verified in code); the practical severity of `snap_back()` being empty is tempered by the passive-homing fallback I traced through.

---

## health_bar_controller.gd
**Current responsibilities:**
- Base health/shield bar visual controller (extended by `PlayerHealthBar`/`EnemyHealthBar`): tweens a main health bar quickly, a secondary "damage trail" bar slowly after a delay, and applies a text-shake BBCode effect on damage

**Style issues:** Found three separate spacing inconsistencies against STYLE_GUIDE.md's double-blank-line-before-function convention: line 71 (single blank before `_get_shield_string`), lines 85-87 (triple blank before `_start_health_text_shake`), and line 91 (single blank before `_set_shields`) — a mix of under- and over-spacing within one file.

**Coupling issues:** none found — `%HealthBar`/`%HealthUpdateBar`/`%HealthLabel`/`%ShieldsLabel`/`%Shields` are sanctioned scene-unique references, and `health_component: Health` is standard Systems-to-Systems composition.

**Split recommendation:** No — cohesive single-purpose base component (106 lines), correctly designed for subclass override (`_get_health_string`/`_get_shield_string`).

**Bugs:** none found. The two-tier "instant bar + delayed white damage-trail bar" pattern (`_set_health()` + the `need_to_update_health_white` handling in `_process()`) is correctly implemented — the delayed bar update only fires once `damage_update_time` has elapsed and is properly reset via the `need_to_update_health_white` flag.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Components/HealthBarController/`.
**Confidence:** High.

---

## clickable.gd
**Current responsibilities:**
- Click detection (press-then-release within a time window and movement radius, to distinguish a click from a drag)
- Hover-delay tracking that fires `hover_delay_completed` after a configurable delay, used to trigger the info-tooltip system
- Hover-state signals, including notifying the global `Events.set_current_clickable` bus (consumed by `mouse_cursor.gd`)

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found — `Events.set_current_clickable` is the sanctioned Content/Systems→Systems direction.

**Split recommendation:** No — small (63 lines), cohesive.

**Bugs:** none found. Cross-checked against `draggable.gd`'s use of `reset_hover_state()` (called when a drag starts, to cancel any pending hover-info popup) and `mouse_cursor.gd`'s consumption of `set_current_clickable` — both integrate correctly with this component's public surface.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Components/Clickable/`.
**Confidence:** High.

---

## shakeable.gd
**Current responsibilities:**
- Small/large shake effects on a target node via lerp-based random-offset shaking with decaying intensity, self-terminating after a fixed duration
- `@tool`-mode editor test buttons (`@export_tool_button`) to trigger shakes directly in the Inspector without running the game

**Style issues:** Lines 51-53 contain three consecutive blank lines between the end of `_process()` and `func small_shake()` (line 54), where every other boundary in this file uses the double-blank convention from STYLE_GUIDE.md.

**Coupling issues:** none found — this is a genuinely generic, reusable component with no Content-tier references at all.

**Split recommendation:** No — small (82 lines), cohesive.

**Bugs:** none found. I specifically checked `_start_shake()`'s reset-then-recapture of `original_position` (lines 69-72) for a potential double-reset bug when one shake interrupts another mid-shake — it's correct and intentional: resetting to the old original position first, then recapturing it (now a no-op since it's already there), prevents positional drift from accumulating across interrupted shakes.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Components/Shakeable/`.
**Confidence:** High.

---

## tutorial_manager.gd
**Current responsibilities:**
- Tutorial step sequencing (`start_tutorial`, `play_step`): waits for a configured open-trigger signal, applies forced dice/enemy-action/reward overrides for the step, creates the tutorial popup, wires whichever signal should close it
- A dev-only "skip to step N" fast-forward path in `_ready()`, replaying steps' forced overrides and tutorial functions without showing their popups
- ~14 small "tutorial trigger function" implementations dispatched via a `Dictionary[TutorialFunctions, Callable]`

**Style issues:** Spot-checked roughly 20 function boundaries across this file (including the large block of trigger functions from line 153 onward) and found the double-blank-line convention consistently followed throughout — a rarity for a file this size in this pass. Minor typo, not a formal style issue: line 86, `is_active  = false`, has a double space before `=`.

**Coupling issues:** none found — extensive but sanctioned `Globals`/`Events` usage; `Globals.map.right_arrow_tile.can_accept_dice.enabled` (line 194) is a long chain but each link is a typed `@export` reference, not string-based path traversal.

**Split recommendation:** Maybe, narrowly scoped: `play_step()` (lines 89-151, ~60 lines) is noticeably denser than the rest of the file, mixing open-signal waiting, forced-override application, popup creation, and close-signal wiring in one function. Breaking it into smaller named steps (e.g. `_apply_forced_overrides(step)`, `_wire_close_signal(step)`) would improve readability without needing a full file split — the ~14 tiny trigger functions themselves are legitimately cohesive as "the tutorial's command vocabulary" and shouldn't be split out.

**Bugs:**
- Confirmed via full-codebase `grep`: `play_step()`'s `force_open: bool = false` parameter (line 89) is never read anywhere in the function body, and its only call site (`start_tutorial()`, line 83) doesn't pass it either. Dead parameter.
- Line 61 (inside the `_ready()` skip-to-step loop): `print("Step: ", skipped_step, " -> ", step.tutorial_function)` is leftover debug output. Lower practical impact than similar findings elsewhere in this pass, since it's gated behind `skip_to_step > 0`, a dev-only field defaulting to `0` — but still worth removing.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/TutorialManager/`, matching ARCHITECTURE_OVERVIEW.md's `TutorialManager` entry.
**Confidence:** High for both findings — confirmed via full-file/full-codebase search rather than inferred.

---

## tutorial_text_popup.gd
**Current responsibilities:**
- Fade in/out animation
- Custom character-by-character text reveal with delay-tag support (built on `Utils`' delay-tag parsing/mapping subsystem) and periodic blip SFX
- Close-button state management and click-anywhere-to-skip-to-full-text

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed. Minor cleanup note: lines 54-59 are a block of commented-out "bob the computer head" tween code — a disabled/abandoned feature worth either removing or re-enabling.

**Coupling issues:** none found — `%CloseButton`/`%RichTextLabel`/`%ComputerTalking`/`%CompleteTextButton` are sanctioned scene-unique references. This file is a real, live consumer of `Utils`' delay-tag-mapping subsystem (`parse_delay_tags`/`remove_delay_tags`/`format_text`/`strip_bbcode_tags`/`map_delay_positions`, lines 62-68) flagged as complex in that file's own entry.

**Split recommendation:** No — 161 lines, cohesive as "the tutorial popup's behavior."

**Bugs:**
- Worth verifying/reordering for safety: `close()` (lines 118-129) calls `queue_free()` (line 127) *before* `popup_closed.emit()` (line 129). Since `queue_free()` only schedules deferred deletion rather than freeing immediately, the signal still fires successfully because the node isn't actually destroyed yet at that point in the same synchronous continuation — I traced this through and it works correctly for the current caller (`tutorial_manager.gd`'s `await current_popup.popup_closed`, which does nothing further with the popup afterward). But the ordering is backwards from best practice (emit-then-free is safer than free-then-emit) and would become a real bug if a future `popup_closed` listener ever needed the node to still be usable across a further `await`. Recommend swapping the order.
- I also verified `_finish_showing_text()`'s click-to-skip path doesn't leave the original `_reveal_next_character()` recursive await-chain running in a broken state afterward — its next scheduled resume correctly hits the `if popup_completed: return` guard (set by `when_text_shown()`) and exits cleanly, so no double-reveal or race occurs.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/TutorialManager/TutorialTextPopup/`.
**Confidence:** High for both findings — traced through concrete execution order, not speculative.

---

## tutorial_step.gd
**Current responsibilities:**
- Pure data resource: tutorial text/position/timing, forced dice/enemy-action/reward overrides, open/close trigger enums (`TutorialSignals`), and the tutorial function to invoke (`TutorialFunctions`)

**Style issues:** none found per demonstrated STYLE_GUIDE.md rules — no functions, nothing to check.

**Coupling issues:** none found.

**Split recommendation:** No — cohesive data schema.

**Bugs:** none found. I cross-checked all 14 non-`NONE` `TutorialFunctions` enum members against `tutorial_manager.gd`'s `tutorial_functions` dictionary keys — every one has a corresponding entry, so `play_step()`'s `if step.tutorial_function in tutorial_functions:` guard won't silently skip a configured function due to a missing dictionary entry.

**Suggested folder:** Its current location (`Source/Systems/TutorialManager/TutorialStepResources/`) is reasonable as-is — this is tutorial-authoring content, but it's tightly coupled to `TutorialManager`'s specific enums/dictionary in a way that doesn't fit the more generic Content-resource relocation pattern recommended for `BackgroundResources`/`SoundEffectResources`/etc. earlier in this pass.
**Confidence:** Medium — placement is a closer judgment call than most other files in this pass, given it's genuinely borderline between "content" and "Systems feature configuration."

---

## jump_transition.gd
**Current responsibilities:**
- Fades the background shader and particle-sheet layers in/out during a hyperspace jump transition

**Style issues:**
- Line 10: only a single blank line separates `var fade_tween: Tween` from `func set_transparency()` (line 11), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found — `%JumpTexture`/`%ParticleSheet` are sanctioned scene-unique references.

**Split recommendation:** No — small (52 lines), cohesive.

**Bugs:**
- Confirmed via full-file search: `var fade_tween: Tween` (line 9) is declared but never assigned or read anywhere in the file — `tween_particles()` and `tween_background()` each create their own independent local `Tween` instead. This looks like an incomplete implementation rather than simple dead code: every other tween-owning script analyzed in this pass (e.g. `_saturation_tween`, `_bob_tween`, `movement_tween`) uses exactly this kind of tracked field to `kill()` an in-progress tween before starting a new one, preventing two tweens from fighting over the same shader parameter if triggered in quick succession. Here that safety net is missing — `fade_tween` was seemingly intended for it but never wired up. Recommend either using it to kill/replace the previous tween in `tween_particles()`/`tween_background()`, or removing the unused field if concurrent calls are known not to happen.
- Minor cleanup: line 7's `#var particle_sprites:` is a dead, incomplete commented-out declaration.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Graphics/JumpTransition/`.
**Confidence:** High.

---

## vignette.gd
**Current responsibilities:**
- Full-screen color-flash vignette effect triggered on player health/shield hits

**Style issues:** Lines 11-13 contain three consecutive blank lines between the end of `_ready()` and `func _health_hit_vignette()` (line 14), where the rest of the file (lines 20-21) uses the double-blank convention from STYLE_GUIDE.md.

**Coupling issues:** `_health_hit_vignette()` and `_shield_hit_vignette()` are near-identical — same two-tween flash structure and timing, differing only in the color (`Globals.red` vs `Globals.blue`). This is the same "duplicated logic differing only by color" pattern flagged in `enemy_graphics_manager.gd`'s `_health_hit_flash`/`_shields_hit_flash` earlier in this pass. Recommend a shared `_flash(color: Color)` helper.

**Split recommendation:** No — small (28 lines), cohesive.

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Graphics/Vignette/`, matching ARCHITECTURE_OVERVIEW.md's `Vignette` entry.
**Confidence:** High.

---

## debris_piece.gd
**Current responsibilities:**
- Randomizes a background debris sprite's texture, rotation, and velocity/parallax-speed shader parameters

**Style issues:** none found — double-blank-line-before-function convention checked at every boundary and consistently followed.

**Coupling issues:** none found.

**Split recommendation:** No — small (41 lines), cohesive.

**Bugs:** none found. Worth a naming-clarity note: this class defines a method named `randomize()` (line 15), which shadows Godot's global built-in `randomize()` function (used to reseed the global RNG from system entropy). Calling it as `piece.randomize()` on a `DebrisPiece` instance correctly resolves to this method, not the global one, so it isn't a functional bug — just a naming choice that could confuse a reader expecting the global function's behavior.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Graphics/BackgroundManager/BackgroundObjects/`.
**Confidence:** High.

---

## twinkling_star.gd
**Current responsibilities:**
- Loops an ambient "twinkle" animation at randomized intervals for the lifetime of the node

**Style issues:**
- Line 2: only a single blank line separates `extends AnimatedSprite2D` from `func _ready()` (line 3), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found.

**Split recommendation:** No — trivial (9 lines).

**Bugs:** none found. The `while true:` loop with `await` calls inside `_ready()` is a standard, idiomatic Godot pattern for an ambient effect that runs for the node's lifetime — when the node is freed, pending awaits on its own coroutine are safely abandoned by the engine rather than causing an error, which is the expected behavior here (not something I'm treating as a live edge case without evidence otherwise).

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Graphics/BackgroundManager/BackgroundObjects/`.
**Confidence:** High.

---

## nebula.gd
**Current responsibilities:**
- Scrolls a nebula sprite's shader `uv_offset` based on an externally-set `speed` value

**Style issues:**
- Line 5: only a single blank line separates `var uv_offset: float = 0` from `func _process()` (line 6), where STYLE_GUIDE.md's convention calls for a double blank line before a function definition.

**Coupling issues:** none found.

**Split recommendation:** No — trivial (9 lines).

**Bugs:** none found.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Graphics/BackgroundManager/BackgroundObjects/`.
**Confidence:** High.

---

## black_hole.gd
**Current responsibilities:**
- A procedural black-hole visual effect (shader-driven disk/accretion-ring rendering with a cosine-based procedural color palette generator) — self-animating via `_process()`, plus a large customization API (pixel size, light direction, seed, rotation, custom time, dithering, color get/set, colorscheme generation/randomization)

**Style issues:** This entire file deviates wholesale from this codebase's established conventions rather than having isolated issues: no type hints anywhere (`func _ready():`, `var time = 1000.0`, `func set_pixels(amount):`, etc.), where every other file in this ~100-file review consistently uses typed variables and return annotations. Combined with the generic naming (`set_pixels`, `get_colors_from_shader`, the Inigo-Quilez-style cosine palette formula in `_generate_new_colorscheme`) and stale commented-out code using the Godot 3.x `rand_range` API name (lines 65, 67 — replaced by `randf_range` in Godot 4), this reads as a vendored or heavily-adapted third-party/tutorial asset rather than originally-authored project code. Recommend treating it as vendored (don't reformat to match project style, since that risks losing sync with the upstream source) rather than nitpicking individual lines.

**Coupling issues:** none found beyond what's noted under Bugs.

**Split recommendation:** No — treat as a vendored asset; splitting it would fight against re-syncing with its likely upstream source.

**Bugs:** Confirmed via `grep` across the entire `Source/` tree: of this file's ~14 public methods, only the two lifecycle callbacks (`_ready`/`_process`) and whatever the shader consumes automatically are actually exercised — `set_light`, `set_seed`, `set_rotates`, `set_custom_time`, `set_dither`, `get_dither`, `get_colors`, `set_colors`, and `randomize_colors` are never called from anywhere else in the codebase (`set_pixels` also appears unused via the same check). `set_light()` itself (line 27-28) is also an empty `pass`-only stub regardless. This suggests the project only actually uses this asset's default baked-in animation, not its rich customization API — worth confirming intentional before assuming any of it needs to work.

**Suggested folder:** Systems — its current location (`Source/Systems/Graphics/BackgroundManager/BackgroundObjects/BlackHole/`) is reasonable for a background visual effect; not recommending a move given its vendored nature.
**Confidence:** High that the listed methods are unreferenced (direct `grep` evidence across the whole tree); Medium on whether that's actually fine (vs. representing an incomplete integration) since I can't see the original asset's intended usage.

---

## background_manager.gd
**Current responsibilities:**
- Parallax motion for stars/debris/static objects via a well-designed generic `_update_objects_motion()` helper (avoiding the kind of triplicated per-object-type update loop seen elsewhere in this pass)
- Background selection and setup from `BackgroundResource`/`RandomBackgroundResource` data (stars, debris, nebula, static objects)
- Hyperspace jump visual sequencing (`play_jump_intro`/`play_jump_outro`, driving `%JumpTransition` and a background-speed ramp)

**Style issues:** none found — spot-checked across the file's ~20 function boundaries and found the double-blank-line convention consistently followed.

**Coupling issues:** none found — sanctioned `Globals`/`Events` usage, and `%JumpTransition`'s method calls (`set_background_transparency`, `tween_particles`, `tween_background`, etc.) all correctly match `jump_transition.gd`'s actual public API.

**Split recommendation:** Maybe. At 289 lines, the hyperspace jump-sequencing logic (`play_jump_intro`/`play_jump_outro`/`tween_speed`, ~60 lines) is a reasonably separable concern from ambient parallax/background management — a designer tuning jump-transition timing has no reason to touch star/debris spawning code. Given `jump_transition.gd` already exists as a dedicated scene/script for the visual side of this sequence, moving the sequencing logic itself there (or into a small dedicated controller) is a plausible, moderate-value split; the parallax/background-setup code is otherwise cohesive and well-factored as-is.

**Bugs:**
- Confirms and extends the global-RNG-reseed finding from earlier in this pass: line 39's `seed(scenario.scenario_seed)` (calling this class's own static `seed()`, line 140-141) means background selection RNG is a **fourth** system fed by the same poisoned `scenario.scenario_seed` chain (alongside sector layout, enemy behavior, and dice rolls) — see `main_menu.gd`'s entry for the root cause.
- `set_global_speed()` (lines 116-124) is never called anywhere else in the codebase (confirmed via `grep`) — dead code. Separately, its nebula-speed-setting logic uses a different `base_speed` (`Vector2(0, -0.01)`, setting a shader parameter named `"speed"` directly) than the live, every-frame `_update_nebula_speed()` (`base_speed = -0.005`, setting the `nebula.speed` property consumed by `nebula.gd`'s own `_process()`). Since `set_global_speed()` is unreachable, this discrepancy has no current effect, but it's worth reconciling if this function is ever revived — I can't confirm from this file alone whether the two mechanisms are meant to be complementary (separate shader effects) or are simply two out-of-sync implementations of the same intent, since I don't have visibility into the nebula shader source.

**Suggested folder:** Systems — already correctly placed under `Source/Systems/Graphics/BackgroundManager/`, matching ARCHITECTURE_OVERVIEW.md's `BackgroundManager` entry.
**Confidence:** High for the dead-code finding and the RNG-chain confirmation; Medium on the nebula speed-mechanism discrepancy, since it's currently unreachable and I lack shader-source visibility to fully resolve it.

---

## effect_data_inspector_plugin.gd
**Current responsibilities:**
- A Godot editor Inspector plugin that replaces `EffectData`'s raw int `subtype` field with a context-sensitive `OptionButton` dropdown, whose entries depend on the currently-selected `category`
- A static `SUBTYPE_NAMES` lookup table mapping each `EffectEnums.Category` to its ordered list of human-readable subtype display names

**Style issues:** The nested `SubtypeProperty` class (lines 37-157) consistently uses a single blank line between its three methods (`_init`/`_update_property`/`_on_item_selected`, e.g. lines 128, 136, 152), rather than the double-blank convention used by the two top-level functions in this same file (lines 13-14, 17-18). A self-contained, internally-consistent deviation confined to the nested class.

**Coupling issues:** none flagged — referencing `EffectEnums`/`EffectData` (Behavior-tier classes) from this editor tool is expected and necessary for it to do its job.

**Split recommendation:** No — cohesive single-purpose editor plugin (157 lines, mostly a static lookup table).

**Bugs:** **Confirmed cross-file mismatch, worth prioritizing:** I compared this file's `SUBTYPE_NAMES[EffectEnums.Category.DICE_CONTROL]` list against `effect_registry.gd`'s actual `DICE_CONTROL` handler registrations (cross-checking every category's entry count between the two files). Every category matches except `DICE_CONTROL`: this file lists **10** subtype names (ending in `"Receive Die from Target"` at index 9), but `effect_registry.gd` only registers **9** handlers for that category (`CHANGE_ACTIVATOR_VALUE` through `SPAWN_HOLOGRAPHIC_DIE`) — there is no handler registered for whatever enum value corresponds to "Receive Die from Target". If a content author selects this option in the Inspector for a `TileResource`'s effect chain, `EffectRegistry.get_handler()` would fail to find a match and `push_error()` at runtime, silently no-opping that effect step. This is either an incomplete feature (subtype added to the enum/dropdown but its handler never implemented) or a display list that drifted out of sync with the enum — worth checking `effect_enums.gd`'s actual `DiceControlSubtype` definition to confirm which of the two it is.

**Suggested folder:** N/A — this is editor tooling under `Addons/`, already in the correct location for a plugin; folder-placement judgment doesn't apply here.
**Confidence:** High — the mismatch was found by directly comparing two files' concrete contents, not inferred.

---

## effect_data_editor_plugin.gd
**Current responsibilities:**
- Registers/unregisters `effect_data_inspector_plugin.gd` as an `EditorInspectorPlugin` on plugin enable/disable

**Style issues:** none found — double-blank-line-before-function convention followed (lines 5-6, 10-11).

**Coupling issues:** none found.

**Split recommendation:** No — trivial (15 lines).

**Bugs:** **Confirmed, significant path-casing mismatch:** line 8 preloads `res://addons/effect_data_inspector/effect_data_inspector_plugin.gd` (lowercase `addons`), and `project.godot`'s `[editor_plugins]` section enables this same plugin via `res://addons/effect_data_inspector/plugin.cfg` (also lowercase) — but the actual folder on disk is `Addons/` (capital A), confirmed directly via `ls`. This works today only because macOS's default filesystem (APFS) is case-insensitive; on a case-sensitive filesystem (Linux, and potentially certain export/packaging paths), every reference to this addon — both Godot's own plugin-enablement mechanism and this script's internal preload — would fail to resolve, breaking the editor plugin entirely for any collaborator or CI environment not running on a case-insensitive filesystem. Recommend renaming the folder to lowercase `addons` to match Godot's own convention and every existing reference to it (rather than updating the references to `Addons`, since `addons/` lowercase is also the standard Godot convention for plugin folders).

**Suggested folder:** N/A — editor tooling under `Addons/`; the folder-casing issue above is a naming/portability fix, not a placement question.
**Confidence:** High — directly confirmed via `ls` against the actual filesystem and cross-checked against `project.godot`'s own plugin-enablement path.
